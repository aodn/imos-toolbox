function desc = genSampleDataDesc( sam, detailLevel )
%GENSAMPLEDATADESC Generates a string description of the given sample_data
% struct.
%
% This function exists so that a uniform sample data description format can
% be used throughout the toolbox.
% 
% Inputs:
%   sam          - struct containing a data set
%   detailLevel  - string either 'full', 'medium' or 'short', dictates the level of
%                details for output sample description
%
% Outputs:
%   desc - a string describing the given data set.
%
% Author: Paul McCarthy <paul.mccarthy@csiro.au>
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

if ~isstruct(sam), error('sam must be a struct'); end

if nargin == 1
    detailLevel = 'full';
end

timeFmt = readProperty('toolbox.timeFormat');

timeRange = ['from ' datestr(sam.time_coverage_start, timeFmt) ' to ' ...
             datestr(sam.time_coverage_end,   timeFmt)];

[~, fName, fSuffix] = fileparts(sam.toolbox_input_file);

fName = [fName fSuffix];

switch detailLevel
    case 'short'
        desc = [   sam.meta.instrument_make ...
            ' '    sam.meta.instrument_model ...
            ' @'   num2str(sam.meta.depth) 'm'];
        
    case 'medium'
        desc = [   sam.meta.instrument_make ...
            ' '    sam.meta.instrument_model ...
            ' SN=' sam.meta.instrument_serial_no ...
            ' @'   num2str(sam.meta.depth) 'm' ...
            ' ('   fName ')'];
        
    otherwise
        % full details
        desc = [   sam.meta.site_id ...
            ' - '  sam.meta.instrument_make ...
            ' '    sam.meta.instrument_model ...
            ' SN=' sam.meta.instrument_serial_no ...
            ' @'   num2str(sam.meta.depth) 'm' ...
            ' '    timeRange ...
            ' ('   fName ')'];
end