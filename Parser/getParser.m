function handle = getParser( name )
%GETPARSER - returns a function handle to the parser for the instrument
% with the given name.
% 
% Creates a function handle to the parser function for the instrument with 
% the given name. If a parser does not exist, the handle is still created,
% but calls to the function will fail.
%
% Inputs:
%   name   - name of the instrument.
%
% Outputs:
%   handle - a function handle to the parser for the given instrument.
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

%convert the instrument name to the parser function 
%name, then create a handle to the function
name = [name 'Parse'];
handle = str2func(name);
