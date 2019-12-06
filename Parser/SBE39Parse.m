function sample_data = SBE39Parse( filename, mode )
%SBE39PARSE Parse a raw '.asc' file containing SBE39 data.
%
% This function can read in data that has been downloaded from an SBE39
% temperature/pressure sensor.
%
% The output format for the SBE39 is very similar to the SBE37, so this
% function simply delegates the parsing to the SBE3x function, which parses
% data from both instrument types.
%
% Inputs:
%   filename    - name of the input file to be parsed
%   mode        - Toolbox data type mode.
%
% Outputs:
%   sample_data - struct containing the sample data
%
% Author: Paul McCarthy <paul.mccarthy@csiro.au>
%
% See SBE3x.m
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
narginchk(1,2);

if ~iscellstr(filename)
    error('filename must be a cell array of strings');
end

% only one file supported currently
filename = filename{1};

sample_data = SBE3x(filename, mode);
