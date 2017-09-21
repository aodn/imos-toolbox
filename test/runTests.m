function runTests()
%RUNTESTS Runs the different unit tests.
%
% Author:       Guillaume Galibert <guillaume.galibert@utas.edu.au>
%

%
% Copyright (C) 2017, Australian Ocean Data Network (AODN) and Integrated 
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

% You should have received a copy of the GNU General Public License
% along with this program.
% If not, see <https://www.gnu.org/licenses/gpl-3.0.en.html>.
%

path = pwd;
    
% set Matlab path for this session (add all recursive directories to Matlab
% path)
searchPath = textscan(genpath(path), '%s', 'Delimiter', pathsep);
searchPath = searchPath{1};
iPathToRemove = ~cellfun(@isempty, strfind(searchPath, [filesep '.']));
searchPath(iPathToRemove) = [];
searchPath = cellfun(@(x)([x pathsep]), searchPath, 'UniformOutput', false);
searchPath = [searchPath{:}];
addpath(searchPath);

% run the unit tests
testOxygenPP();
testSBE19Parse();

end

