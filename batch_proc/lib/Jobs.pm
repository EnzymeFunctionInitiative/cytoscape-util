

package Jobs;

use strict;
use warnings;

use DBH;
use Data::Dumper;


sub new {
    my ($class, %args) = @_;

    my $self = {};
    bless $self, $class;

    $self->{db_file} = $args{db_file};
    $self->{max_run} = $args{max_running_jobs} // 11;
    $self->{qstat} = $args{queue_status};
    $self->{script_dir} = $args{script_dir};
    $self->{job_prefix} = $args{job_prefix};
    $self->{rest_job_prefix} = $args{rest_job_prefix} // "rest";
    $self->{py4cy_image} = $args{py4cytoscape_image};
    $self->{dry_run} = $args{dry_run} // 0;
    $self->{debug} = $args{debug} // 0;
    $self->{qact} = $args{qact};
    $self->{logger} = $args{logger};
    $self->{overwrite_images} = $args{overwrite_images} // 0;
    $self->{cyto_config_home} = $args{cyto_config_home};

    $self->{dbh} = $self->openDb($self->{db_file});

    return $self;
}


sub addCluster {
    my $self = shift;
    my $clusterId = shift;
    my $clusterDir = shift;

    my $dbh = $self->{dbh};

    my $sql = "SELECT * FROM clusters WHERE cluster_id = '$clusterId'";
    my $sth = $dbh->prepare($sql);
    $sth->execute;
    my $row = $sth->fetchrow_hashref;
    if (not $row) {
        $self->{logger}->print("Adding $clusterId");
        my $ssnFile = "$clusterDir/ssn.xgmml";
        $sql = "INSERT INTO clusters (cluster_id, ssn_path) VALUES ('$clusterId', '$ssnFile')";
        $dbh->do($sql);
        my ($numEdges, $numNodes, $fileSize) = getFileStats($ssnFile);
        $sql = "INSERT INTO stats (cluster_id, num_edges, num_nodes, file_size) VALUES ('$clusterId', $numEdges, $numNodes, $fileSize)";
        $dbh->do($sql);
        $sql = "INSERT INTO cy_jobs (cluster_id) VALUES('$clusterId')";
        $dbh->do($sql);
        $self->{logger}->print("Added cluster cluster_id=$clusterId, num_edges=$numEdges, num_nodes=$numNodes, file_size=$fileSize to database");
    }
}


sub checkForFinishedJobs {
    my $self = shift;

    my $runningJobs = $self->{qstat}->getRunningJobs();
    my $pendingJobs = $self->{qstat}->getPendingJobs();
    my ($runningRestJobNames) = $self->{qstat}->loadByPattern($self->{rest_job_prefix});

    my $sql = <<SQL;
SELECT rest_jobs.cluster_id, cy_slurm_id, slurm_id, end_utime
    FROM rest_jobs
    LEFT JOIN stats ON rest_jobs.cluster_id = stats.cluster_id
    WHERE cy_slurm_id IS NOT NULL AND
        slurm_id IS NOT NULL AND
        stats.runtime IS NULL
SQL
    my $sth = $self->{dbh}->prepare($sql);
    $sth->execute;
    while (my $row = $sth->fetchrow_hashref) {
        if (not $runningRestJobNames->{$row->{slurm_id}} and not $row->{end_utime}) {
            my $utime = time();
            $sql = "UPDATE rest_jobs SET end_utime = $utime WHERE slurm_id = $row->{slurm_id}";
            $self->{dbh}->do($sql);
        }
        # Skip any running jobs
        next if $runningJobs->{$row->{cy_slurm_id}} or $pendingJobs->{$row->{cy_slurm_id}};
        my $memStats = $self->{qstat}->computeJobStats($row->{cy_slurm_id});
        my $timeStats = $self->{qstat}->computeJobStats($row->{slurm_id});
        $sql = "UPDATE stats SET ram_used = $memStats->{ram}, runtime = $timeStats->{runtime} WHERE cluster_id = '$row->{cluster_id}'";
        $self->{dbh}->do($sql);
    }
}


# Check if any job slots are available
sub startNewCytoscapeJobs {
    my $self = shift;
    my $checkForMissingImages = shift || 0;

    my $runningJobs = $self->{qstat}->getRunningJobs();
    my $numJobs = scalar keys %$runningJobs;
    my $pendingJobs = $self->{qstat}->getPendingJobs();
    $numJobs += scalar keys %$pendingJobs;

    my $numNewJobs = $self->{max_run} - $numJobs;
    if ($numNewJobs <= 0) {
        return;
    }

    my $dbh = $self->{dbh};

    my $openPorts = $self->getOpenPorts($runningJobs, $pendingJobs);

    my $sql = "";
    my $whereCond = $checkForMissingImages ? "IS NOT NULL"  : "IS NULL";
    $sql = <<SQL;
SELECT C.cluster_id AS cluster_id,
       S.num_edges,
       S.num_nodes,
       S.file_size,
       CL.ssn_path
    FROM cy_jobs AS C
    LEFT JOIN stats AS S ON C.cluster_id = S.cluster_id
    LEFT JOIN clusters AS CL ON C.cluster_id = CL.cluster_id
    WHERE C.slurm_id $whereCond LIMIT $numNewJobs
SQL

    my $sth = $dbh->prepare($sql);
    $sth->execute;
    while (my $row = $sth->fetchrow_hashref) {
        my $clusterId = $row->{cluster_id};
        my $ssnImagePath = getSsnImagePath($row->{ssn_path});
        if ((not $checkForMissingImages or -f $ssnImagePath) and (not $self->{overwrite_images} and -f $ssnImagePath)) {
            $self->{logger}->print("Skipping cluster_id=$clusterId because the image already exists");
            my $sql = "UPDATE cy_jobs SET slurm_id = -1, port = -1 WHERE cluster_id = '$clusterId'";
            $dbh->do($sql);
            next;
        }

        my $port = findAvailablePort($openPorts);
        $openPorts->{$port} = 1;
        my ($slurmId, $ram, $error, $file) = $self->createCytoscapeJob($row, $port);
        if (not $slurmId) {
            $self->{logger}->error("There was an error submitting cluster_id=$clusterId, script_file=$file: $error");
            next;
        }
        my $sql = "UPDATE cy_jobs SET slurm_id = $slurmId, port = $port WHERE cluster_id = '$clusterId'";
        $dbh->do($sql);

        sleep 5; # we were having problems with submitting jobs right after another, Cytoscape didn't like it, some file open/writing problem. The delay fixes this problem.
    }
}


# Looks for any running Cytoscape jobs that don't have associated REST jobs, then
# submits a REST job that corresponds to the Cytoscape job (by submitting to the same
# node with the same REST port that Cytoscape is looking for).
sub startNewRestJobs {
    my $self = shift;

    my $runningJobs = $self->{qstat}->getRunningJobs();

    foreach my $jid (keys %$runningJobs) {
        my $rj = $runningJobs->{$jid};

        # Check if the REST job is already running
        my $sql = <<SQL;
SELECT rest_jobs.slurm_id AS slurm_id
    FROM rest_jobs
    INNER JOIN cy_jobs ON rest_jobs.cy_slurm_id = cy_jobs.slurm_id
    WHERE rest_jobs.cy_slurm_id = $jid
SQL
        my $sth = $self->{dbh}->prepare($sql);
        $sth->execute;
        my $row = $sth->fetchrow_hashref;
        $self->{logger}->print("Skipping cluster_id=$rj->{name}, slurm_id=$jid because REST job already running") and next if $row->{slurm_id};
        
        $sql = <<SQL;
SELECT clusters.ssn_path, cy_jobs.port
    FROM clusters
    INNER JOIN cy_jobs ON cy_jobs.cluster_id = clusters.cluster_id
    WHERE cy_jobs.slurm_id = $jid
SQL
        $sth = $self->{dbh}->prepare($sql);
        $sth->execute;
        $row = $sth->fetchrow_hashref;

        my ($slurmId, $error, $file) = $self->createRestJob($row->{port}, $rj->{name}, $rj->{node}, $row->{ssn_path});
        if (not $slurmId) {
            $self->{logger}->error("There was an error submitting REST job cluster_id=$rj->{name}, script_file=$file: $error");
            next;
        }
        $sql = "INSERT INTO rest_jobs (cluster_id, cy_slurm_id, slurm_id) VALUES ('$rj->{name}', $jid, $slurmId)";
        $self->{dbh}->do($sql);
        
        sleep 5;
    }
}


sub checkForOrphanedCytoscapeJobs {
    my $self = shift;

    my $runningJobs = $self->{qstat}->getRunningJobs();
    my ($runningRestJobNames) = $self->{qstat}->loadByPattern($self->{rest_job_prefix});
    foreach my $jid (keys %$runningJobs) {
        my $sql = "SELECT slurm_id, end_utime FROM rest_jobs WHERE cy_slurm_id = $jid";
        my $sth = $self->{dbh}->prepare($sql);
        $sth->execute;
        my $row = $sth->fetchrow_hashref;
        #print "".($row->{end_utime} // 2552149168).", ".time().", ".$row->{slurm_id}.", ".$jid."\n";
        if ($row and $row->{slurm_id} and not $runningRestJobNames->{$row->{slurm_id}} and ($row->{end_utime} // 2552149168) + 60 < time()) { # 2552149168 is year 2050, this is in case the field isn't initialized
            $self->{logger}->warning("Canceling orphaned cysz-$runningJobs->{$jid}->{name} jid=$jid");
            $self->{qact}->cancelJob($jid);
        }
    }
}


sub createCytoscapeJob {
    my $self = shift;
    my $info = shift;
    my $port = shift;
    
    my $clusterId = $info->{cluster_id};

    my $jobName = $self->{job_prefix} . "-" . $clusterId;
    my $scriptFile = $self->{script_dir} . "/$jobName.sh";
    my $mem = $self->getRamPrediction($info) + 5;
    #TODO: remove debug
    #$mem = 350;
    my $javaMem = $mem - 5;

    my @commands = (<<SCRIPT

if [[ -n \${USE_SINGULARITY+x} ]]; then
    module load singularity/3.8.1
    IMAGE=/igbgroup/n-z/noberg/dev/ssn2image/memspec/cytoscape.sif
    singularity run \$IMAGE $port
else
    module load cytoscape/3.8.2-Java-11.0.5
    CYTOSCAPE=cytoscape.sh
    #CYTOSCAPE=/igbgroup/n-z/noberg/dev/ssn2image/memspec/random.sh
    export CHECK_ROOT_INSTANCE_RUNNING=false
    export USE_TEMP_KARAF=1
    export CYTOSCAPE_CONFIG_HOME=$self->{cyto_config_home}
    export JAVA_OPTS="-Xms${javaMem}G -Xmx${javaMem}G"
    xvfb-run -d \$CYTOSCAPE -R $port < /dev/zero
fi

SCRIPT
    );
    
    my %args = (name => $jobName, mem => $mem, file => $scriptFile, commands => \@commands);
    $self->{qact}->createScript(%args);

    $self->{logger}->print("Submitting Cytoscape job cluster_id=$clusterId, slurm_name=$jobName, script_file=$scriptFile, ram_resv_=$mem, rest_port=$port");
    my $jid = $self->{qact}->submitJob($scriptFile);

    return ($jid, $mem, 0, "");
}


sub createRestJob {
    my $self = shift;
    my $port = shift;
    my $clusterId = shift;
    my $node = shift;
    my $ssnPath = shift;
    
    my $jobName = $self->{rest_job_prefix} . "-" . $clusterId;
    my $scriptFile = $self->{script_dir} . "/$jobName.sh";
    my $mem = "1";

    my $outputImage = getSsnImagePath($ssnPath);

    my @commands = (<<SCRIPT
module load singularity/3.8.1
IMAGE=$self->{py4cy_image}
singularity run \$IMAGE $ssnPath $outputImage $port
SCRIPT
    );
    
    my %args = (name => $jobName, mem => $mem, file => $scriptFile, node => $node, commands => \@commands);
    $self->{qact}->createScript(%args);

    $self->{logger}->print("Submitting py4cytoscape job cluster_id=$clusterId, slurm_name=$jobName, script_file=$scriptFile, node=$node, rest_port=$port");
    my $jid = $self->{qact}->submitJob($scriptFile);

    return ($jid, 0, "");
}


sub getSsnImagePath {
    my $ssnPath = shift;
    $ssnPath =~ s%^(.*)/ssn.xgmml$%${1}/ssn_lg.png%;
    return $ssnPath;
}


sub getOpenPorts {
    my $self = shift;
    my $running = shift;
    my $pending = shift;

    my $open = {};

    foreach my $jid (keys %$running, keys %$pending) {
        my $sql = "SELECT port FROM cy_jobs WHERE slurm_id = $jid";
        my $sth = $self->{dbh}->prepare($sql);
        $sth->execute;
        my $row = $sth->fetchrow_hashref;
        $open->{$row->{port}} = 1;
    }

    return $open;
}


sub findAvailablePort {
    my $ports = shift;

    my $port = 8001;
    while ($port++) {
        return $port if not $ports->{$port};
    }
}


sub getRamPrediction {
    my $self = shift;
    my $info = shift;

    #TODO: empirically-derived formula for RAM allocation based on edges, nodes, and file size.
    # For now, we make a guess

    my $numEdges = $info->{num_edges};
    my $ram = 10;
    if ($numEdges > 5700000) { # 5.7m
        $ram = 150;
    } elsif ($numEdges > 2500000) { # 2.5m
        $ram = 100;
    } elsif ($numEdges > 975000) {
        $ram = 60;
    } elsif ($numEdges > 500000) {
        $ram = 40;
    } elsif ($numEdges > 100000) {
        $ram = 20;
    }
    #my $ram = 25;
    #if ($numEdges > 100000000) { # 10 million
    #    $ram = 350;
    #} elsif ($numEdges > 5000000) { # 5 million
    #    $ram = 250;
    #} elsif ($numEdges > 1000000) { # 1 million
    #    $ram = 150;
    #} elsif ($numEdges > 500000) { # 500,000
    #    $ram = 100;
    #} elsif ($numEdges > 100000) { # 100,000
    #    $ram = 50;
    #}

    return $ram;
}


sub openDb {
    my $self = shift;
    my $file = shift;

    my %args = (file => $file, debug => $self->{debug}, logger => $self->{logger});
    if ($self->{dry_run}) {
        $args{dry_run} = 1;
        $args{dry_run_data} = {slurm_id => 1, cluster_id => "cluster-1-1-1-AS20", ssn_path => "/path/to/file",
                              port => 8001, node => "compute-4-5", cy_slurm_id => 2,
                              num_edges => 1000000, num_nodes => 10000, file_size => 200000000, ram_used => 185, runtime => 1000,
                             };
    }

    my $dbh = new DBH(%args);

    if (not $dbh->tableExists("clusters")) {
        my $sql = <<SQL;
CREATE TABLE clusters (
    cluster_id TEXT NOT NULL PRIMARY KEY,
    ssn_path TEXT
)
SQL
        $dbh->do($sql);
    }

    if (not $dbh->tableExists("cy_jobs")) {
        my $sql = <<SQL;
CREATE TABLE cy_jobs (
    cluster_id TEXT NOT NULL PRIMARY KEY,
    slurm_id INT,
    port INT,
    node TEXT
)
SQL
        $dbh->do($sql);
    }

    if (not $dbh->tableExists("rest_jobs")) {
        my $sql = <<SQL;
CREATE TABLE rest_jobs (
    cluster_id TEXT NOT NULL PRIMARY KEY,
    cy_slurm_id INT,
    slurm_id INT,
    end_utime INT
)
SQL
        $dbh->do($sql);
    }

    if (not $dbh->tableExists("stats")) {
        my $sql = <<SQL;
CREATE TABLE stats (
    cluster_id TEXT NOT NULL PRIMARY KEY,
    num_edges INT,
    num_nodes INT,
    file_size INT,
    ram_used INT,
    runtime INT
)
SQL
        $dbh->do($sql);
    }

    return $dbh;
}


sub getFileStats {
    my $file = shift;
    my $numEdges = `grep \\<edge $file | wc -l`;
    chomp $numEdges;
    my $numNodes = `grep \\<node $file | wc -l`;
    chomp $numNodes;
    my $fileSize = -s $file;
    return ($numEdges, $numNodes, $fileSize);
}


1;

