function [files] = FilesInFolder(path)
% function files = FilesInFolder(path)
%
% Return a cell with fullpath of files within path.
% The cell is sorted based on fullpath.
%
% Inputs:
%
% `path` - a path string
%
% Outputs:
%
% `files` - a cell with fullpath strings of the files.
%
% Example:
% % assumes /dev/shm got 4 files, "_a","1b","1_ab","abc.m".
% path = '/dev/shm';
% [files] = FilesInFolder(path);
% assert(any(contains(files,'1_ab')));
% assert(any(contains(files,'1b')));
% assert(any(contains(files,'_a')));
% assert(any(contains(files,'abc.m')));
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
files = cell(1, 1);
c = 0;

for k = 1:length(dobj)
    name = dobj(k).('name');

    if ~isfolder(name)
        fullpath = fullfile(path, dobj(k).('name'));
        issubfolder = isfolder(fullpath);

        if ~issubfolder
            c = c + 1;
            files{c} = fullpath;
        end

    end

end

end
