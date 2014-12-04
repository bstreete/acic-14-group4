#!/usr/bin/env python

from work_queue import *
import os
import sys
import glob

"""
Arguments List:
1 - Project Name 
2 - Password File
3 - Input Directory
4 - Starting Year
5 - Ending Year
"""

def driver(args):

	# Initial Argument Verification
	if len(args) != 6: 
		print 'Usage: %s project_name password_file input_dir start_year end_year' % args[0]
		print 'All fields are required in the specified order. Aborting.'
		sys.exit(1)

	# Save the directories
	input_dir = os.path.join(os.getcwd(), args[3])
	password_file = os.path.join(os.getcwd(), args[2])
	# script_dir = os.path.join(os.getcwd(), src)

	# Check the input directory then change to it
	if os.path.isdir(input_dir):
		try:
			os.chdir(input_dir)
		except OSError: 
			print 'Unable to change to input directory. Please verify the path and associated permissions.'
			print 'Given directory: %s' % input_dir

			sys.exit(1)
	else:
		print 'Input directory does not exist. Please verify the path and associated permissions.'
		print 'Given directory: %s' % input_dir

		sys.exit(1)

	# Check for a password file before starting work queue
	if not os.path.isfile(password_file):
		print 'Invalid password file specified. Please verify the path and associated permissions.'
		print 'Given filename: %s' % password_file

		sys.exit(1)
	# Finished checking arguments

	# Initiate the Queue
	wq = init_wq(args[1], password_file)

	# Create the tasks
	wq, total = create_tasks(wq, args[4], args[5])

	# Wait for Completion
	start_wq(wq, total)

	sys.exit(0)
# End driver(args)

def init_wq(name, password_file): 
	"""
	Initializes the work queue instance with the specified project 
	name and password file. Assumes these were already verified 
	before calling this function. 
	"""

	# Try to create the queue with a random port and specified name
	try:
		wq = WorkQueue(0)
		wq.specify_name(name)
		wq.specify_password_file(password_file)
		print 'Started Work Queue process with project name %s\n' % name
		
	# Catch the errors
	except:
		print 'Failed to initialize work queue process. Aborting'
		sys.exit(1)

	return wq
# End init_wq(name, password_file)

def create_tasks(wq, start, end):
	"""
	Creates the tasks needed to generate R.Sun for the area of interest,
	upscale Daymet's weather information in the given area to match the 
	resolution of the non-Daymet input, and generates the final EEMT model
	from the upscaled inputs.
	"""

	print 'Preparing to generate solar irradiation model....\n'
	# Generate the R.Sun calculations first
	wq, sun_total = calc_sun(wq)

	print 'Preparing to upscale weather data....\n'
	# Generate the Upscaled weather data/EEMT model
	wq, model_total = calc_model(wq, start, end) 

	total = sun_total + model_total

	print 'Submitted %d individual jobs. Processing.\n' % total

	return wq, total
# End create_tasks()

def calc_sun(wq): 
	"""
	Generates the Work Queue tasks to calculate r.sun for every 
	day of the year with a time step of 0.05 for the given input
	area and submits them to the queue. Returns the updated queue
	and a count of how many tasks were submitted. 
	"""

	total = 0 
	script = 'src/rsun.sh'
	dem = 'pit_c.tif'
	
	# Start iterating over the days of the year
	for day in xrange(1,366):
	
		# Generate the names of the output files
		sun_flat = 'sun_%d_flat' % day
		sun_total = 'sun_%d_total' % day

		command = '%s %s %d %s %s' % (script, dem, day, 
			sun_flat, sun_total)

		print command
		# Create the task
		t = Task(command)

		# Specify input and output files
		t.specify_file(script, script, WORK_QUEUE_INPUT, cache = True)
		t.specify_file(dem, dem, WORK_QUEUE_INPUT, cache = True)
		t.specify_file(sun_flat, sun_flat, WORK_QUEUE_OUTPUT, cache = True)
		t.specify_file(sun_total, sun_total, WORK_QUEUE_OUTPUT, cache = True)

		wq.submit(t)
		total += 1

	return wq, total

# End calc_sun(wq)

def calc_model(wq, start, end):
	"""
	Generates the work queue tasks to upscale all of the climate 
	data downloaded from Daymet for the appropriate input area. Once the 
	inputs are generated, the final EEMT model tasks are generated
	and submitted. Returns the updated queue and a count of how many tasks
	were created. 
	"""

	total = 0 
	files = list()

	files.append('pit_c.tif')
	files.append('twi_c.tif')
	files.append('na_dem.part.tif')
	script = 'src/reemt.sh'

	# Loop here 
	for day in range(1, 366): 

		for year in range(int(start), int(end) + 1): 
			# wildcard for tmin
			tmin = glob.glob('daymet/*/*_%d_tmin.tif' % year)
			# wildcard for tmax
			tmax = glob.glob('daymet/*/*_%d_tmax.tif' % year)
			# wildcard for prcp
			prcp = glob.glob('daymet/*/*_%d_prcp.tif' % year)

			files.insert(tmin[0], 1)
			files.insert(tmax[0], 2)
			files.insert(prcp[0], 4)

			command = '%s %s %d' % (script, ' '.join(files), day)

			print command

			t.Task(command)

			# List all of the necessary input files 
			for filename in files: 
				t.specify_file(filename, filename, WORK_QUEUE_INPUT, 
					cache = True)

			# Insert the executable 
			t.specify_file(script, script, WORK_QUEUE_INPUT, 
				cache = True)

			# Specify the output file
			t.specify_file(output, output, WORK_QUEUE_OUTPUT, cache = False)

			wq.submit(t)
			total += 1
		# End loop

	return wq, total
# End calc_model(wq)

def start_wq(wq, total): 
	"""
	Starts listening for completed work queue tasks, and prints a message
	every time a task is completed. Will attempt to resubmit failed jobs
	with the exact same parameters. 
	"""
	# Check every 5 seconds for completed tasks
	while not wq.empty(): 
		t = wq.wait(5)

		if t: 
			print 'Finished task %d of %d. %2.2f%% completed.' % (t.id, total, float(t.id / total))

			if task.return_status != 0:
				print 'Task %d failed. Resubmitting.'
				wq.submit(t)
				total += 1 


	print 'Finished generating the EEMT model. '
# End start_wq(wq)

if __name__ == '__main__':
	sys.exit(driver(sys.argv))