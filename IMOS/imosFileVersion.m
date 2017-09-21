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
