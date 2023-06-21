#!/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use FindBin;
use Cwd;
use Data::Dumper;
use File::Find;

use lib "$FindBin::Bin/../lib";

use Queue::Status;
use Queue::Actions;
use Jobs;
use Util qw(cluster_id_sort);
use Log;


my ($dbFile, $queueName, $maxRunJobs, $scriptDir, $jobPrefix, $py4cytoscapeImage, $imageConf, $ssnListFile, $ssnFindDir,
    $ssnRootDir, $dryRun, $debug, $logFile, $overwriteImages, $checkForNewSsnDirs, $checkForMissingImages, $cytoConfigHome, $cytoApp);
my $result = GetOptions(
    "db=s"                  => \$dbFile,
    "queue=s"               => \$queueName,
    "max-cy-jobs=i"         => \$maxRunJobs,
    "script-dir=s"          => \$scriptDir,
    "job-prefix=s"          => \$jobPrefix,
    "py4cy-image=s"         => \$py4cytoscapeImage,
    "ssn-root-dir=s"        => \$ssnRootDir, # --ssn-home-dirs /path/dicing-20,/path/dicing-30,/path ...
    "ssn-list-file=s"       => \$ssnListFile,
    "ssn-base-find-dir=s"   => \$ssnFindDir,
    "dry-run"               => \$dryRun,
    "debug"                 => \$debug,
    "log-file=s"            => \$logFile,
    "overwrite-images"      => \$overwriteImages,
    "check-new-dirs"        => \$checkForNewSsnDirs,
    "check-missing-images"  => \$checkForMissingImages,
    "cyto-config-home=s"    => \$cytoConfigHome,
	"cyto-app=s"            => \$cytoApp,
    "image-conf=s"          => \$imageConf,
);


$queueName = "efi" if not $queueName;
$maxRunJobs = 11 if not $maxRunJobs;
$jobPrefix = "cysz" if not $jobPrefix;
$dryRun = 0 if not $dryRun;
$debug = 0 if not $debug;
$logFile = "" if not $logFile;
$overwriteImages = 0 if not $overwriteImages;
$checkForNewSsnDirs = 0 if not $checkForNewSsnDirs;
$checkForMissingImages = 0 if not $checkForMissingImages;

die "Need --script-dir" if not $scriptDir or not -d $scriptDir;
die "Need --ssn-root-dir or --ssn-list-file" if (not $ssnRootDir and (not $ssnListFile or not -f $ssnListFile) and (not $ssnFindDir or not -d $ssnFindDir));
die "Need --py4cy-image (singularity SIF file)" if not $py4cytoscapeImage or not -f $py4cytoscapeImage;
die "Need --cyto-config-home" if not $cytoConfigHome or not -d $cytoConfigHome;
die "Need --cyto-app path to modified cytoscape_superfamily.sh script" if not $cytoApp or not -f $cytoApp;

if (not $dbFile) {
    $dbFile = getcwd() . "/job_info.sqlite";
}



my $logger = new Log(file => $logFile, dry_run => $dryRun, debug => $debug);

my $qstat = new Queue::Status(queue => $queueName, job_prefix => $jobPrefix);
my $qact = new Queue::Actions(queue => $queueName, dry_run => $dryRun, logger => $logger);

$imageConf = parseImageConf($imageConf);

my %jobsArgs = (
    db_file => $dbFile,
    max_running_jobs => $maxRunJobs,
    queue_status => $qstat,
    script_dir => $scriptDir,
    job_prefix => $jobPrefix,
    py4cytoscape_image => $py4cytoscapeImage,
    dry_run => $dryRun,
    debug => $debug,
    qact => $qact,
    logger => $logger,
    overwrite_images => $overwriteImages,
    cyto_config_home => $cytoConfigHome,
    cyto_app => $cytoApp,
    image_conf => $imageConf,
);
my $jobs = new Jobs(%jobsArgs);

# Check each cluster; add to db if not already existing, otherwise load state.
if ($checkForNewSsnDirs and $ssnRootDir) {
    my %ssnFiles = getSsnDirs($ssnRootDir);
    foreach my $clusterId (sort { cluster_id_sort($a, $b) } keys %ssnFiles) {
        $jobs->addCluster($clusterId, $ssnFiles{$clusterId});
    }
} elsif ($checkForNewSsnDirs and $ssnListFile) {
    open my $fh, "<", $ssnListFile or die "Unable to read SSN list file: $!";
    while (my $line = <$fh>) {
        chomp $line;
        my ($clusterId, $file) = split(m/\t/, $line);
        $clusterId =~ s/\-AS(\d+)\-(\d+)$/-$2-AS$1/;
        $jobs->addCluster($clusterId, $file);
    }
} elsif ($checkForNewSsnDirs and $ssnFindDir) {
    #my $wanted = sub {
    #    return if $File::Find::name !~ m%/(cluster-[\-\d]+)/ssn.xgmml$%;
    #    my $clusterId = $1;
    #    if ($File::Find::dir =~ m%/dicing-(\d+)/%) {
    #        $clusterId .= "-AS$1";
    #    }
    #    $jobs->addCluster($clusterId, $File::Find::name);
    #};
    #find($wanted, $ssnFindDir);
}

$qstat->load();

$jobs->checkForFinishedJobs();
$jobs->startNewCytoscapeJobs($checkForMissingImages);
$jobs->startNewRestJobs();
$jobs->checkForOrphanedCytoscapeJobs();




sub getSsnDirs {
    my $ssnRootDir = shift;

    my %ssnFiles;
    my @bases = split(m/,/, $ssnRootDir);
    foreach my $base (@bases) {
        print "Skipping invalid directory $base\n" and next if not -d $base;
        my @dirs = grep { -d $_ } glob("$base/cluster-*");
        foreach my $dir (@dirs) {
            (my $clusterId = $dir) =~ s%^.*/(cluster-[\-\d]+)$%$1%;
            foreach my $dicingDir (glob("$dir/dicing-*")) { # Gets executed only if dicing exists
                (my $ascore = $dicingDir) =~ s%^.*/dicing-(\d+)$%$1%;
                my $asid = "$clusterId-AS$ascore";
                foreach my $subDir (glob("$dicingDir/cluster-*")) {
                    (my $subId = $subDir) =~ s%^.*/(cluster-[\-\d]+)$%$1%;
                    $subId .= "-AS$ascore";
                    my $ssn = "$subDir/ssn.xgmml";
                    $ssnFiles{$subId} = $ssn if -f $ssn;
                }
                my $ssn = "$dicingDir/ssn.xgmml";
                $ssnFiles{$asid} = $ssn if -f $ssn;
            }
            my $ssn = "$dir/ssn.xgmml";
            $ssnFiles{$clusterId} = $ssn if -f $ssn;
        }
    }

    return %ssnFiles;
}


sub parseImageConf {
    my $confStr = shift || "";
    my $conf = {
        zoom => 400,
        style => "style",
        verbose => "no_verbose",
        crop => "crop",
        name => "ssn_lg",
    };
    my @p = split(m/,/, $confStr);
    map { my ($k, $v) = split(m/=/, $_); $conf->{$a} = $b if ($a and $b); } @p;
    return $conf;
}


