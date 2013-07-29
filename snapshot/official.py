#!/usr/bin/python

import os
import sys
import time
import shutil
import ziputil

# official.py
# Exports the IMOS Toolbox from SVN and
#
#   - Creates an archive of the source 
#   - Runs Util/imosPackage.m to to package the source
# 
# These files are submitted back to the project as file downloads.
#
# python, svn (SlikSvn) and matlab must be on PATH
#

lt = time.localtime()
at = time.asctime()

project = 'imos-toolbox'

def googleSubmit(archive, summary):

  username = 'guillaume.galibert@gmail.com'
  password = 'myPasswordSVN' # SVN password!!!
  labels   = 'Featured'

  print('\n--submitting %s to google' % archive)
  cmd = 'python googlecode_upload.py'
  cmd = ' %s -s "%s"' % (cmd,summary)
  cmd = ' %s -p %s'   % (cmd,project)
  cmd = ' %s -u %s'   % (cmd,username)
  cmd = ' %s -w %s'   % (cmd,password)
  cmd = ' %s -l "%s"' % (cmd,labels)
  cmd = ' %s %s'      % (cmd,archive)
  
  os.system(cmd)

version    = '2.3'
  
url        = 'http://%s.googlecode.com/svn/trunk' % project
exportDir  = 'export'
stdArchive = 'imos-toolbox-%s.zip' % version

stdSummary  = 'IMOS Toolbox %s (standalone + source)' % version
compilerLog = '.\%s\log.txt' % exportDir

#
# export from SVN
#
print('\n--exporting tree from %s to %s' % (url, exportDir))
os.system('svn export %s %s' % (url, exportDir))

#
# remove Tests and snapshot directories
#
print('\n--removing Tests and snapshot')
shutil.rmtree('%s/Tests' % exportDir)
shutil.rmtree('%s/snapshot' % exportDir)

#
# create snapshot
#
print('\n--creating snapshot')
matlabOpts = '-nodisplay -wait -logfile "%s"' % compilerLog
matlabCmd = "addpath('Util'); try, imosPackage(); exit(); catch e, disp(e.message); end;"
os.system('cd %s && matlab %s -r "%s"' % (exportDir, matlabOpts, matlabCmd))
shutil.copy('%s/imos-toolbox.zip' % exportDir, './%s' % stdArchive)

try:
  googleSubmit(stdArchive, stdSummary)

except:
  print('\n--Snapshot upload error. Check script, fix and then delete previous files before running new snapshot')

print('\n--removing local SVN tree and archives')
shutil.rmtree('%s' % exportDir)
os.remove(stdArchive)
