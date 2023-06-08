#!/bin/bash

script_file=`readlink -f $0`
script_dir=`basename $script_file`
lock_file="$script_file.lock"

#-gt is sometimes 2, sometimes 3?????
if [[ -f $lock_file || "`ps -ef | grep $0 | grep -v grep | wc -l`" -gt 2 ]]; then echo "Already running; exiting"; exit; fi
touch $lock_file

source /etc/profile
module load Perl
module load singularity

BASE_DIR=$script_dir
SSN_DIRS=\
/path/to/dicing/cluster/dicing-20,\
/path/to/dicing/cluster/dicing-30
LOG_FILE=$BASE_DIR/log
NUM_JOBS=20

#CHECK_SSN_DIRS_FLAG="--check-new-dirs"
#DRY_RUN_FLAG="--dry-run"
#DEBUG_FLAG="--debug"
LOG_FILE_FLAG="--log-file $LOG_FILE"
CYTOSCAPE_CONFIG_HOME="--cyto-config-home /path/to/cytoscape/temp/karaf/dirs/temp"
SRV_SCRIPT=$script_dir/bin/cyto_job_server.pl

perl $SRV_SCRIPT \
    --db $BASE_DIR/job_info.sqlite \
    --script-dir $BASE_DIR/scripts \
    --py4cy-image $BASE_DIR/py4cytoscape.sif \
    --ssn-home-dirs $SSN_DIRS \
    --max-cy-jobs $NUM_JOBS \
    $DEBUG_FLAG $LOG_FILE_FLAG $CHECK_SSN_DIRS_FLAG $DRY_RUN_FLAG $CYTOSCAPE_CONFIG_HOME

rm $lock_file

