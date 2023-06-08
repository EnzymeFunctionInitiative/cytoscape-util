#!perl

use strict;
use warnings;

use Getopt::Long;
use FindBin;
use Cwd;
use Data::Dumper;

use lib "$FindBin::Bin/../lib";

use Queue::Status;
use Queue::Actions;
use Jobs;
use Util qw(cluster_id_sort);
use Log;


my ($dbFile, $queueName, $maxRunJobs, $scriptDir, $jobPrefix, $py4cytoscapeImage,
    $ssnBase, $dryRun, $debug, $logFile, $overwriteImages, $checkForNewSsnDirs, $checkForMissingImages, $cytoConfigHome);
my $result = GetOptions(
    "db=s"                  => \$dbFile,
    "queue=s"               => \$queueName,
    "max-cy-jobs=i"         => \$maxRunJobs,
    "script-dir=s"          => \$scriptDir,
    "job-prefix=s"          => \$jobPrefix,
    "py4cy-image=s"         => \$py4cytoscapeImage,
    "ssn-home-dirs=s"       => \$ssnBase, # --ssn-home-dirs /path/dicing-20,/path/dicing-30,/path ...
    "dry-run"               => \$dryRun,
    "debug"                 => \$debug,
    "log-file=s"            => \$logFile,
    "overwrite-images"      => \$overwriteImages,
    "check-new-dirs"        => \$checkForNewSsnDirs,
    "check-missing-images"  => \$checkForMissingImages,
    "cyto-config-home=s"    => \$cytoConfigHome,
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
die "Need --ssn-home-dirs" if not $ssnBase;
die "Need --py4cy-image (singularity SIF file)" if not $py4cytoscapeImage or not -f $py4cytoscapeImage;
die "Need --cyto-config-home" if not $cytoConfigHome or not -d $cytoConfigHome;

if (not $dbFile) {
    $dbFile = getcwd() . "/job_info.sqlite";
}



my $logger = new Log(file => $logFile, dry_run => $dryRun, debug => $debug);

my $qstat = new Queue::Status(queue => $queueName, job_prefix => $jobPrefix);
my $qact = new Queue::Actions(queue => $queueName, dry_run => $dryRun, logger => $logger);

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
);
my $jobs = new Jobs(%jobsArgs);

# Check each cluster; add to db if not already existing, otherwise load state.
if ($checkForNewSsnDirs) {
    my %ssnDirs = getSsnDirs($ssnBase);
    foreach my $clusterId (sort { cluster_id_sort($a, $b) } keys %ssnDirs) {
        $jobs->addCluster($clusterId, $ssnDirs{$clusterId});
    }
}

$qstat->load();

$jobs->checkForFinishedJobs();
$jobs->startNewCytoscapeJobs($checkForMissingImages);
$jobs->startNewRestJobs();
$jobs->checkForOrphanedCytoscapeJobs();




sub getSsnDirs {
    my $ssnBase = shift;

    my %ssnDirs;
    my @bases = split(m/,/, $ssnBase);
    foreach my $base (@bases) {
        print "Skipping invalid directory $base\n" and next if not -d $base;
        my @dirs = grep { -d $_ and -f "$_/ssn.xgmml" } glob("$base/cluster-*");
        if ($base =~ m%dicing-(\d+)/?$%) {
            my $ascore = $1;
            map { (my $cid = $_) =~ s%^.*/(cluster[\-0-9]+)$%$1%; $ssnDirs{"$cid-$ascore"} = $_ } @dirs;
        } else {
            map { (my $cid = $_) =~ s%^.*/(cluster[\-0-9]+)$%$1%; $ssnDirs{$cid} = $_ } @dirs;
        }
    }

    return %ssnDirs;
}





