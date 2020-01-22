@echo off
echo "Loading the IMOS-Toolbox Tests..."
matlab -nosplash -nodesktop -r "batchTesting(0)"
echo "Please check the tests reports in the command line window..."
@pause
