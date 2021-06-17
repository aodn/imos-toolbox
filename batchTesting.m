function batchTesting(parallel,print_stats)
% function batchTesting(parallel)
%
% Execute all the xunit Test functions
% and docstring tests
%
% Inputs:
%
% parallel[bool] - true for parallel execution.
% print_stats[bool] = true for printing statistics.
%
% Example:
%
% % trigger all tests hiding the output
% % and running all serially
% %batchTesting(0,1);
%
% author: hugo.oliveira@utas.edu.au
%

% Copyright (C) 2020, Australian Ocean Data Network (AODN) and Integrated
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
narginchk(0, 2)

if nargin == 0
    parallel = false;
    print_stats = true;
elseif nargin == 1
    print_stats = true;
end

csplit = strsplit(mfilename('fullpath'), 'batchTesting');
root_folder = csplit{1};
addpath([root_folder filesep 'Util' filesep 'Path'])
setToolboxPaths(root_folder)

try
    sdisp('Executing `xunit` tests...')
    results = runAllTests(parallel);
    total_xunit_tests = length(results);
catch me
    sdisp('`xunit` tests aborted. Please investigate the error:')
    rethrow(me)
end

xunit_failed = [results(:).Failed];
xunit_n_failed = sum(xunit_failed);
xunit_skipped = ~xunit_failed & [results(:).Incomplete];
xunit_n_skipped = sum(xunit_skipped);
[xunit_failed_files, xunit_failed_tests, xunit_failed_lines] = get_xunit_stats(results(xunit_failed));
[xunit_skipped_files, xunit_skipped_tests, xunit_skipped_lines] = get_xunit_stats(results(xunit_skipped));

try
    sdisp('Executing `docstring` tests...')
    [ok, wrong_files, total_docstring_tests, error_msgs, missing_comment, missing_example] = checkDocstrings(toolboxRootPath());
catch me
    sdisp('Could not run `docstring` tests!')
    rethrow(me)
end

docstring_n_failed = length(wrong_files);
docstring_n_skipped = length(missing_comment) + length(missing_example);

failed_files = [xunit_failed_files, wrong_files];
failed_tests = [xunit_failed_tests, wrong_files];
failed_lines = [xunit_failed_lines, get_docstring_failed_lines(error_msgs)];

total_tests = total_xunit_tests + total_docstring_tests;
total_failed = xunit_n_failed + docstring_n_failed;
total_skipped = xunit_n_skipped + docstring_n_skipped;

total_missing_comment = length(missing_comment);
total_missing_docstrings = length(missing_example);

if ~print_stats
    return
end

sdisp('    ')
sdisp('    ')
sdisp('----IMOS toolbox Test Coverage Summary----')
sdisp('----XUnit` test statistics and `docstrings` inspection in all matlab files in the repository----')
sdisp('    Total number of tests evaluations: %d (%d `xunit` tests and %d docstrings',total_tests,total_xunit_tests,total_docstring_tests);
sdisp('    Total number of failed tests: %d (%d xunit, %d source files)',total_failed,xunit_n_failed,docstring_n_failed);
sdisp('    Total number of skipped tests: %d (%d xunit, %d source files)',total_skipped,xunit_n_skipped,docstring_n_skipped);
sdisp('    ');
if total_failed > 0
    sdisp('Failed tests are:')
    for k=1:length(failed_files)
        if strcmp(failed_files{k},failed_tests{k})
            sdisp('    file/test=%s,line=%s',failed_files{k},failed_lines{k})
        else
            sdisp('    file=%s,test=%s,line=%s',failed_files{k},failed_tests{k},failed_lines{k})
        end
    end
end


if total_skipped > 0
    if ~isempty(xunit_skipped_files)
        sdisp('Skipped xunit tests are:')
        for k=1:length(xunit_skipped_files)
            sdisp('    test=%s',xunit_skipped_files{k})
        end
    end
    if ~isempty(missing_comment)
        sdisp('Skipped docstring tests are:')
        for k=1:length(missing_comment)
            sdisp('    file=%s, reason: missing docstring block',missing_comment{k});
        end
    end

    if ~isempty(missing_example)
        for k=1:length(missing_example)
            sdisp('    test=%s, reason: missing example block',missing_example{k});
        end
    end
end


end

function [failed_files, failed_tests, failed_lines] = get_xunit_stats(results)
n = length(results);
failed_files = cell(1, n);
failed_tests = cell(1, n);
failed_lines = cell(1, n);

for k = 1:n
    test = results(k);
    failed_files{k} = get_testfile(test);
    failed_tests{k} = get_testname(test);
    failed_lines{k} = get_blameline(test);
end

end

function [clines] = get_docstring_failed_lines(error_msgs)
clines = cell(1, length(error_msgs));

for k = 1:length(clines)
    s = find(error_msgs{k} == '(', 1);
    e = find(error_msgs{k} == ')', 1);
    clines{k} = error_msgs{k}(s:e);
end

end

function file = get_testfile(r)

try
    file = r.Details.DiagnosticRecord.Stack(1).file;
catch
    sname = split(r.Name,'/');
    file = sname{1};
end

end

function testname = get_testname(r)

try
    testname = r.Details.DiagnosticRecord.Stack(1).name;
catch
    try
        testname = replace(r.Details.DiagnosticRecord.EventLocation, '/', '.');
    catch
        testname = 'Unknown test';
    end
end

end

function blameline = get_blameline(r)

try
    blameline = r.Details.DiagnosticRecord.Stack(1).line;
catch
    blameline = 'Unknown line';
end

end

function sdisp(varargin)
    disp(sprintf(varargin{:}));
end
