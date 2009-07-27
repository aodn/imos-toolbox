function imosTests()
%IMOSESTS Runs all of the unit tests in the 'Tests' directory.
%
% Looks in the 'Tests' subdirectory for all files which start with the word
% 'test', and executes them as functions.
%
% Author: Paul McCarthy <paul.mccarthy@csiro.au
%

%
% Copyright (c) 2009, eMarine Information Infrastructure (eMII) and Integrated 
% Marine Observing System (IMOS).
% All rights reserved.
% 
% Redistribution and use in source and binary forms, with or without 
% modification, are permitted provided that the following conditions are met:
% 
%     * Redistributions of source code must retain the above copyright notice, 
%       this list of conditions and the following disclaimer.
%     * Redistributions in binary form must reproduce the above copyright 
%       notice, this list of conditions and the following disclaimer in the 
%       documentation and/or other materials provided with the distribution.
%     * Neither the name of the eMII/IMOS nor the names of its contributors 
%       may be used to endorse or promote products derived from this software 
%       without specific prior written permission.
% 
% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
% AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
% IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
% ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE 
% LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
% CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
% SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
% INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
% CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
% ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
% POSSIBILITY OF SUCH DAMAGE.
%

testPath = [pwd filesep 'Tests'];

tests = dir(testPath);

numExecuted = 0;
numPassed   = 0;
numFailed   = 0;
failNames   = {};
failCauses  = {};

for test = tests'
  
  if test.isdir, continue; end
  if ~strncmp(test.name, 'test', 4), continue; end
  testFunc = str2func(test.name(1:end-2));
  
  numExecuted = numExecuted + 1;
  try
    testFunc();
    numPassed = numPassed + 1;
  catch e
    numFailed = numFailed + 1;
    failNames{end+1} = test.name;
    failCauses{end+1} = e;
  end
end

disp(' ');
disp('-- Test results --');
disp(' ');
disp(['Executed: ' num2str(numExecuted)]);
disp(['Passed:   ' num2str(numPassed)]);
disp(['Failed:   ' num2str(numFailed)]);

for k = 1:length(failNames)
  disp(' ');
  disp(['-- ' failNames{k} ' --']);
  disp(failCauses{k}.message);
end
