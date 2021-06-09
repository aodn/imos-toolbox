@echo off
if exist data (
echo "Loading the IMOS-Toolbox Tests..."
matlab -nosplash -r "batchTesting(0,1);"
echo "Please check the tests reports in the command line window...") else (
echo "Cannot run tests - please obtain all test files first with the get_testfiles.py script."
)
@pause
