function [name] = basename(path)
% function [name] = basename(path)
%
% Return the basename from a file/folder
% path string.
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
%
% % basename of a file with extension
% assert(strcmp(basename('/tmp/abc.nc'),'abc.nc'))
% % basename of a file without extension
% assert(strcmp(basename('/a/b/c/d'),'d'))
% % basename of a folder is itself
% assert(strcmp(basename('/tmp/'),'/tmp')) % strip away
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

[fpath, fname, fext] = fileparts(path);

no_extension = isempty(fext);
isfolder = no_extension && isempty(fname);

if isfolder
    name = fpath;
else

    if no_extension
        name = fname;
    else
        name = [fname fext];
    end

end

end
