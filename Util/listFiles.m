function hits = listFiles(path, pattern)
%LISTFILES Returns a cell array containing the names of all files in the
% given directory which match the given (regex) pattern.
%
% This function simply searches the given directory looking for files which
% match the given pattern, and returns the names of those files.
%
% Inputs:
%   path    - Name of the directory in which to search. 
%   pattern - Regular expression pattern to match against.
%
% Outputs:
%   hits    - cell array of strings, each of which is the name of a file 
%             in the given directory which matched the given pattern.
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
narginchk(2,2);

if ~ischar(path),    error('path must be a string');    end
if ~ischar(pattern), error('pattern must be a string'); end

hits = {};

% get the contents of the directory
files = dir(path);

%iterate through each element in the directory
for file = files'

  %skip subdirectories
  if file.isdir == 1, continue; end

  %if name matches the pattern, add 
  %it to the list of hits
  token = regexp(file.name, pattern, 'tokens');

  %add the name name to the list
  if ~isempty(token), hits{end + 1} = token{1}{1}; end

end

% sort alphabetical, case insensitive
[ignore idx] = sort(lower(hits));
hits         = hits(idx);
