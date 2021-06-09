#!/usr/bin/env sh
if [ -d "data" ]; then
  matlab -nosplash -nodesktop -r "batchTesting(1,1);exit"
else
  echo "Cannot run tests - please obtain all test files first with the get_testfiles.py script."
  exit 1
fi
