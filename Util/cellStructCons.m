function str = cellStructCons(structs, fieldname, delimiter)
%CELLSTRUCTCONS Retrieves the given field from the given structs, and
% returns a string of those fields, separated by the given delimiter.
%
% Inputs:
%   structs   - cell array of structs, all containing a field with the 
%               given fieldname.
%   fieldname - name of the field to concatenate.
%   delimiter - Delimiter to use.
%
% Outputs:
%   str       - A string containing the fields of the given struct,
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
  narginchk(3,3);
  
  if ~iscell(structs),   error('structs must be a cell array'); end
  if ~ischar(fieldname), error('fieldname must be a string');   end
  if ~ischar(delimiter), error('delimiter must be a string');   end
  
  str = cellfun(@(x)(x.(fieldname)), structs, 'UniformOutput', false);
  
  str = cellCons(str, delimiter);
  
end
