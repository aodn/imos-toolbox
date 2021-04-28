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

try
    time_coverage_start = sam.time_coverage_start;
    if isempty(time_coverage_start)
        time_coverage_start = 0;
    end
catch
    time_coverage_start = 0;
end

try 
    time_coverage_end = sam.time_coverage_end;
    if isempty(time_coverage_end)
        time_coverage_end = 0;
    end
catch
    time_coverage_end = 0;
end

timeRange = ['from ' datestr(time_coverage_start, timeFmt) ' to ' ...
    datestr(time_coverage_end,   timeFmt)];

try
    filename = sam.toolbox_input_file;
catch
    filename = 'Unknown';
end

[~, fName, fSuffix] = fileparts(filename);

fName = [fName fSuffix];


try
    alias_file = readProperty('toolbox.instrumentAliases');
catch
    alias_file = '';
end

try
    maker = sam.meta.instrument_make;
catch
    maker = 'None';
end
try
    model = sam.meta.instrument_model;
catch
    model = 'None';
end

instrument_entry = [maker ' ' model ];

if ~isempty(alias_file)
    try
        map = readMappings(alias_file);
        instrument_entry = map(instrument_entry);
    catch
    end
end

try
    depth = sam.meta.depth;
catch
    depth = NaN;
end

try
    instrument_serial_no = sam.meta.instrument_serial_no;
catch
    instrument_serial_no = 'Unknown';
end

try
    site_id = sam.meta.site_id;
catch
    site_id = 'Unknown';
end

switch detailLevel

    case 'name-only'
        desc = instrument_entry ;

    case 'short'
        desc = [ instrument_entry ' @' num2str(depth) 'm'];

    case 'medium'
        desc = [   instrument_entry ...
            ' SN=' instrument_serial_no ...
            ' @'   num2str(depth) 'm' ...
            ' ('   fName ')'];

    case 'id'
        desc = [ '(' fName ')' ' SN=' instrument_serial_no ' @' num2str(depth) 'm'];

    otherwise
        % full details
        desc = [   site_id ...
            ' - '  instrument_entry ...
            ' SN=' instrument_serial_no ...
            ' @'   num2str(depth) 'm' ...
            ' '    timeRange ...
            ' ('   fName ')'];
end

end
