@echo off
if exist data (
echo "Loading the IMOS-Toolbox Tests..."
matlab -nosplash -nodesktop -r "batchTesting(0)"
echo "Please check the tests reports in the command line window...") else (
echo "Cannot run tests - please obtain all test files first with the get_testfiles.py script."
)
@pause
