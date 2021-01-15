function setToolboxPaths(toolbox_path)
% function setToolboxPaths(toolbox_path)
%
% Add all the folders of the toolbox to the search
% path.
%
% Inputs:
%
% toolbox_path - the root path of the IMOS toolbox
%
% Outputs:
%
% Example:
%
% setToolboxPaths(toolboxRootPath)
% assert(exist('detectType.m','file')==2)
%
% author: hugo.oliveira@utas.edu.au
%

% Copyright (C) 2020, Australian Ocean Data Network (AODN) and Integrated
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

% Toolbox root level folders and subfolders that contains matlab functions
folders = { ...
    'AutomaticQC', ...
    frdir(fullfile(toolbox_path, 'AutomaticQC')), ...
    'DDB', ...
    'FlowManager', ...
    'Geomag', ...
    'Graph', ...
    'GUI', ...
    'IMOS', ...
    'Java', ...
    'Java/UCanAccess-3.0.2-bin', ...
    'Java/UCanAccess-3.0.2-bin/lib', ...
    frdir(fullfile(toolbox_path, 'Java/bin')), ...
    'NetCDF', ...
    frdir(fullfile(toolbox_path, 'NetCDF')), ...
    'Parser', ...
    frdir(fullfile(toolbox_path, 'Parser')), ...
    'Preprocessing', ...
    frdir(fullfile(toolbox_path, 'Preprocessing')), ...
    'Seawater/TEOS10', ...
    'Seawater/TEOS10/library', ...
    'Seawater/EOS80', ...
    'test', ...
    frdir(fullfile(toolbox_path, 'test')), ...
    'Util', ...
    frdir(fullfile(toolbox_path, 'Util')), ...
    };

addpath(toolbox_path)

for k = 1:length(folders)

    if isstring(folders{k}) || ischar(folders{k})
        addpath(fullfile(toolbox_path, folders{k}));
    elseif iscell(folders{k})
        rfolders = folders{k};
        for kk = 1:length(rfolders)
            [path,folder_name,~] = fileparts(rfolders{kk});
            if ~strcmp(folder_name(1),'+')
                addpath(rfolders{kk});
            end
        end

    end

end

end

%functions required to be in this scope since we
%may need to call setToolboxPaths from anywhere.

function [folders] = subFolders(path)
% function files = Folders(path)
%
% Return fullpath of sub-folders.
%
% Inputs:
%
% path - a path string
%
% Outputs:
%
% folders - a cell with fullpath strings of the subfolders.
%
% Example:
% % assumes /dev/shm got 2 folders, "a","b"
% path = '/dev/shm';
% [subfolders] = subFolders(path);
% assert(any(contains(sf,'a')));
% assert(any(contains(sf,'b')));
%
% author: hugo.oliveira@utas.edu.au
%

dobj = dir(path);
folders = cell(0, 0);
p = 1;

for k = 1:length(dobj)
    name = dobj(k).name;
    isfolder = dobj(k).isdir;

    if isfolder &&~strcmp(name, '.') &&~strcmp(name, '..')
        folders{p} = fullfile(path, name);
        p = p + 1;
    end

end

end

function [folders] = frdir(path)
% function folders = frdir(path)
%
% recursive dir - List all children folders given a path
%
% Inputs:
%
% path - a path string
%
% Outputs:
%
% `folders` - a cell with fullpath strings of all subfolders at all levels.
%
% Example:
% % assumes /dev/shm/c/d/e/f/g/h/j is a empty folder
% path = '/dev/shm'
% [allfiles,allfolders] = frdir(path);
% assert(strcmp(allfolders{1},'/dev/shm/c'));
% assert(strcmp(allfolders{2},'/dev/shm/c/d'));
% assert(strcmp(allfolders{end},'/dev/shm/c/d/e/f/g/h/j'));
%
% author: hugo.oliveira@utas.edu.au
%

[folders] = subFolders(path);

if isempty(folders)
    return
end

folders_to_walk = string(folders);

while ~isempty(folders_to_walk)
    f = folders_to_walk{1};
    folders_to_walk(1) = [];
    [newfolders] = frdir(f);

    if ~isempty(newfolders)
        folders = cat(2, folders, newfolders);
    end

end

end
