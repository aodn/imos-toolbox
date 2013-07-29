#!/usr/bin/python

import os
import sys
import time
import shutil
import ziputil
import gmail

# official.py
# Exports the IMOS Toolbox from SVN and
#
#   - Creates an archive of the source 
#   - Runs Util/imosCompile.m to create a standalone executable archive
# 
# Both of these files are submitted back to the project as file downloads.
#
# python, svn (SlikSvn), javac, ant and matlab must be on PATH
# JAVA_HOME must be set
#

lt = time.localtime()
at = time.asctime()

project = 'imos-toolbox'

def googleSubmit(archive, summary):

  username = 'guillaume.galibert@gmail.com'
  password = 'dZ2JH2wD4ad2' # SVN password!!!
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
# build DDB interface
#
print('\n--building DDB interface')
compiled = os.system('cd %s/Java && ant install' % exportDir)

if compiled is not 0:
  print('\n--DDB interface compilation failed - cleaning')
  os.system('cd %s/Java && ant clean' % exportDir)
  gmail.send(
    "guillaume.galibert@utas.edu.au",
    "[imos-toolbox] DDB interface compilation error",
    "Check the Java DDB interface code",
    None,
    "guillaume.galibert",
    "28gg=!bb")

#
# create snapshot
#
print('\n--creating snapshot')
matlabOpts = '-wait -nosplash -nodesktop -logfile "%s"' % compilerLog
matlabCmd = "addpath('Util'); try, imosCompile(); exit(); catch e, disp(e.message); end;"
os.system('cd %s && matlab %s -r "%s"' % (exportDir, matlabOpts, matlabCmd))
shutil.copy('%s/imos-toolbox.zip' % exportDir, './%s' % stdArchive)

try:
  googleSubmit(stdArchive, stdSummary)

except:
  if os.path.exists(compilerLog):
    attachment = compilerLog
  else:
    attachment = None
  
  gmail.send(
    "guillaume.galibert@utas.edu.au",
    "[imos-toolbox] Snapshot upload error",
    "Check the snapshot script. Fix, then delete previous files before runnning new snapshot.",
    attachment,
    "guillaume.galibert",
    "28gg=!bb")

print('\n--removing local SVN tree and archives')
shutil.rmtree('%s' % exportDir)
os.remove(stdArchive)
