function writeProperty( prop, val, file, delim )
%WRITEPROPERTY Updates the value of a property in the given file.
%
% Updates the value of a property, which is stored in the given file. If the 
% property does not already exist in the file, it is added to the end. If the 
% property appears more than once in the file, all occurrences are updated. 
% This function does not support instances where the existing property value 
% is the property name (e.g. 'prop_name = prop_name').
%
% A 'property' file is a file which contains a list of name value pairs,
% separated by a delimiter. If the optional delim parameter is not provided, 
% it is assumed that the file uses '=' as the delimiter.
%
% Inputs:
%
%   prop  - name of the property to update
%
%   val   - new value to give the property. Must be a string; if the
%           property value is of a different type, convert it to a 
%           string when passing to this function.
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
narginchk(2,4);

if ~exist('delim', 'var'), delim = '=';                     end
if ~exist('file',  'var'), file  = 'toolboxProperties.txt'; end

if ~ischar(file),        error('file must be a string');  end
if ~ischar(prop),        error('prop must be a string');  end
if ~ischar(val),         error('val must be a string');   end
if ~ischar(delim),       error('delim must be a string'); end
if ~exist(file, 'file'), error('file must be a file');    end

propFilePath = '';
if ~isdeployed, [propFilePath, ~, ~] = fileparts(which('imosToolbox.m')); end
if isempty(propFilePath), propFilePath = pwd; end

[filePath fileName fileExt] = fileparts(file);

oldFile = fullfile(propFilePath, file);
newFile = fullfile(propFilePath, filePath, ['.' fileName fileExt]);

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
updated = 0;
while ischar(line)
  
  tkns = regexp(line, ['^\s*(.*\S)\s*' delim '\s*(.*\S)?\s*$'], 'tokens');
  
  % if this is the relevant line, replace the 
  % old property value with the new value
  if ~isempty(tkns) ...
  &&  strcmp(tkns{1}{1},prop)
    if isempty(tkns{1}{2})
      line = sprintf('%s %s %s\n', tkns{1}{1}, delim, val);
    else
      line = strrep(line, tkns{1}{2}, val);
    end 
    updated = 1;
  end
  
  % write out to the replacement file
  fprintf(nfid,'%s',line);
  line = fgets(fid);
  
end

% if a new property, add it to the end
if ~updated, fprintf(nfid, '\n%s %s %s', prop, delim, val); end

fclose(fid);
fclose(nfid);

% overwrite the old file with the new file
if ~movefile(newFile, oldFile, 'f')
  error(['could not replace ' oldFile ' with ' newFile]);
end
