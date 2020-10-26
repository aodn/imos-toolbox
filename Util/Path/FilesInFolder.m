function [files, folders] = FilesInFolder(path)
% function files = FilesInFolder(path)
%
% Return two cells with fullpath of files/folders within
% a path.
% The cells are sorted.
%
% Inputs:
%
% path - a path string
%
% Outputs:
%
% files - a cell with fullpath strings of the files.
% folders - a cell with fullpath strings of the subfolders.
%
% Example:
%
% [files] = FilesInFolder(toolboxRootPath);
% assert(any(contains(files,'imosToolbox.m')));
% assert(any(contains(files,'license.txt')));
% assert(any(contains(files,'toolboxProperties.txt')));
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

dobj = dir(path);
files = cell(0, 0);
folders = cell(0, 0);
c = 0;
p = 0;

for k = 1:length(dobj)
    isfolder = dobj(k).isdir;
    name = dobj(k).name;

    if ~isfolder
        fullpath = fullfile(path, name);
        c = c + 1;
        files{c} = fullpath;
    else
        not_dots = ~strcmp(name, '.') &&~strcmp(name, '..');

        if not_dots
            p = p + 1;
            folders{p} = fullfile(path,name);
        end

    end

end

end
