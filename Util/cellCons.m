function str = cellCons(strs, delimiter)
%CELLCONS Concatenates the strings in the given cell array, separated
% with the given delimiter.
%
% Inputs:
%   strs      - cell array of strings.
%   delimiter - Delimiter to use.
%
% Outputs:
%   str       - A string containing the strings in the given cell array,
%               concatenated with the given delimiter.
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
  
  if ~iscellstr(strs),   error('strs must be a cell array');  end
  if ~ischar(delimiter), error('delimiter must be a string'); end
  
  str = cellfun(@(x)([x delimiter]), strs, 'UniformOutput', false);
  
  str = [str{:}];
  str = str(1:end-length(delimiter));
  
end
