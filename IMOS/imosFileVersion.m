function value = imosFileVersion(index, field)
%IMOSFILEVERSION Returns the name, file ID or description of file version 
% with the given index, or return the index with the given name.
%
% IMOS file versions are defined in the imosFileVersion.txt file. This
% function returns the name, description or file ID of the file version
% with the given index, or the index of the file_version given its name
% The given field parameter must be one of 'index, 'fileid', 'name' or 
% 'desc'.
%
% Inputs:
%   index - Index or name of the required file version. 
%   field - Either 'index', 'fileid', 'name' or 'desc'.
%
% Outputs:
%   value - the requested field of the given file version, either the index, 
%           file ID, the name, or the description.
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

narginchk(2, 2);
if isnumeric(index), index = num2str(index); end
if ~ischar(field),    error('field must be a string'); end

index = num2str(index);

value = '';

% get the location of this m-file, which is 
% also the location of imosFileVersion.txt
path = '';
if ~isdeployed, [path, ~, ~] = fileparts(which('imosToolbox.m')); end
if isempty(path), path = pwd; end
path = fullfile(path, 'IMOS');

fid = -1;
params = [];
try
  fid = fopen([path filesep 'imosFileVersion.txt'], 'rt');
  if fid == -1, return; end
  
  params = textscan(fid, '%s%s%s%[^\n]', 'delimiter', ',', 'commentStyle', '%');
  fclose(fid);
catch e
  if fid ~= -1, fclose(fid); end
  rethrow(e);
end

indices = params{1};
fileids = params{2};
names   = params{3};
descs   = params{4};

% search the list for an index match
for k = 1:length(names)
    switch field
        case 'index'
            if strcmp(index, names{k})
                value = str2double(indices{k});
                break;
            end
        otherwise
            if strcmp(index, indices{k})
                switch field
                    case 'fileid', value = fileids{k};
                    case 'name',   value = names{k};
                    case 'desc',   value = descs{k};
                end
                break;
            end
    end
end
