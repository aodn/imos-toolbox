function writeToolboxProperty( prop, val )
%WRITETOOLBOXPROPERTY Updates the value of a toolbox property.
%
% Updates the value of a toolbox property, which is stored in a file called
% toolboxProperties.txt. If the property does not already exist in the
% file, it is added to the end. If the property appears more than once in
% the file, all occurrences are updated. This function does not support
% instances where the existing property value is the property name (e.g.
% 'prop_name = prop_name').
%
% Inputs:
%   prop - name of the property to update
%
%   val  - new value to give the property. Must be a string; if the
%          property value is of a different type, convert it to a 
%          string when passing to this function.
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
if ~ischar(val),  error('val must be a string');  end

propFilePath = fileparts(which(mfilename));

oldFile = [propFilePath filesep  'toolboxProperties.txt'];
newFile = [propFilePath filesep '.toolboxProperties.txt'];

% open old file for reading
fid  = fopen(oldFile, 'r');
if fid == -1,  error(['could not open ' oldFile ' for reading']); end

% open handle to new replacement file
nfid = fopen(newFile, 'w');
if nfid == -1, 
  flose(fid);
  error(['could not open ' newFile ' for writing']); 
end

% iterate through every line of the file
line = fgets(fid);
updated = 0;
while line ~= -1
  
  tkns = regexp(line, '^\s*(.*\S)\s*=\s*(.*\S)?\s*$', 'tokens');
  
  % if this is the relevant line, replace the 
  % old property value with the new value
  if ~isempty(tkns) ...
  &&  strcmp(tkns{1}{1},prop)
    line = strrep(line, tkns{1}{2}, val);
    updated = 1;
  end
  
  % write out to the replacement file
  fprintf(nfid,'%s',line);
  line = fgets(fid);
  
end

% if a new property, add it to the end
if ~updated, fprintf(nfid, '\n%s = %s', prop, val); end

fclose(fid);
fclose(nfid);

% overwrite the old file with the new file
if ~movefile(newFile, oldFile, 'f')
  error(['could not replace ' oldFile ' with ' newFile]);
end
