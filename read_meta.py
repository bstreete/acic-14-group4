#!/usr/bin/env python
import os
from subprocess import Popen, PIPE
from glob import glob
import sys
import decimal
import ConfigParser
from tiffParser import TiffParser

def driver(): 
	"""
	Handles the execution of the program. Changes the working directory, un-archives all of the files in the directory, merges the partitioned TIFs into a single master TIF for each dataset, then converts the TIFs from their current projections to the projection defined by Daymet. 
	"""

	# Change to passed directory, if applicable
	try:
		if len(sys.argv) == 2:
			os.chdir(sys.argv[1])

		elif len(sys.argv) > 2:
			print "Too many arguments passed."
			print "Usage: %s [directory]" % sys.argv[0]
			sys.exit(1)

	except OSError:
		print "Directory not found."
		print "Usage: %s [directory]" % sys.argv[0]
		sys.exit(1)

	# Untar all of the files in the working directory before merging 
	# Then remove the old archives. 

	print '\nExtracting archived DEMs from Open Topography....\n'
	path = os.path.join(os.getcwd(), '*.tar.gz')
	extract_dems(glob(path))
	
	# Need to merge subfiles for each DEM output into a single TIFF
	# And remove the now unneeded partial DEMs

	# print 'Merging tiled DEMs...\n'

	# # D Infinity Catchment Area
	# print 'Merging catchment DEMs....'
	# path = os.path.join(os.getcwd(), "scap*.tif")
	# merge_files(glob(path), 'catch_total.tif')

	# print 'Merging flow DEMs....'
	# # D Infinity Flow 
	# path = os.path.join(os.getcwd(), "angp*.tif")
	# merge_files(glob(path), 'flow_total.tif')

	# print 'Merging slope DEMs....'
	# # D Infinity Slope
	# path = os.path.join(os.getcwd(), "slpp*.tif")
	# merge_files(glob(path), 'slope_total.tif')

	# print 'Merging pit remove DEMs....'
	# # Pit Remove 
	# path = os.path.join(os.getcwd(), 'felp*.tif')
	# merge_files(glob(path), 'pit_total.tif')

	print '\nMerging TWI DEMs....'
	# Total Wetness Index
	path = os.path.join(os.getcwd(), 'twip*.tif')
	merge_files(glob(path), 'twi.tif')
	
	# Read the metadata to determine what projection to warp 
	# After reading, it will pass the projection info to convert_opentopo 
	# to update all of the available TIF files
	read_meta() 

	# Take the useful information out of the Daymet DEM
	window_daymet()

# End driver() 

def extract_dems(path):
	"""
	Extracts all files ending with .tar.gz in the currrent directory. After a successful execution, delete the extracted archive. 
	"""
	
	for archive in path:

		# Setup command for each file
		command = ['tar', 'zxf'] 
		command.append(archive)

		process = Popen (command, stdout=PIPE, shell=False)
		stdout, stderr = process.communicate()

		if process.returncode != 0: 
			print '\tErrors encountered extracting %s.\n' % archive
			print stderr

		# Successfully untarred/ungzipped specified archive
		else:
			# os.remove(archive)
			print '\tFinished extracting contents of %s. ' % archive
		# Remove the filename for next iteration
		command.remove(archive)

# End extract_dems()

def merge_files(path, output): 
	"""
	Merges the filenames passed into a single TIFF file with gdalwarp. Assumes that the system running the application has at least 2 GB of available memory. Deletes the individual chunks of the file after creating the single combined TIFF. 
	"""

	# Create the command to execute
	command = ['gdalwarp', '-overwrite'] 
	command.extend(path)
	command.append(output)

	# Execute the command
	process = Popen(command, stdout=PIPE, shell=False)
	stdout, stderr = process.communicate()

	if process.returncode != 0:
		print stderr
	else:
		# Remove the partitioned files
		for part in path: 
			os.remove(part)
		print 'Finished merging %s.\n' % output
		
# End merge_files()

def read_meta():
	"""
	Opens up any metadata*.txt files in the local directory or specified directory if there is one.
	It will search the files for the EPSG code defining the projection as well as the current zone.
	This data is saved in a dictionary named coords that is passed to the next functions.
	"""

	# Try opening the file and searching
	try:
		path = os.path.join(os.getcwd(), "metadata*.txt")
		proj_info = dict()

		# Try to open the file and read contents
		for meta_file in glob(path):
			with open(meta_file) as meta:
				for line in meta.readlines():

					# If the line contains the EPSG Code
					if line.startswith("Horizontal Coordinates:"):
						proj_info['region'] = line[-8:-3]
						proj_info['zone'] = proj_info['region'][-2:] + 'n'
	except IOError:
		print 'Unable to open file.'
		sys.exit(1)

	# Make sure that all of the data was read successfully
	if len(proj_info) != 2:
		print 'Coordinates not found. Verify that the metadata file exists in %s and is complete.' % os.getcwd()
		sys.exit(1)

	else:
		# Convert the DEMs to Daymet's projection
		print 'Converting OpenTopography DEMs to Daymet\'s projection.'
		convert_opentopo(proj_info)

		print 'Finished warping OpenTopography.\n' 

# End read_meta()



def convert_opentopo(proj_info):
	"""
	Creates another .tif file with the name .converted.tif for every .tif file located
	in the passed directory.The converted.tif file is supposed to be converted into the Daymet
	custom projection. Depends on theread_meta() method executing correctly. It doesn't check
	for the converted files before executing. Once the files are generated, script will call
	gdalinfo and try to parse the new coordinates from the output. The corner coordinates are
	returned in a list. Since everything is related to Daymet, it assumes the data is in the
	North and West hemispheres.
	"""

	# Command string to convert the DEM files from Open Topography to DAYMET's projection
	command = ['gdalwarp', '-s_srs', 'EPSG:' + proj_info['region'], '-overwrite', '-t_srs',
			   "+proj=lcc +lat_1=25 +lat_2=60 +lat_0=42.5 +lon_0=-100 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs",
			   '-r', 'bilinear', '-of', 'GTiff', '-tr', '10', '-10']

	# Need to execute for each .tif file from OpenTopo
	path = ['output.mean.tif', 'twi.tif']

	for dem_file in path:

		# Create the output file name
		dem_output = dem_file[:-4] + '.converted.tif'

		print "\tCreating %s." % dem_output

		# Add the filenames to the end of the list
		command.append(dem_file)
		command.append(dem_output)

		# Execute the gdalwarp command
		process = Popen(command, stdout=PIPE, shell=False)

		# Check for errors
		stdout, stderr = process.communicate()

		if process.returncode != 0:
			print stderr

		# Remove the original file
		else:
			# os.remove(dem_file)
			print '\tSuccessfully created %s.\n' % dem_output

		# Remove the filenames for next iteration
		command.remove(dem_file)
		command.remove(dem_output)

# End convert_opentopo()
	
def window_daymet():
	"""
	Shrinks the Daymet DEM to include only relevant data to the Open
	Topography data set. 
	"""

	print 'Download and convert Daymet DEM.'
	# Parse dem file
	demParser = TiffParser()
	demParser.loadTiff('output.mean.converted.tif')
    
    # get coordinates
	coords = demParser.getProjCoords()

	# Check for the Daymet DEM
	if not os.path.isfile('na_dem.tif'):
		# If it's not there, download it
		command = ['iget', '/iplant/home/tyson_swetnam/DAYMET/NA_DEM/na_dem.tif']
		process = Popen(command, stdout=PIPE, shell=False)

		print '\tDownloading Daymet DEM....'
		out, err = process.communicate()

		if process.returncode != 0:
			print 'Failed to download.\n'
			print err
			sys.exit(1)

		print '\tFinished downloading.\n'

	else:
		print '\tDaymet DEM detected. Processing.'

	command = ['gdal_translate', '-projwin', coords[1][0], coords[1][1], coords[0][0], coords[0][1], 
		'na_dem.tif', 'na_dem.part.tif']

	print '\tPartitioning Daymet....'

	process = Popen(command, stdout=PIPE, shell=False)

	out, err = process.communicate()

	if process.returncode != 0:
		print 'Failed to partition Daymet DEM. \n'
		print err
		sys.exit(1)

	print 'Finished partitioning Daymet DEM as na_dem.part.tif.\n'

# End window_daymet()

driver()