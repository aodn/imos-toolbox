function value = readToolboxProperty(prop)
%READTOOLBOXPROPERTY Return the value of the specified global toolbox 
% property.
%
% The file toolboxProperties.txt contains 'global' toolbox configuration 
% properties. This file provides a simple interface to retrieve the values of
% these properties.
%
% Inputs:
%   prop  - Name of the property. If the name does not map to a property listed
%           in the properties file, an error is raised.
%
% Outputs:
%   value - Value of the property. 
%
% Author: Paul McCarthy <paul.mccarthy@csiro.au>
%

%
% Copyright (c) 2009, eMarine Information Infrastructure (eMII) and Integrated 
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
%     * Neither the name of the eMII/IMOS nor the names of its contributors 
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

if ~ischar(prop), error('prop must be a string'); end

propFilePath = pwd;

% read in all the name=value pairs
fid = fopen([propFilePath filesep 'toolboxProperties.txt'], 'rt');
if fid == -1, error('could not open toolboxProperties.txt'); end

lines = textscan(fid, '%s%s', 'Delimiter', '=', 'CommentStyle', '%');

fclose(fid);

if isempty(lines), error('toolboxProperties.txt is empty'); end

names = lines{1};
vals  = lines{2};

% find the requested property
for k = 1:length(names)
  
  name = strtrim(names{k});
  
  if ~strcmp(name, prop), continue; end
  
  value = vals{k};
  return;
  
end

error([prop ' is not a toolbox property']);
