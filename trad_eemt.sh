#!/bin/bash

# Bash script that will create tasks for Makeflow to create a 
# traditional EEMT model. Takes an input directory, output 
# directory, and a project name if specified. If none of the 
# arguments are given, the input and output directories default to 
# the current working directory. The Makeflow project name defaults 
# to trad_eemt. 

# Clear the screen
clear 

# Define default values for variables

CUR_YEAR=$(date +%Y)
INPUT_DIR=./
OUTPUT_DIR=./
PROJ_NAME="trad_eemt"
END_YEAR=$(($CUR_YEAR - 2))
START_YEAR=1980
PASSWORD=""

# Generate absolute path to the install directory
SRC="$(readlink -f $0)"
SRC="$(dirname $SRC)"
START_DIR=${PWD}
# Process arguments
while getopts ":i:o:p:s:e:d:P:" o ; do
	case "${o}" in 
		# i = Input directory
		i)
			INPUT_DIR=${OPTARG}

			# Check that it is a valid directory 
			if [ ! -d "$INPUT_DIR" ] ; then
				echo
				echo "Invalid input directory. "
				echo "$INPUT_DIR does not exist or is inaccessible."
				echo
				exit 1
			fi
			;;

		# o - Output directory
		o)
			OUTPUT_DIR=${OPTARG}

			# Check that it is a valid directory 
			if [ ! -d "$OUTPUT_DIR" ] ; then
				echo
				echo "Invalid output directory. "
				echo "$OUTPUT_DIR does not exist or is inaccessible."
				echo
				exit 1
			fi
			;;

		# p - Makeflow project name
		p)
			PROJ_NAME=${OPTARG}
			;;

		# s - Start year
		s)
			START_YEAR=${OPTARG}

			# Check that it is an integer
			if [ "$START_YEAR" -eq "$START_YEAR" ] ; then

				# Check lower bounds 
				if [ "$START_YEAR" -lt 1980 ] ; then
					echo "The starting year needs to be at least 1980. Defaulting to 1980."
					START_YEAR=1980
				
				# Check upper bounds
				elif [ "$START_YEAR" -ge "$CUR_YEAR" ] ; then
					echo "The starting year needs to be less than this year. Aborting."
					exit 1
				fi

			# Not an integer. Exit.
			else
				echo "Invalid starting year $START_YEAR. Please check your input."
				exit 1
			fi
			;;

		# e - End Year
		e)
			END_YEAR=${OPTARG}
			
			# Check that it is an integer
			if [ "$END_YEAR" -eq "$END_YEAR" ] 2>/dev/null ; then

				# Check upper bounds 
				if [ "$END_YEAR" -gt "$(($CUR_YEAR - 1 ))" ] ; then
					END_YEAR=$(($CUR_YEAR - 1 ))
					echo "The starting year needs to be at most $(($CUR_YEAR - 2 )). Defaulting to $(($CUR_YEAR - 2 ))."
				
				# Check lower bounds
				elif [ "$END_YEAR" -lt 1980 ] ; then
					echo "The ending year needs to be greater than or equal to 1980. Aborting."
					exit 1
				fi

			# Not an integer. Exit.
			else
				echo "Invalid starting year $END_YEAR. Please check your input."
				exit 1
			fi
			;;
			
		# d - Location of Daymet DEM 
		d) 
			# Check that the file exists
			if [ -e ${OPTARG} ] ; then
				# Save it 
				DAYMET_DEM=${OPTARG}
			fi

			;;

		# P - Password file 
		P)
			# Check the file exists 
			if [ -e ${OPTARG} ] ; then 
				PASSWORD=${OPTARG}
			fi
			;;

		# Unknown entry, print usage and exit with a non-zero status
		*)
			echo "Usage: trad_eemt.sh [-i input directory] [-o output directory] [-p project name]"
			echo "	[-s starting year] [-e ending year] [-d Daymet DEM]"
			echo
			
			echo "-i 	Specifies the directory that contains the Open Topography data. Files can be stored as a .tif or still be archived as .tar.gz. The metadata file needs to be included. Defaults to current directory."
			echo

			echo "-o 	Specifies the directory where the completed transfer model should be stored. Defaults to the current directory."
			echo
			
			echo "-p 	Specifies the project name used by makeflow. Workers will need the project name to connect to the makeflow process. Defaults to trad_eemt."
			echo

			echo "-s 	Specifies the starting year for generating the EEMT model. Dayment data starts in 1980. If a year is not specified, or the year is too early, 1980 is used."
			echo			

			echo "-e 	Specifies the end year for generating the EEMT model. Yearly Daymet data is posted in the following June. If a year is not specified or the year is in the current year or later, it will default to last year."
			echo

			echo "-d 	Specifies the location of the Daymet DEM. The filename must be na_dem.tif. "
			echo

			echo "-P 	Specifies the password file to use for Work Queue. A Copy of this file needs to be accessible by each worker before it can connect to the master process. Optional. "

			exit 1	
	esac
done	# End argument reading

# Sanity check the arguments

# Check that the starting year < ending year
if [ "$START_YEAR" -gt "$END_YEAR" ] 2>/dev/null ; then
	TEMP=$END_YEAR
	END_YEAR=$START_YEAR
	START_YEAR=$TEMP

	echo "Starting and Ending years were transposed. Ending year is now $END_YEAR. Starting year is now $START_YEAR"
fi

# Print selected values, give user option to abort
echo $'\n\t---- Values Used ----\n'
echo "Start Year        : $START_YEAR"
echo "End Year          : $END_YEAR"
echo "Input Directory   : $INPUT_DIR"
echo "Output Directory  : $OUTPUT_DIR"
echo "Project Name      : $PROJ_NAME"

# If no password is specified, then tell the user
if [ -z $PASSWORD ] ; then 
	echo "Password File     : None Specified "
else 
	echo "Password File     : $PASSWORD"
fi

# If the DEM isn't specified, and isn't found in the specified directory, download it
if [ ! -e "${INPUT_DIR}${DAYMET_DEM}na_dem.tif" ] ; then
	echo "Daymet DEM        : Downloaded from iPlant"

# Otherwise, show the user what they specified
else
	echo "Daymet DEM        : ${INPUT_DIR}${DAYMET_DEM}na_dem.tif"
fi


echo
read -p "Hit [Ctrl]-[C] to abort, or any key to start processing...."
echo

wait

# Finished reading the command line input

# Initialize iCommands for downloading
iinit

# Process inputs to prepare for parallel commands
python ${SRC}/src/read_meta.py $INPUT_DIR $DAYMET_DEM

# If read_meta.py failed, don't continue executing
if [ $? -ne 0 ] ; then
	echo
	echo "Failed processing input data. Please check errors. Aborting...."
	echo
	exit 1
fi

cd $INPUT_DIR
# Download Daymet Information
python2.7 ${SRC}/src/process_dem.py ${START_DIR}/${INPUT_DIR}pit_c.tif $START_YEAR $END_YEAR tmin tmax prcp

# If process_dem.py failed, don't continue executing
if [ $? -ne 0 ] ; then
	echo
	echo "Failed downloading Daymet data. Please check errors. Aborting...."
	echo
	exit 1
fi

cd $START_DIR

echo
echo "Starting task generation....."
echo

if [ ! -d ${OUTPUT_DIR}/trad ] ; then
	mkdir ${OUTPUT_DIR}/trad
fi

if [ ! -d ${OUTPUT_DIR}/topo ] ; then
	mkdir ${OUTPUT_DIR}/topo
fi

if [ ! -d ${OUTPUT_DIR}/sun ] ; then 
	mkdir ${OUTPUT_DIR}/sun
fi

# Start makeflow 
${SRC}/src/eemt_queue.py $PROJ_NAME $INPUT_DIR $OUTPUT_DIR $START_YEAR $END_YEAR $PASSWORD 

if [ $? -ne 0 ] ; then
	echo
	echo "Failed to generate the EEMT Models. Look at the error messages for more information. Aborting."
	echo
	exit 1
fi

# Finished creating model. Organize data.
echo
echo "Organizing output...."
echo

# Remove unnecessary files

echo 
echo "Finished tasks."
echo