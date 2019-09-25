function sample_data = XRParse( filename, mode )
%XRPARSE Parses a data file retrieved from an RBR XR420 or XR620 depth 
% logger.
%
% This function is able to read in a single file retrieved from an RBR
% XR420 or XR620 data logger generated using RBR Windows v 6.13 software 
% or Ruskin software. The pressure data is returned in a sample_data
% struct.
%
% Inputs:
%   filename    - Cell array containing the name of the file to parse.
%   mode        - Toolbox data type mode.
%
% Outputs:
%   sample_data - Struct containing imported sample data.
%
% Author : Guillaume Galibert <guillaume.galibert@utas.edu.au>
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

% ensure that there is exactly one argument, 
% and that it is a cell array of strings
narginchk(1,2);

if ~iscellstr(filename), error('filename must be a cell array of strings'); end

% only one file supported currently
filename = filename{1};
if ~ischar(filename), error('filename must contain a string'); end

[~, ~, ext] = fileparts(filename);

% read first line in the file
line = '';
try
    fid = fopen(filename, 'rt');
    line = fgetl(fid);
    fclose(fid);
    
catch e
    if fid ~= -1, fclose(fid); end
    rethrow(e);
end

if strcmpi(ext, '.dat') && strcmp(line(1:3), 'RBR')
    % use the classic XR420 parser for RBR Windows v 6.13 file format
    sample_data = readXR420(filename, mode);
else
    % use the new XR620 and XR420 parser for Ruskin file format
    sample_data = readXR620(filename, mode);
end