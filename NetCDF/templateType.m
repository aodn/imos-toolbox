function t = templateType( name, temp, mode )
%TEMPLATETYPE Returns the type of the given NetCDF attribute, as specified
% in the associated template file.
%
% In the NetCDF attribute template files, attributes can have one of the
% following types.
%
%   S - String
%   N - Numeric
%   D - Date
%   Q - Quality control (either byte or char, depending on the QC set in use)
%
% Inputs:
%   name - the attribute name
%   temp - what kind of attribute - 'global', 'time', 'depth', 'latitude', 
%          'longitude', 'variable', 'qc' or 'qc_coord'
%   mode - Toolbox data type mode ('profile' or 'timeSeries').
%
% Outputs:
%   t    - the type of the attribute, one of 'S', 'N', 'D', or 'Q', or
%          empty if there was no such attribute.
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
error(nargchk(2,3,nargin));

if ~ischar(name), error('name must be a string'); end
if ~ischar(temp), error('temp must be a string'); end

% matlab no-leading-underscore kludge
if name(end) == '_', name = ['_', name(1:end-1)]; end

t = '';

if strcmpi(temp, 'global')
    if strcmpi(mode, 'profile')
        temp = [temp '_attributes_profile.txt'];
    else
        temp = [temp '_attributes_timeSeries.txt'];
    end
else
    temp = [temp '_attributes.txt'];
end

filepath = readProperty('toolbox.templateDir');
if isempty(filepath) || ~exist(filepath, 'dir')
  filepath = fullfile(pwd, 'NetCDF', 'template');
end

filepath = fullfile(filepath, temp);

lines = {};

% read all the lines in
fid = -1;
try
  fid = fopen(filepath, 'rt');
  
  if fid == -1, error(['could not open file ' filepath]); end
  
  line = fgetl(fid);
  
  while ischar(line)
    
    lines{end+1} = line;
    line         = fgetl(fid);
  end
  fclose(fid);
catch e
  if fid ~= -1, fclose(fid); end
  rethrow(e);
end

% pull out the type, attribute name and value
tkns = regexp(lines, '^\s*(.*\S)\s*,\s*(.*\S)\s*=\s*(.*\S)?\s*$', 'tokens');

for k = 1:length(tkns)
  
  % will be empty on lines that didn't match the regex
  if isempty(tkns{k}), continue; end
  
  type  = tkns{k}{1}{1};
  att   = tkns{k}{1}{2};
  
  if ~strcmp(name, att), continue; end
  
  % found a match, return the type
  t = type;
  return;
end
