#!/bin/bash
###
## Runs the complete experiment using a PBS batch system on a cluster.
## based on Alexander Petry's script
## Modified 19.9.2006 Mathias Dalheimer
#

export CGWG_HOME=/u/herc/dalheime/cgwg/trunk

function usage() {
	echo "usage: $0 path-to-workload-set output-directory"
	cat <<HEND
	wld-set    - the path to the workload binary store
  output-dir - the name of the directory that will hold the output files
                     to the experiment.xml w/o the .xml)
  res-def    - The resource definition file.
HEND
}

function exitTrap() {
	exit 1
}

trap 'exit 1' SIGINT

username=`whoami`
userdomain="itwm.fhg.de"
useremail="$username@$userdomain"
prefix="/u/herc/dalheime"
ruby_binary="$prefix/usr/ruby/bin/ruby"
analysis_cmd="$ruby_binary $prefix/cgwg/trunk/bin/analysis.rb -f -s"

workloadstore="$1"    # workload directory
outputdir="$2"    # output directory
resourcedefinition="$3"
if [ -z "$outputdir" -o -z "$workloadstore" -o -z "$resourcedefinition" ]; then
	usage
	exit 1
fi

if [ "${workloadstore:0:1}" != "/" ]; then
	workloadstore=`pwd`/"$workloadstore"
fi

if [ "${outputdir:0:1}" != "/" ]; then
	exp=`pwd`/"$outputdir"
fi

if [ ! -e "${workloadstore}" ]; then
	echo "could not locate workload data: $workloadstore"
	exit 1
fi

if [ -d "$outputdir" ]; then
	echo "output directory $outputdir does already exist, all files will be removed"
	echo -n "do you want to continue? [yN] "
	read decision
	case "$decision" in
		y|Y)
			rm -rf "$outputdir"
			;;
		*)
			exit 0;	
	esac
fi

if [ ! -e "${resourcedefinition}" ]; then
  echo "could not locate resource definition file: $resourcedefinition"
	exit 1
fi


# get load-levels
cmd="$ruby_binary $CGWG_HOME/bin/sa-dumpworkload.rb -s $workloadstore -n"
loadlevels=`$cmd`
echo "Found load levels $loadlevels"

TMPID=$$
# run experiment for each load-level
for load in `echo -e "$loadlevels" | sort -n`; do
    echo "Working on load level $load" 
    echo "Creating job for workload $load"
    SUBMISSIONFILE=/tmp/calanasim-$TMPID-$load.sh   
    (
    cat <<EOSCRIPT
#!/bin/sh
# Calanasim run script created by run-exp-pbs at `date`
export CGWG_HOME=$CGWG_HOME
# workaround for sculptor PBS -d directive: explicitly move to startup
# directory
cd \$PBS_O_INITDIR
echo "\`date\`: running experiment with workload \`basename $wl\`..."
(
    echo "\`date\`: working in directory \`pwd\`" &&
    cmd="$ruby_binary $CGWG_HOME/bin/sa-scheduler.rb -s $workloadstore -o $outputdir -l $load -r $resourcedefinition"
    echo "Using commandline $cmd"
    $cmd
)
echo "done."
EOSCRIPT
    ) > $SUBMISSIONFILE
    chmod 700 $SUBMISSIONFILE
    qsubparams="-d $PWD -e $outputdir/pbs_error_$load.log -o $outputdir/pbs_output_$load.log -N CS-$load -S /bin/tcsh -l walltime=0:30:00 " 
    jobid=`qsub $qsubparams $SUBMISSIONFILE`
    jobIDs="$jobIDs $jobid"
done
echo "Submitted to PBS: $jobIDs"

# skipped for now.
exit

joblist=`echo "$jobIDs" | sed -e 's/\ /:/g'`
echo "Joblist: $joblist"
echo "Preparing analysis job, reporting to $useremail"
SUBMISSIONFILE=/tmp/calanasim-$TMPID-analysis.sh
analysisdir=$expdir/analysis
mkdir -p $analysisdir
(
cat <<EOSCRIPT
#!/bin/sh
# Calanasim analysis script created by run-exp-pbs at `date`
# workaround for sculptor PBS -d directive: explicitly move to startup
# directory
cd \$PBS_O_INITDIR
echo "foo"
export PATH=$prefix/usr/ruby/bin/ruby:$CGWG_HOME/bin:$PATH
export CGWG_HOME=$CGWG_HOME
echo "bar"
echo "\`date\`: running analysis \`basename $exp\` ..."
$analysis_cmd -i $expdir -o $analysisdir
echo "done."
echo "get your analysis here: $analysisdir" | mail -s "Analysis of experiment $exp finished." $useremail
EOSCRIPT
) > $SUBMISSIONFILE
chmod 700 $SUBMISSIONFILE
qsubparams="-d $PWD -e $analysisdir/pbs_error.log -o $analysisdir/pbs_output.log -N CS-analysis -S /bin/tcsh -W depend=afterany$joblist" 
jobid=`qsub $qsubparams $SUBMISSIONFILE`
jobIDs="$jobIDs $jobid"
echo "$jobIDs" > jobIDs-$TMPID.txt
