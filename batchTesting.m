function batchTesting(parallel)
% function batchTesting(parallel)
%
% Execute all the xunit Test functions of the toolbox
% in batch mode.
%
% Inputs:
%
% parallel - true for parallel execution
%
% Example:
%
% batchTesting(1)
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

csplit = strsplit(mfilename('fullpath'),[ filesep 'batchTesting']);
root_folder = csplit{1};
addpath([root_folder filesep 'Util' filesep 'Path'])
setToolboxPaths(root_folder)

try
    results = runAllTests(parallel)%do not supress report output
catch
    error('Tests failed')
end

failed = {'    Tests failed:\n'};
c = 2;

%pretty print the results of failed tests.
for k = 1:length(results)% loop through all results
    ktest = results(k); %get k-results

    if ~ktest.Passed
        fparam = extract_param(ktest.Name); % extract all test parameters
        fnames = fieldnames(fparam); %get parameter names
        fnames = fnames(2:end); % remove the testname from the list

        %now create a pretty string
        fstr = [repmat(' ', 1, length(failed{1})) fparam.testname ':\n'];
        lfstr = length(fstr)

        for kk = 1:length(fnames)
            fstr = [fstr repmat(' ', 1, lfstr) fnames{kk} '->' fparam.(fnames{kk}) '\n'];
        end

        fstr = [fstr '\n'];
        failed{c} = fstr; % store the string for subsequent failed tests if any
        c = c + 1;
    end

end

if length(failed) > 1
    error(sprintf(strjoin(failed)))
end

end

function params = extract_param(namestr)
% function extract_param(namestr)
%
% Extract the name parameters used in the test
% based on the name of the test.
%
% Inputs:
%
% namestr - the name of the test in the TestResult array.
%
% Example:
%
% testname_str='mytest(myparam='abc',myparam2='cba',folder='p__home_user_S');
% params=extract_param(testname_str);
% assert(strcmpi(params.testname,'mytest'))
% assert(strcmpi(params.myparam,'abc'))
% assert(strcmpi(params.myparam2,'cba'))
% assert(strcmpi(params.folder='/home/user'))
%
% author: hugo.oliveira@utas.edu.au

params = struct();

tmp = strsplit(namestr, '(');
tmp2 = strsplit(tmp{1}, fileSep);
params.testname = tmp2{end};

pcell = strsplit(namestr, ',');

tmp = strsplit(pcell{1}, '(');
tmp2 = strsplit(tmp{end}, '=');
pname = tmp2{1};
pval = tmp2{2};
params.(pname) = pval;

for k = 2:length(pcell) - 1
    tmp = strsplit(pcell{k}, '=');
    pname = tmp{1};
    pval = tmp{2};
    params.(pname) = pval;
end

tmp = strsplit(pcell{end}, ')');
tmp2 = strsplit(tmp{1}, '=');
pname = tmp2{1};
pval = tmp2{2};
params.(pname) = pval;

end
