function [names values] = listProperties(file, delim)
%LISTPROPERTIES Returns a cell array containing all key value pairs in the
%given file.
%
% This function reads the given property file, and returns all of the key 
% value pairs contained within.
%
% A 'property' file is a file which contains a list of name value pairs,
% separated by a delimiter. If the optional delim parameter is not provided, 
% it is assumed that the file uses '=' as the delimiter.
%
% Inputs:
%
%   file   - Optional. Name of the property file. Must be specified relative 
%            to the IMOS toolbox root. Defaults to 'toolboxProperties.txt'.
%
%   delim  - Optional. Delimiter character/string. Defaults to '='.
%
% Outputs:
%   names  - Cell array containing property names contained in the file.
%   values - Cell array containing property values contained in the file.
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
narginchk(0,2);

if ~exist('delim', 'var'), delim = '=';                     end
if ~exist('file',  'var'), file  = 'toolboxProperties.txt'; end

if ~ischar(delim),       error('delim must be a string'); end
if ~exist(file, 'file'), error('file must be a file');    end

propFilePath = '';
if ~isdeployed, [propFilePath, ~, ~] = fileparts(which('imosToolbox.m')); end
if isempty(propFilePath), propFilePath = pwd; end

% read in all the name=value pairs
fid = fopen([propFilePath filesep file], 'rt');
if fid == -1, error(['could not open ' file]); end

props = textscan(fid, '%s%s', 'Delimiter', delim, 'CommentStyle', '%');

fclose(fid);

names  = props{1};
values = props{2};

names  = cellfun(@strtrim, names,  'UniformOutput', false);
values = cellfun(@strtrim, values, 'UniformOutput', false);
