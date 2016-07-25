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
% Copyright (c) 2016, Australian Ocean Data Network (AODN) and Integrated 
% Marine Observing System (IMOS).
% All rights reserved.
% 
% Redistribution and use in source and binary forms, with or without 
% modification, are permitted provided that the following conditions are met:
% 
%     * Redistributions of source code must retain the above copyright notice, 
%       this list of conditions and the following disclaimer.
%     * Redistributions in binary form must reproduce the above copyright 
%       notice, this list of conditions and the following disclaimer in the 
%       documentation and/or other materials provided with the distribution.
%     * Neither the name of the AODN/IMOS nor the names of its contributors 
%       may be used to endorse or promote products derived from this software 
%       without specific prior written permission.
% 
% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
% AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
% IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
% ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE 
% LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
% CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
% SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
% INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
% CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
% ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
% POSSIBILITY OF SUCH DAMAGE.
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
