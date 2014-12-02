#!/usr/bin/env python

from work_queue import *

import os
import sys

"""
Arguments List:
1 - Project Name 
2 - Password File
3 - Input Directory
"""

def driver(args):

	# Initial Argument Verification
	if len(args) != 4: 
		print 'Usage: eemt_queue.py project_name password_file input_dir'
		print 'All fields are required in the specified order. Aborting.'
		sys.exit(1)

	# Save the directories
	input_dir = os.path.join(os.getcwd(), args[3])
	password_file = os.path.join(os.getcwd(), args[2])

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
	wq = start_wq(args[1], password_file)

	# Create the tasks
	wq = create_tasks(wq)

	# Wait for Completion

	sys.exit(0)
# End driver(args)

def start_wq(name, password_file): 
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
# End start_wq(name, password_file)

def create_tasks(wq):
	"""
	Creates the tasks needed to generate R.Sun for the area of interest,
	upscale Daymet's weather information in the given area to match the 
	resolution of the non-Daymet input, and generates the final EEMT model
	from the upscaled inputs.
	"""
	# INCOMPLETE

	# Need to verify the filenames of the updated scripts
	print ''

# End create_tasks()

if __name__ == '__main__':
	sys.exit(driver(sys.argv))