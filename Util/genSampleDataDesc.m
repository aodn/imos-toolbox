function desc = genSampleDataDesc(sam, detailLevel)
%function desc = genSampleDataDesc(sam, detailLevel)
%
% Generates a string description of the given sample_data
% struct.
%
% This function exists so that a uniform sample data description
% format can be used throughout the toolbox.
%
% Inputs:
%   sam          - struct containing a data set
%   detailLevel  - string either 'full', 'medium' or 'short', dictates
%                  the level of details for output sample description
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
%along with this program.
% If not, see <https://www.gnu.org/licenses/gpl-3.0.en.html>.
%
narginchk(1,2);

if ~isstruct(sam), error('sam must be a struct'); end

user_detailLevel = '';
try
    user_detailLevel = readProperty('toolbox.detailLevel');
catch
end

simple_call_no_user_config = isempty(user_detailLevel) && nargin < 2;
simple_call_with_user_config = ~isempty(user_detailLevel) && nargin < 2;
full_call_with_user_config = ~isempty(user_detailLevel) && nargin > 1;

if simple_call_no_user_config
    detailLevel = 'full';
elseif simple_call_with_user_config
    detailLevel = user_detailLevel;
elseif full_call_with_user_config
    %disambiguation towards shorter detailed levels
    scores = containers.Map({'name-only','short','medium','full','id'},{1,2,3,4,5});
    try
        user_score = scores(user_detailLevel);
        call_score = scores(detailLevel);
        [found,ind] = inCell(scores.values,max(user_score,call_score));
        if found
            names = scores.keys;
            detailLevel = names{ind};
        end
    catch
    end
end

timeFmt = readProperty('toolbox.timeFormat');

timeRange = ['from ' datestr(sam.time_coverage_start, timeFmt) ' to ' ...
             datestr(sam.time_coverage_end,   timeFmt)];

[~, fName, fSuffix] = fileparts(sam.toolbox_input_file);

fName = [fName fSuffix];


alias_file = '';
try
    alias_file = readProperty('toolbox.instrumentAliases');
catch
end

instrument_entry = [sam.meta.instrument_make ' ' sam.meta.instrument_model];
if ~isempty(alias_file)
    try
        map = readMappings(alias_file);
        instrument_entry = map(instrument_entry);
    catch
    end
end

switch detailLevel

    case 'name-only'
        desc = [ instrument_entry ];

    case 'short'
        desc = [ instrument_entry ' @' num2str(sam.meta.depth) 'm'];

    case 'medium'
        desc = [   instrument_entry ...
            ' SN=' sam.meta.instrument_serial_no ...
            ' @'   num2str(sam.meta.depth) 'm' ...
            ' ('   fName ')'];

    case 'id'
        desc = [ '(' fName ')' ' SN=' sam.meta.instrument_serial_no ' @' num2str(sam.meta.depth) 'm'];

    otherwise
        % full details
        desc = [   sam.meta.site_id ...
            ' - '  instrument_entry ...
            ' SN=' sam.meta.instrument_serial_no ...
            ' @'   num2str(sam.meta.depth) 'm' ...
            ' '    timeRange ...
            ' ('   fName ')'];
end

end
