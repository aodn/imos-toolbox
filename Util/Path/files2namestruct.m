function [named_struct] = files2namestruct(carg)
% function named_struct = files2namestruct(carg)
%
% Return a named structure from a cell argument with strings.
%
% Inputs:
%
% carg - a cell with strings.
%
% Outputs:
%
% named_struct = a structure with key as valid variable names
%                and values as the carg{n} values.
%
% Example:
% carg = {'/dev/shm/_a','/dev/shm/1b','/dev/shm/1_ab','/dev/shm/abc.m'};
% [named_struct] = files2namestruct(carg);
% assert(strcmpi(named_struct.x_a,'/dev/shm/_a'));
% assert(strcmpi(named_struct.x1b,'/dev/shm/1b'));
% assert(strcmpi(named_struct.x1_ab,'/dev/shm/1_ab'));
% assert(strcmpi(named_struct.abc_m,'/dev/shm/abc.m'));
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

clen = numel(carg);

for k = 1:clen
    [~, filename, ext] = fileparts(carg{k});
    valid_filename = ~strcmpi(filename, '');

    if valid_filename
        pname = [filename ext];
        named_struct.(matlab.lang.makeValidName(pname)) = carg{k};
    end

end

end
