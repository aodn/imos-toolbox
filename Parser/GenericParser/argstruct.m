function [astruct] = argstruct(cell_of_args, fun)
% function astruct = argstruct(cell_of_args,fun)
%
% A wrapper that creates a structure with
% a cell of strings and a function handle.
%
% Inputs:
%
% cell_of_args - a cell of strings
% afunc - an anonymous function/function handle
%
% Outputs:
%
% astruct - a argument structure.
% astruct.args - a cell with string argument names
% astruct.fun - anonymous function that use astruct.args
%
% Example:
% cell_of_args = {1,2,3};
% afunc = @(x,y,z) (x+y+z);
% [astruct] = argstruct(cell_of_args,afunc);
% assert(isequal(astruct.args,cell_of_args))
% assert(isfunctionhandle(astruct.fun))
% assert(astruct.fun(astruct.args{:})==6)
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
astruct.args = cell_of_args;
astruct.fun = fun;
end
