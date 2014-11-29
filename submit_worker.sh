#!/bin/bash
# Script for submitting workers to the UA HPC through PBS
# Code modified from Group 1's sol_rad_hack.sh

# Define default values for variables

### Change address to your U of A email address for email notifications
ADDRESS="bstreete@email.arizona.edu"

### Change to your HPC group name to automatically charge the appopriate group
GROUP="nirav"

# These variables are modified by passed arguments
PRIORITY="windfall"
NODES=12
EMAIL="#"
WALLTIME=1
PROJECT=${USER}_eemt
TIMESTAMP=$( date +%Y.%m.%d_%T )

# Read and process the arguments
while getopts ":eg:n:p:sw:" o ; do
	case "${o}" in 
		# s = standard priority
		s)
			PRIORITY="standard"
			;;

		# n = Number of nodes (individual processor/memory combos)
		n)
			NODES=${OPTARG}

			# Check for an integer
			if [ $NODES -eq $NODES ] 2> /dev/null; then 

				# Check upper bounds
				if [ $NODES -gt 144 ] ; then
					NODES=144
					echo "You can request up to 144 nodes. Defaulting to 128."
				fi

				# Check lower bounds
				if [ $NODES -lt 1 ] ; then
					NODES=1
					echo "You must request at least 1 node. Defaulting to 1."
				fi

			# Not an integer option
			else
				echo "The -n argument requires an integer option. Aborting."
				exit 1
			fi
			;;

		# e = disable auto email when job starts and ends
		e) 
			EMAIL="### "
			;;

		# g = HPC group to charge for time
		g)
			GROUP=${OPTARG}	
			;;

		# w = Wall Time (Computation time per processor)
		w)
			WALLTIME=${OPTARG}

			# Check that it is an integer
			if [ $WALLTIME -eq $WALLTIME ] 2> /dev/null ; then 
				# Check upper bounds
				if [ $WALLTIME -gt 240 ] ; then 
					echo "Limited to a maximum of 240 hours of wall time. Defaulting to 240."
					WALLTIME=240
				fi

				# Check Lower Bounds
				if [ $WALLTIME -lt 1 ] ; then
					echo "Walltime must be at least 1 hour to use this script. Defaulting to 1."
					WALLTIME=1
				fi
			fi
			;;

		# p = Makeflow/WorkQueue Project Name
		p)
			PROJECT=${OPTARG}
			;;

		# Default Case = Unknown option
		*) 
			echo "Usage: submit_worker executable_name [-e] [-g group_name] [-n #] "
			echo $'\t[-p project_name] [-s] [-w #]'
			echo
			echo "Creates a script to submit to the PBS batch system on the UA HPC that executes the passed executable."
			echo
			echo $'\t-e\tDisables the email notifications when the job begins and ends (Enabled by default).'
			echo $'\t-g\tSpecify the group to charge for resource utilization.'
			echo $'\t-n\tSets the number of workers to request. Defaults to 12 (One complete physical node).'
			echo $'\t-p\tSpecify the project name to connect the worker to. Defaults to $USER_eemt'
			echo $'\t-s\tSets the priority to standard. Default is windfall.'
			echo $'\t-w\tSpecify the walltime for the calculations in hours. Defaults to 1 hour.'

			exit 1
	esac			
done	# End argument reading

# Finish calculating variables
CPUTIME=$(($WALLTIME * $NODES))
WALLTIME=$WALLTIME:0:0

SCRIPT="qsub_wq_worker_${TIMESTAMP}.pbs"

### Start of PBS Code
cat > "${SCRIPT}" << __EOF__
#!/bin/csh

#PBS -N wq_worker_${TIMESTAMP}
${EMAIL}PBS -m bea
#PBS -M $ADDRESS

#PBS -W group_list=$GROUP
#PBS -l jobtype=serial
#PBS -q $PRIORITY
#PBS -l select=1:ncpus=1:mem=2gb
#PBS -l pvmem=2gb
#PBS -l place=pack:shared
#PBS -l walltime=$WALLTIME
#PBS -l cput=$WALLTIME

### Code to Execute
cd $PWD

source /usr/share/Modules/init/csh

date
work_queue_submit -M $PROJECT
date
__EOF__

### End of PBS Code

# Change the script to an executable and submit it with qsub
chmod 755 $script_name
INDEX=0

while [ $INDEX -lt $NODES ] ; do 
	echo "Submitted worker."
	# qsub $SCRIPT
	INDEX=$(( $INDEX + 1))
done

cat $SCRIPT
rm $SCRIPT

# Check the status of the submission
# qstat -u $USER