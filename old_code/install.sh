#!/bin/bash

# Assumes the user is on an Ubuntu machine with root permissions.
# Downloads and installs all of the necessary software for 
# generating the EEMT model, including the group's code.

# Pull new updates
sudo apt-get update -y

# Install Applications
sudo apt-get install -y grass-dev coop-computing-tools python-rpy2 git r-base python-workqueue

# Get iCommands 
wget http://www.iplantcollaborative.org/sites/default/files/irods/icommands.x86_64.tar.bz2
tar jxf icommands.x86_64.tar.bz2

# Update PATH
echo $'\nexport PATH=$PATH:~/icommands' >> .bashrc
source .bashrc

# Clean up extra
cd 
rm icommands.x86_64.tar.bz2

# Download the code and change to directory
git init
git clone https://github.com/bstreete/acic-14-group4.git
