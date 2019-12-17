function [dicts] = readHeaderDict(cell_line_str, func, varargin)
% function [dicts] = readHeaderDict(cell_line_str, func, varargin)
%
% Load the Header dictionary
%
% Inputs:
%
% cell_line_str - a cell with the header lines
% func - the function to read each line string
% varargin - the arguments to the func
%
% Outputs:
%
% dicts - a cell of structs containing the output
%         of the func(line,varargin) applied
%         to every line of the header.
%
% Example:
% cell_line_str = {'field: Velocity','units: m/s'};
% func = @regexpi;
% args = {'^(?<key>(.+?(?=:))):\s(?<value>(.+?))$','names'};
% [dicts] = readHeaderDict(cell_line_str,func,args);
% assert(isequal(dicts{1},struct('key','field','value','Velocity')));
% assert(isequal(dicts{2},struct('key','units','value','m/s')));
%
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

narginchk(2, inf)

if nargin > 2
    func_extra_arg = varargin{:};
end

if ~iscell(cell_line_str)
    error('argument 1 is not a cell');
elseif ~isa(func, 'function_handle')
    error('second argument is not a function_handle')
elseif ~iscell(func_extra_arg)
    error('invalid functional arguments: not a cell')
end

dicts = cell(1, 1);
lc = length(cell_line_str);

for k = 1:lc
    dicts{k} = func(cell_line_str{k}, func_extra_arg{:});
end

end
