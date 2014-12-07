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
4 - Output Directory
5 - Starting Year
6 - Ending Year

It assumes that is has been called from the root directory of the project,
and uses the appropriate relative paths to the individual scripts. 
"""

def driver(args):

	# Initial Argument Verification
	if len(args) != 7: 
		print 'Usage: %s project_name password_file input_dir output_dir start_year end_year' % args[0]
		print 'All fields are required in the specified order. Aborting.'
		sys.exit(1)

	# Save the directories
	input_dir = args[3]
	output_dir = args[4]
	password_file = os.path.join(os.getcwd(), args[2])

	# Check the input directory then change to it
	if not os.path.isdir(input_dir):	
		print 'Input directory does not exist. Please verify the path and associated permissions.'
		print 'Given directory: %s' % input_dir

		sys.exit(1)

	if not os.path.isdir(output_dir):
		print 'Output directory does not exist. Please verify the path and associated permissions.'
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
	wq, total = create_tasks(wq, input_dir, output_dir, args[5], args[6])

	print 'Workqueue is listening for project %s.\n' % args[1]
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

	port = 9123
	while True:
		# Try to create the queue with a random port and specified name
		try:
			wq = WorkQueue(port)
			wq.specify_name(name)
			# wq.specify_password_file(password_file)
			cctools_debug_flags_set('all')
			print 'Started Work Queue process with project name %s\n' % name
			break
		# Catch the errors
		except:
			print 'Failed to initialize work queue process on port %d. Retrying.' % port
			port += 1

		if port > 10000:
			print 'Unable to start work queue process. Aborting.'
			sys.exit(1)

	return wq
# End init_wq(name, password_file)

def create_tasks(wq, input_dir, output_dir, start, end):
	"""
	Creates the tasks needed to generate R.Sun for the area of interest,
	upscale Daymet's weather information in the given area to match the 
	resolution of the non-Daymet input, and generates the final EEMT model
	from the upscaled inputs.
	"""

	print 'Preparing to generate solar irradiation model....\n'
	# Generate the R.Sun calculations first
	wq, sun_total = calc_sun(wq, input_dir, output_dir)

	print 'Preparing to upscale weather data....\n'
	# Generate the Upscaled weather data/EEMT model
	wq, model_total = calc_model(wq, input_dir, output_dir, start, end) 

	total = sun_total + model_total

	print 'Submitted %d individual jobs. Processing.\n' % total

	return wq, total
# End create_tasks()

def calc_sun(wq, input_dir, output_dir): 
	"""
	Generates the Work Queue tasks to calculate r.sun for every 
	day of the year with a time step of 0.05 for the given input
	area and submits them to the queue. Returns the updated queue
	and a count of how many tasks were submitted. 
	"""

	total = 0 
	script = 'src/rsun.sh'
	dem = input_dir + 'pit_c.tif'
	

	# Start iterating over the days of the year
	for day in xrange(1,366):
	
		# Generate the names of the output files
		sun_flat = output_dir + 'sun_%d_flat.tif' % day
		sun_total = output_dir + 'sun_%d_total.tif' % day

		command = './rsun.sh pit_c.tif %s sun_%d_total.tif sun_%d_flat.tif' % (day, day, day)

		# Create the task
		t = Task(command)

		# Specify input and output files
		t.specify_input_file(script, remote_name = 'rsun.sh', cache = True)
		t.specify_input_file(dem, remote_name =  'pit_c.tif', cache = True)
		t.specify_output_file(sun_flat, remote_name = 'sun_%d_flat.tif' % day, cache = True)
		t.specify_output_file(sun_total, remote_name =  'sun_%d_total.tif' % day, cache = True)

		taskid = wq.submit(t)
		total += 1
	# End loop

	return wq, total

# End calc_sun(wq)

def calc_model(wq, input_dir, output_dir, start, end):
	"""
	Generates the work queue tasks to upscale all of the climate 
	data downloaded from Daymet for the appropriate input area. Once the 
	inputs are generated, the final EEMT model tasks are generated
	and submitted. Returns the updated queue and a count of how many tasks
	were created. 
	"""

	total = 0 
	files = list()

	files.append(input_dir + 'pit_c.tif')
	files.append(input_dir + 'twi_c.tif')
	files.append(input_dir + 'na_dem.part.tif')
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

			sun_flat = output_dir + 'sun_%d_flat.tif' % day
			sun_total = output_dir + 'sun_%d_total' % day

			files.insert(1, tmin[0])
			files.insert(2, tmax[0])
			files.insert(4, prcp[0])
			files.append(sun_total)
			files.append(sun_flat)

			output = output_dir + 'eemt_%d_%d.tif' % (year, day)

			command = '%s %s %s' % (script, ' '.join(files), output)

			t = Task(command)

			# List all of the necessary input files 
			for filename in files: 
				t.specify_file(filename, filename, WORK_QUEUE_INPUT, 
					cache = True)

			# Insert the executable 
			t.specify_file(script, script, WORK_QUEUE_INPUT, 
				cache = True)

			# Specify the output file
			t.specify_file(output, output, WORK_QUEUE_OUTPUT, cache = False)

			# Remove the files that have variable names
			files.remove(tmin[0])
			files.remove(tmax[0])
			files.remove(prcp[0])
			files.remove(sun_total)
			files.remove(sun_flat)

			taskid = wq.submit(t)

			total += 1
		# End yearly loop
	# End daily loop

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
			if t.return_status == 0: 
				print 'Finished task %d of %d. %2.2f%% completed.' % (t.id, total, float(t.id / total))

			else:

				print 'Task failed: \n\tLogs: \n'
				print t.output
				print 'Task %d failed. Resubmitting.' % t.id
				wq.submit(t)
				total += 1 

	print 'Finished generating the EEMT model. '
# End start_wq(wq)

if __name__ == '__main__':
	sys.exit(driver(sys.argv))