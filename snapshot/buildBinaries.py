#!/usr/bin/python

import os
import sys
import time
import shutil

# buildBinaries.py
# Exports the IMOS Toolbox from SVN and
#
#   - Runs Util/imosCompile.m to create a ddb.jar and imosToolbox executables
# 
# Both of these files are copied to the relevant directory and commited to SVN.
#
# python, git, javac, ant and matlab must be on PATH
# JAVA_HOME must be set
#

lt = time.localtime()

project = 'imos-toolbox'

version    = '2.5'

url        = 'https://github.com/aodn/%s.git' % project
exportDir  = 'export'

compilerLog = '.\%s\log.txt' % exportDir

#
# export from SVN
#
print('\n--exporting tree from %s to %s' % (url, exportDir))
os.system('git clone %s %s' % (url, exportDir))
os.system('cd %s && git checkout %s' % (exportDir, version))

#
# remove snapshot directory
#
print('\n--removing snapshot')
shutil.rmtree('%s/snapshot' % exportDir)

#
# build DDB interface
#
print('\n--building DDB interface')
compiled = os.system('cd %s/Java && ant install' % exportDir)

if compiled is not 0:
  print('\n--DDB interface compilation failed - cleaning')
  os.system('cd %s/Java && ant clean' % exportDir)

#
# create snapshot
#
print('\n--running Matlab unit tests and building binaries')
matlabOpts = '-nosplash -wait -logfile "%s"' % compilerLog
matlabCmd = "addpath('Util', 'test'); try, runTests(); imosCompile(); exit(); catch e, disp(e.message); end;"
os.system('cd %s && matlab %s -r "%s"' % (exportDir, matlabOpts, matlabCmd))

print('\n--removing local git tree')
shutil.rmtree('%s' % exportDir)
