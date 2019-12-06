function var = getVar(vars, name)
%GETVAR Finds and returns the index of the variable with the given name from 
% the given cell array of variables. If the array does not contain a variable 
% of the given name, 0 is returned.
%
% This function is simply a for loop - it saves having to repeat the same
% code elsewhere.
%
% Inputs:
%   vars - Cell array of variable structs.
%   name - Name of the variable in question.
%
% Outputs:
%   var  - Index into the vars array, specifying the variable with the
%          given name, or 0 if the variable wasn't found.
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
narginchk(2, 2);

if ~iscell(vars), error('vars must be a cell array'); end
if ~ischar(name), error('name must be a string');     end

var = 0;

for k = 1:length(vars)

  if strcmp(vars{k}.name, name), var = k; return; end
end
