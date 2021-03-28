function [files, folders] = FilesInFolder(path, exclude_extensions)
% function files = FilesInFolder(path, exclude_extensions)
%
% Return two cells with fullpath of files/folders within
% a path.
% The cells are sorted.
%
% Inputs:
%
% path [str] - a path string
% exclude_extensions [cell{str}] - Optional: a cell with file
%                                  extensions to exclude.
% 
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
% % exclude txt files.
% [files] = FilesInFolder(toolboxRootPath,{'.txt'});
% assert(~any(contains(files,'license.txt')))
%
%
% author: hugo.oliveira@utas.edu.au
%
narginchk(1,2)
if nargin==1
    exclude_extensions = {};
else
    if ~iscellstr(exclude_extensions)
        errormsg('Second argument is not a cell of strings')
    end
end

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
        skip = false;
        for j=1:length(exclude_extensions)
            if endsWith(fullpath,exclude_extensions{j})
                skip = true;
                break
            end
        end
        if ~skip
            c = c + 1;
            files{c} = fullpath;
        end
    else
        not_dots = ~strcmp(name, '.') &&~strcmp(name, '..');

        if not_dots
            p = p + 1;
            folders{p} = fullfile(path,name);
        end

    end

end

end
