function [results] = runAllTests(parallel)
% function  = runAllTests(parallel)
%
% Run all toolbox tests
%
% Inputs:
%
% parallel - boolean to run the tests in parallel
%    - Default to False
%      Reason: Memory usage is too high and CPU usage is too low.
%
% Outputs:
%
% results - the resulted unittest structure for all tests
%
%
% Example:
% runAllTests(1);
%
% author: hugo.oliveira@utas.edu.au
%

% Copyright (C) 2019, Australian Ocean Data Network (AODN) and Integrated
% Marine Observing System (IMOS).
%
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation version 3 of the License.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with this program.
% If not, see <https://www.gnu.org/licenses/gpl-3.0.en.html>.
%
if nargin < 1
    parallel = false;
end

testfolder = [toolboxRootPath() 'test'];
[~, allfolders] = rdir(testfolder);
suite = testsuite(allfolders);
runner = matlab.unittest.TestRunner.withTextOutput();

if parallel
    results = runInParallel(runner, suite);
else
    results = run(runner, suite);
end
