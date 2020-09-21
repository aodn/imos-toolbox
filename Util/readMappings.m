function [mappings] = readMappings(file, delimiter)
% function [mappings] = readMappings(file, delimiter)
%
% This read a mapping file, with a predefined delimiter (',').
%
% Inputs:
%
% file - a file location string
% delimiter - a field delimiter
%             default: ','
%
% Outputs:
%
% mappings - a containers.Map mapping
%
% Example:
%
% file =
% [mappings] = readMappings(file)
% assert()
%
% author: hugo.oliveira@utas.edu.au
%

% Copyright (C) 2020, Australian Ocean Data Network (AODN) and Integrated
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
%
% You should have received a copy of the GNU General Public License
% along with this program.
% If not, see <https://www.gnu.org/licenses/gpl-3.0.en.html>.
%
if nargin < 2
    delimiter = ',';
end

nf = fopen(file, 'r');
raw_read = textscan(nf, '%s', 'Delimiter', delimiter);
raw_read = raw_read{1};
mappings = containers.Map(raw_read(1:2:end), raw_read(2:2:end));
end
