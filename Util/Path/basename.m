function [name] = basename(path)
% function [name] = basename(path)
%
% Return the basename given a full file path
% 
% The function ignore strings ending in '/'
%
% Inputs:
%
% path - a string representing a fullpath
%
% Outputs:
%
% name - a string representing the basename
%
% Examples:
% % simple case
% assert(strcmp(basename('/tmp/abc.nc'),'abc.nc'))
% assert(strcmp(basename('/a/b/c/d'),'d'))
% % folder case
% assert(strcmp(basename('/tmp/'),'/tmp/')) % ignored
%
% Author: hugo.oliveira@utas.edu.au
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

s = split(path, '/');
ns = length(s);

if isempty(s{ns})
    name = path;
    return
end

for k = ns:-1:1
    if isempty(s{k})
        continue
    else
        name = s{k};
        return
    end
end

error('Invalid Path %s', path)
end
