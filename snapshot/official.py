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
# python, svn (SlikSvn), scp and matlab must be on PATH
#

lt = time.localtime()
at = time.asctime()

project = 'imos-toolbox'

def submit(archive):

  user     = 'ggalibert'
  server   = '10-nsp-mel.emii.org.au'
  dir      = '/mnt/imos-t4/IMOS/public/eMII/softwares/imos-toolbox'
  http_url = 'http://data.aodn.org.au/IMOS/public/eMII/softwares/imos-toolbox/'

  print('\n--submitting %s to %s' % (archive,http_url))
  cmd = 'scp %s %s@%s:%s' % (archive,user,server,dir)
  
  os.system(cmd)

version    = '2.5'
  
url        = 'https://github.com/aodn/%s.git' % project
exportDir  = 'export'
stdArchive = 'imos-toolbox-%s.zip' % version

compilerLog = './%s/log.txt' % exportDir

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
# create snapshot
#
print('\n--creating snapshot')
matlabOpts = '-nodisplay -wait -logfile "%s"' % compilerLog
matlabCmd = "addpath('Util'); try, imosPackage(); exit(); catch e, disp(e.message); end;"
os.system('cd %s && matlab %s -r "%s"' % (exportDir, matlabOpts, matlabCmd))
shutil.copy('%s/imos-toolbox.zip' % exportDir, './%s' % stdArchive)

try:
  submit(stdArchive)

except:
  print('\n--Snapshot upload error. Check script, fix and then delete previous files before running new snapshot')

print('\n--removing local git tree and archives')
shutil.rmtree('%s' % exportDir)
os.remove(stdArchive)
