function delProperty( prop, file, delim )
%DELPROPERTY Deletes the given property from the given file.
%
% Searches the given file for a property with the given name; if the
% property is found, it is removed from the file. If multiple properties
% have the same name, they are all removed.
%
% A 'property' file is a file which contains a list of name value pairs,
% separated by a delimiter. If the optional delim parameter is not provided, 
% it is assumed that the file uses '=' as the delimiter.
%
% Inputs:
%
%   prop  - name of the property to delete
%
%   file  - Optional. Name of the property file. Must be specified relative 
%           to the IMOS toolbox root. Defaults to 'toolboxProperties.txt'.
%
%   delim - Optional. Delimiter character/string. Defaults to '='.
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
narginchk(1,3);

if ~exist('delim', 'var'), delim = '=';                     end
if ~exist('file',  'var'), file  = 'toolboxProperties.txt'; end

if ~ischar(file),        error('file must be a string');  end
if ~ischar(prop),        error('prop must be a string');  end
if ~ischar(delim),       error('delim must be a string'); end
if ~exist(file, 'file'), error('file must be a file');    end

propFilePath = '';
if ~isdeployed, [propFilePath, ~, ~] = fileparts(which('imosToolbox.m')); end
if isempty(propFilePath), propFilePath = pwd; end

[filePath fileName fileExt] = fileparts(file);

oldFile = [propFilePath filesep file];
newFile = [propFilePath filesep filePath filesep '.' fileName '.' fileExt];

% open old file for reading
fid  = fopen(oldFile, 'rt');
if fid == -1,  error(['could not open ' oldFile ' for reading']); end

% open handle to new replacement file
nfid = fopen(newFile, 'wt');
if nfid == -1, 
  fclose(fid);
  error(['could not open ' newFile ' for writing']); 
end

% iterate through every line of the file
line = fgets(fid);
while ischar(line)
  
  tkns = regexp(line, ['^\s*(.*\S)\s*' delim '\s*(.*\S)?\s*$'], 'tokens');
  
  % unless this is the relevant line, write 
  % the line out to the replacement file
  if isempty(tkns) || ~strcmp(tkns{1}{1},prop)
    fprintf(nfid,'%s',line); 
  end
  
  line = fgets(fid);
end

fclose(fid);
fclose(nfid);

% overwrite the old file with the new file
if ~movefile(newFile, oldFile, 'f')
  error(['could not replace ' oldFile ' with ' newFile]);
end
