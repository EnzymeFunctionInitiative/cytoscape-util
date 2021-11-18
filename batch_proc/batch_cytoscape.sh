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
/home/n-z/noberg/dev/hmm/pipeline/ip82/load-3.0/rsam-3.0/cluster-1-1/dicing-25,\
/home/n-z/noberg/dev/hmm/pipeline/ip82/load-3.0/rsam-3.0/cluster-1-1/dicing-30,\
/home/n-z/noberg/dev/hmm/pipeline/ip82/load-3.0/rsam-3.0/cluster-1-1/dicing-35,\
/home/n-z/noberg/dev/hmm/pipeline/ip82/load-3.0/rsam-3.0/cluster-1-1/dicing-40,\
/home/n-z/noberg/dev/hmm/pipeline/ip82/load-3.0/rsam-3.0/cluster-1-1/dicing-45,\
/home/n-z/noberg/dev/hmm/pipeline/ip82/load-3.0/rsam-3.0/cluster-1-1/dicing-50,\
/home/n-z/noberg/dev/hmm/pipeline/ip82/load-3.0/rsam-3.0/cluster-1-1/dicing-55,\
/home/n-z/noberg/dev/hmm/pipeline/ip82/load-3.0/rsam-3.0/cluster-1-1/dicing-60,\
/home/n-z/noberg/dev/hmm/pipeline/ip82/load-3.0/rsam-3.0/cluster-1-1/dicing-65,\
/home/n-z/noberg/dev/hmm/pipeline/ip82/load-3.0/rsam-3.0/cluster-1-1/dicing-70,\
/home/n-z/noberg/dev/hmm/pipeline/ip82/load-3.0/rsam-3.0/cluster-1-1/dicing-80,\
/home/n-z/noberg/dev/hmm/pipeline/ip82/load-3.0/rsam-3.0/cluster-1-1/dicing-90,\
/home/n-z/noberg/dev/hmm/pipeline/ip82/load-3.0/rsam-3.0/cluster-1-1/dicing-100,\
/home/n-z/noberg/dev/hmm/pipeline/ip82/load-3.0/rsam-3.0/cluster-1-1/dicing-110,\
/home/n-z/noberg/dev/hmm/pipeline/ip82/load-3.0/rsam-3.0/cluster-1-1/dicing-120,\
/home/n-z/noberg/dev/hmm/pipeline/ip82/load-3.0/rsam-3.0/cluster-1-1/dicing-130,\
/home/n-z/noberg/dev/hmm/pipeline/ip82/load-3.0/rsam-3.0/cluster-1-1/dicing-140,\
/home/n-z/noberg/dev/hmm/pipeline/ip82/load-3.0/rsam-3.0/cluster-1-1/dicing-150,\
/home/n-z/noberg/dev/hmm/pipeline/ip82/load-3.0/rsam-3.0/cluster-1-1/dicing-160,\
/home/n-z/noberg/dev/hmm/pipeline/ip82/load-3.0/rsam-3.0/cluster-1-1/dicing-170,\
/home/n-z/noberg/dev/hmm/pipeline/ip82/load-3.0/rsam-3.0/cluster-1-1/dicing-180,\
/home/n-z/noberg/dev/hmm/pipeline/ip82/load-3.0/rsam-3.0/cluster-1-1/dicing-190,\
/home/n-z/noberg/dev/hmm/pipeline/ip82/load-3.0/rsam-3.0/cluster-1-1/dicing-200,\
/home/n-z/noberg/dev/hmm/pipeline/ip82/load-3.0/rsam-3.0/cluster-1-1/dicing-210,\
/home/n-z/noberg/dev/hmm/pipeline/ip82/load-3.0/rsam-3.0/cluster-1-1/dicing-220,\
/home/n-z/noberg/dev/hmm/pipeline/ip82/load-3.0/rsam-3.0/cluster-1-1/dicing-230,\
/home/n-z/noberg/dev/hmm/pipeline/ip82/load-3.0/rsam-3.0/cluster-1-1/dicing-240,\
/home/n-z/noberg/dev/hmm/pipeline/ip82/load-3.0/rsam-3.0/cluster-1-1/dicing-250,\
/home/n-z/noberg/dev/hmm/pipeline/ip82/load-3.0/rsam-3.0/cluster-1-1/dicing-260,\
/home/n-z/noberg/dev/hmm/pipeline/ip82/load-3.0/rsam-3.0/cluster-1-1/dicing-270,\
/home/n-z/noberg/dev/hmm/pipeline/ip82/load-3.0/rsam-3.0/cluster-1-1/dicing-280,\
/home/n-z/noberg/dev/hmm/pipeline/ip82/load-3.0/rsam-3.0/cluster-1-1/dicing-290,\
/home/n-z/noberg/dev/hmm/pipeline/ip82/load-3.0/rsam-3.0/cluster-1-1/dicing-300
LOG_FILE=$BASE_DIR/log
NUM_JOBS=20

#CHECK_SSN_DIRS_FLAG="--check-new-dirs"
#DRY_RUN_FLAG="--dry-run"
#DEBUG_FLAG="--debug"
LOG_FILE_FLAG="--log-file $LOG_FILE"
CYTOSCAPE_CONFIG_HOME="--cyto-config-home /private_stores/gerlt/users/temp"
SRV_SCRIPT=$script_dir/bin/cyto_job_server.pl

perl $SRV_SCRIPT \
    --db $BASE_DIR/job_info.sqlite \
    --script-dir $BASE_DIR/scripts \
    --py4cy-image $BASE_DIR/py4cytoscape.sif \
    --ssn-home-dirs $SSN_DIRS \
    --max-cy-jobs $NUM_JOBS \
    $DEBUG_FLAG $LOG_FILE_FLAG $CHECK_SSN_DIRS_FLAG $DRY_RUN_FLAG $CYTOSCAPE_CONFIG_HOME

rm $lock_file

