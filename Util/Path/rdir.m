function [files, folders] = rdir(path)
% function files,folders = rdir(path)
%
% Recursively list all files/folders in 
% a given a path.
%
% Inputs:
%
% path [str] - a folder path
%
% Outputs:
%
% files [cell] - file path strings at all root/sub folder levels.
% folders [cell] - folder path strings at all sub-folder levels.
%
% Example:
%
% %simple test with nest folders
% [allfiles,allfolders] = rdir([toolboxRootPath 'Java']);
% assert(sum(contains(allfolders,'Java/bin'))==4)
% assert(sum(contains(allfiles,'ddb.jar'))==1)
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

[files, folders] = FilesInFolder(path);

if isempty(folders)
    return
end

folders_to_walk = string(folders);

while ~isempty(folders_to_walk)
    f = folders_to_walk{1};
    folders_to_walk(1) = [];
    [newfiles, newfolders] = rdir(f);

    if ~isempty(newfiles)
        files = cat(2, files, newfiles);
    end

    if ~isempty(newfolders)
        folders = cat(2, folders, newfolders);
    end

end

end
