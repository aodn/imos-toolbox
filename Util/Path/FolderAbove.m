function [above] = FolderAbove(path, level)
% function [above] = FolderAbove(path,level)
%
% Return the full path of arbitrary backward levels
% (above) the path provided.
%
% Inputs:
%
% path - a path string.
% level - an integer to go above the folder level.
%
% Outputs:
%
% above - a string with the folder above `level`.
%
% Example:
% path = '/dev/shm/';
% level = 1;
% [above] = FolderAbove(path,level);
% assert(strcmp(above,'/dev/'));
%
% path = '/';
% levle = 10;

% [] = ()
% assert()
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

if nargin < 2
    level = 1;
end

if level < 0
    error('Folder level must be positive')
end

if ~strcmp(path(end), filesep)
    path_adj = [path filesep];
else
    path_adj = path;
end

if level == 0
    above = path_adj;
    return
end

splitted = split(path_adj, filesep);
nfolders = length(splitted);
nc = nfolders - level - 1;
onlinux = strcmp(filesep,'/') && strcmp(pathsep,':');

if onlinux
    above = [filesep fullfile(splitted{2:nc}) filesep];
else
    above = [fullfile(splitted{2:nc}) filesep];
end

end
