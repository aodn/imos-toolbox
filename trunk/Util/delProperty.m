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
error(nargchk(1,3,nargin));

if ~exist('delim', 'var'), delim = '=';                     end
if ~exist('file',  'var'), file  = 'toolboxProperties.txt'; end

if ~ischar(file),        error('file must be a string');  end
if ~ischar(prop),        error('prop must be a string');  end
if ~ischar(delim),       error('delim must be a string'); end
if ~exist(file, 'file'), error('file must be a file');    end

propFilePath = pwd;

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
