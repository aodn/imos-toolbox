function value = readProperty(prop, file, delim)
%READPROPERTY Return the value of the specified property from the given file.
%
% This function provides a simple interface to retrieve the values of
% properties stored in a properties file.
%
% A 'property' file is a file which contains a list of name value pairs,
% separated by a delimiter. If the optional delim parameter is not provided, 
% it is assumed that the file uses '=' as the delimiter.
%
% Inputs:
%
%   prop  - Name of the property. If the name does not map to a property 
%           listed in the properties file, an error is raised.
%
%   file  - Optional. Name of the property file. Must be specified relative 
%           to the IMOS toolbox root. Defaults to 'toolboxProperties.txt'.
%
%   delim - Optional. Delimiter character/string. Defaults to '='.
%
% Outputs:
%   value - Value of the property. 
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

propFilePath = '';
if ~isdeployed, [propFilePath, ~, ~] = fileparts(which('imosToolbox.m')); end
if isempty(propFilePath), propFilePath = pwd; end
    
file = fullfile(propFilePath, file);

if ~exist(file, 'file'), error(['file ' file ' must be a file']);    end

% read in all the name=value pairs
fid = fopen(file, 'rt');
if fid == -1, error(['could not open ' file]); end

lines = textscan(fid, '%s%q', 'Delimiter', delim, 'CommentStyle', '%');

fclose(fid);

if isempty(lines), error([file ' is empty']); end

names = lines{1};
vals  = lines{2};

if strcmp(prop, '*')
    value = lines;
    return;
end

% find the requested property
for k = 1:length(names)
  
  name = strtrim(names{k});
  
  if ~strcmp(name, prop), continue; end
  
  value = strtrim(vals{k});
  return;
  
end

error([prop ' is not a property']);
