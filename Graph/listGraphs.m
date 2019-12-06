function graphs = listGraphs()
%LISTGRAPHS Returns a cell array containing the names of all available
%graphing functions.
%
% Graph functions live in the Graph subdirectory, and are named according
% to the format:
%
%   graph[GraphType].m
%
% This function simply searches the subdirectory looking for files which
% match the above pattern, and returns the names of those files, minus the 
% 'graph' prefix, and the '.m' suffix. The graphTimeSeries function is the
% de-facto standard; this entry (if it exists) is explicitly placed at the
% start of the returned cell array.
%
% Outputs:
%   graphs - cell array of strings, each of which is the name of a graph
%            function. The caller must add the 'graph' prefix before
%            converting the name into a callable function.
%
% Author: Paul McCarthy <paul.mccarthy@csiro.au>
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

path = '';
if ~isdeployed, [path, ~, ~] = fileparts(which('imosToolbox.m')); end
if isempty(path), path = pwd; end
path = fullfile(path, 'Graph');

pattern = '^graph(.+)\.m$';

graphs  = listFiles(path, pattern);

% place timeseries at the start
ts = find(ismember(graphs, 'TimeSeries'));
if ~isempty(ts)
  
  graphs(ts) = [];
  graphs     = ['TimeSeries' graphs];
end
