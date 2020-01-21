function [rules] = StaroddiRules()
% function [rules] = StaroddiRules()
%
% Load the structural rules for reading and processing Star-Oddi
% Instruments.
%
% This is a declarative function that setup meta parameters and functions
% on how to read the headers/data of the instrument file.
%
% Inputs:
%
% Outputs:
% rules - a structure with several substrucutres
%      .header_def_rules - a structure where fieldsnames are functions
%                          handles to read the header information.
%      .header_oper_rules - a structure where fieldnames are meta-Header
%                           structs that hold functions which
%                           convert/parse the header information.
%      .data_def_rules - as above but to read the data block only
%      .data_oper_rules - as above but to convert/extract the data.
%      .name_map_rules - the mapping rules between header names to other names.
%
% The outputs are used by the respective `Instrument`Parser function
% to read the data into the Toolbox structure.
%
% For more information, see comments in the StaroddiRules.m file, which
% explains all the functionality.
%
% author: hugo.oliveira@utas.edu.au

% Copyright (C) 2019, Australian Ocean Data Network (AODN) and Integrated
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

narginchk(0, 0)

% We seek to first, extract correctly the header lines.
% For this, we need to read every line of the header and assign
% name(s) and value(s) to it. Hence, we need to create rules.
%
% This set of rules is called here 'header definition rules'.
% It's a struct where fieldnames are anonymous functions that
% return regex patterns.
% The reason why is clear in the example below - it allow consistency
% with the rest of the machinery and a lot of flexibility.
%
% The definitions need to ensure the evaluation of the rules create
% a key:value structure output, where key/value are strings.
%
% Hence, the idea here is to (meta)-compose how the headers are read,
% so we can store them, lazy-evaluate and/or do some dependency
% injection.
%
% The struct requires the following fields:
% .func - the function accepting the header line string
%
% .line_signature - a function that creates arguments to .func
% that will detect if the line is a header line
%
% .key_value_signature - a function that creates arguments to .func
%  and that will extract the line information to a meta-header
% struct.
%
% Example:
%
% x.func = regexpi;
% x.line_signature = @() '^%';
% x.key_value_signature  = @() {'^(?<linenumber>(%[0-9]+))\s(?<name>(.+))$','names'}
%
% %This will ensure that:
% is_header_line  =  x.func('%1 Instrument : Starmon Oddi',x.line_signature())
% assert(is_header_line)
%
% %and that:
% y = x.func('%1 Starmon abcdef.33.54.6',x.key_value_signature(){:})
% assert(strcmpi(y.linenumber,'1'));
% assert(strcmpi(y.key,'Instrument'));
% assert(strcmpi(y.value,'Starmon'));
%
% Hence, we can extract the exact reference/name.
%

% basic definitions
header_def_rules = struct();
header_def_rules.func = @regexpi; % the function
header_def_rules.line_signature = @(n) '^#'; % signature of a a header line

% Starmon mini/DST sentences are:
% 1. simple word -> Created, Columns,
% 2. a 2 word sentence separated by tab -> Version    Seastar.
% 3. a 2 word sentence with specific number -> Axis    0, Series    0
% 4. a Recorder entry -> Recorder: value
% 5. a new[2019] Recorder entry -> Recorder    7    Starmon mini    4047
% 6. a 2 word sentence separated by space, with & separation or with a dot at the end ->  Date def., Date & Time, Field Separator,
% 7. Separation usually occurs at \t or \s

% Hence, create auxiliar fields to compose the key_value_signature
header_def_rules.lineid = @() '(?<lineid>(?:^#[0-9]+|^#+|^#[A-Z]+))';
header_def_rules.key = @() '(?<key>(?:(Recorder\s)|(Axis\s[0-9])|(Series\s[0-9])|([\w-\\.]+[\w-\\.\& ]+)))';
header_def_rules.separator0 = @() '[\s\t]+';
header_def_rules.separator1 = @() '(?:[:]\s|\s)';
header_def_rules.value = @() '(?<value>(.*$))';

%define a function with regex arguments that will read a header line as key:value
header_def_rules.key_value_signature = @() {
strcat(header_def_rules.lineid(), ...
    header_def_rules.separator0(), ...
    header_def_rules.key(), ...
    header_def_rules.separator1(), ...
    header_def_rules.value()), ...
    'names'
};

% Now that we got a "key" (or name) and a "value", we can use
% applicable transformations to them, if not applied already.
%
% Since the "key" can be any string,
% including invalid variable names in matlab,
% we need to manually define a alternative dummy name
% to be used as fieldname.
%
% We then pass key(s) name as argument(s) and a transformation function that
% accept the argument(s) in a simple structure:
%
% Example of definition:
%
%  % header line -> %1 Starmon Mini    SN:1234
%  KEY = 'Starmon Mini'; VALUE = 'SN:1234'
%  INAME = 'serialnumber'
%  split = @(x) (strsplit(x,':'));
%  getcellindex = @(x,i) x{i};
%  fun = @(x) getcellindex(split(x),2);
%  oper_rule.(INAME)= argstruct({KEY},fun);
%
% The definition is made this way to support nesting of
% functions (as above) and multi key/value arguments (with {{}}).
% This is useful if a transformation requires
% more than a simple function to be applied (as above) or
% more than one key (the outcome requires information
% spread over several header lines).
%
% The outcome will be a header_information structure:
%
% assert(hinfo.serialnumber,'1234')
%
% To understand the machinery see readLinesWithRegex,
% readHeaderDict, and translateHeaderText.
%
%

%functions
keep_original_str = @(x) x;
str2number = @(x) str2double(strtrim(x));
str2bool = @(x) logical(str2number(x));
str2bool_rev = @(x)~str2bool(x);

header_oper_rules = struct(); % args should match keys read by header_def_rules

%The below structure will ensure fun(header_content{n}.value) is triggered if strcmpi(header_content{n}.key,'Date-Time') is true.
header_oper_rules.date_time = argstruct({'Date-time'}, keep_original_str);
header_oper_rules.created = argstruct({'Created'}, keep_original_str);
header_oper_rules.recorder = argstruct({'Recorder'}, @StarmonRecorder);
header_oper_rules.file_type = argstruct({'File type'}, str2bool);
header_oper_rules.columns = argstruct({'Columns'}, str2number);
header_oper_rules.field_separation = argstruct({'Field separation'}, str2number);
header_oper_rules.decimal_point = argstruct({'Decimal point'}, @StarmonDecimalFlag);
header_oper_rules.date_def = argstruct({'Date def.'}, @StarmonDateDef);
header_oper_rules.time_def = argstruct({'Time def.'}, @StarmonTimeDef);
header_oper_rules.data_def = argstruct({'Data'}, @StarmonDataDef);

maxchannels = 16; % maximum allowed number of channels entries is 8x2( 8 variables with reconvertions)

for k = 1:maxchannels

    fname = ['Channel ' num2str(k)]; % as shown on the file, avoid strcat since space is ignored
    aname = ['Axis ' num2str(k - 1)];
    sname = ['Series ' num2str(k - 1)];

    %compute channel index name
    c_vname = strcat('channel_index_', num2str(k));
    header_oper_rules.(c_vname) = argstruct({fname}, @StarmonVariableInfo);

    % dst uses axis/series
    % Note that series and axis start from zero
    c_avname = strcat('axis_index_', num2str(k - 1));
    header_oper_rules.(c_avname) = argstruct({aname}, @StarmonVariableInfo);

    c_svname = strcat('series_index_', num2str(k - 1));
    header_oper_rules.(c_svname) = argstruct({sname}, @StarmonVariableInfo);

    % if ever needed, the complete channel/axis/series header can be accessed
    % in the _info fields.
    cname = strcat('channel_info_', num2str(k));
    header_oper_rules.(cname) = argstruct({fname}, @StarmonChannelInfo);

    % dst uses axis/series
    % Note that series and axis start from zero
    c_aname = strcat('axis_info_', num2str(k - 1));
    header_oper_rules.(c_aname) = argstruct({aname}, @StarmonAxisInfo);

    c_sname = strcat('series_info_', num2str(k - 1));
    header_oper_rules.(c_sname) = argstruct({sname}, @StarmonSeriesInfo);

end

header_oper_rules.pressure_offset_correction = argstruct({'Pressure offset correction'}, @StarmonPressureOffset);
header_oper_rules.reconvertion = argstruct({'Reconvertion'}, str2bool);
header_oper_rules.trend_type_number = argstruct({'Trend Type Number'}, str2bool);
header_oper_rules.no_temperature_correction = argstruct({'No temperature correction'}, str2bool_rev);
header_oper_rules.limit_temp_corr_OTCR = argstruct({'Limit Temp. Corr. OTCR'}, str2bool);

split_spaces = @(x) strsplit(x);
header_oper_rules.line_color = argstruct({'Line color'}, split_spaces);

% Headers lines from StarmonMini version 001 - 2019
first_split = @(x) x{1};
second_split = @(x) x{2};
get_software = @(x) first_split(strsplit(x));
get_version = @(x) second_split(strsplit(x));
header_oper_rules.sofware_name = argstruct({'Version'}, get_software);
header_oper_rules.software_version = argstruct({'Version'}, get_version);

% Now it's time to define how to read the data block
% Since we are dealing with text files, most data blocks are simply columnar.
% Hence, the textscan function is better suited and most performant (no need to read line by line).
%
% The definition here is the same as the header read rules above,
% but way more simpler. The only thing required is to properly pass the dynamic number of columns.
%
% An example of a common data block definition for Starmon is:
%
%`index` \fieldSep `date` \whitespace `hour` \fieldSep `Channel1`          \fieldSep `Channel2` ...
%
% For example:
%'1  21.04.14 02:00:00       25,54'
%

data_def_rules = struct();

data_def_rules.func = @textscan;
data_def_rules.line_signature = @(n) '%d';

%auxiliar
data_def_rules.indexnumber = @(n) '%d';
data_def_rules.date = @(n) '%s';
% At reading time, the total number of columns is dictated by the
% columns header.
% The number of channels is nCol-2.
% If the data is reconverted, every channel will have two "sub-channels"
% a default and "converted" value.
%
% The trick here is to inject a dependency - the number of columns is dependent
% on the reconverted attribute and column attribute.
% Hence, the anonymous function here allow us to define the number of columns dynamically.
data_def_rules.channel = @(hinfo) repmat('%s', 1, StarmonTotalNumberOfDataColumns(hinfo));

% Separator is also defined in the header.
data_def_rules.sep = @(field_separation) StarmonFieldSeparator(field_separation);

%Build the function that will create the whole string for textscan.
data_def_rules.key_value_signature = @(hinfo) {strcat(...
data_def_rules.indexnumber(), ...
    data_def_rules.date(), ...
    data_def_rules.channel(hinfo)), ...
    'Delimiter', ...
    data_def_rules.sep(hinfo.field_separation)};

% Great. Similarly to the previous case, all the data will be stored in
% a structure, in this case, `raw_data`. As expected,
% those entries will also need to be named/transformed to their
% respective representation.
%
%For example, to define the correct date, we need the date column, the date & time_def header definitions.
%
% the order here should follow the column order for simplicity.
%
%
% IMPORTANT - the operation rules should be ordered from left to right (column wise)
data_oper_rules = struct();
line_number = @(rawdata) rawdata{1}; % no transform, just extraction
data_oper_rules.indexnumber = argstruct({'rawdata'}, line_number);

% To parse date we need the correct column and some header fields.
% The reference to date_def will be gather automatically
% since the machinery have access to both rawdata and header_info.
parse_date = @(rawdata, date_fmt, time_fmt) StarmonGenDate(rawdata{2}, date_fmt, time_fmt); % date is always second column
data_oper_rules.date = argstruct({'rawdata', 'date_def', 'time_def'}, parse_date);

str2channel = @(x) sscanf(strrep(sprintf('%s ', x{:}), ',', '.'), '%f '); % faster than str2double(strrep(x, ',', '.'));

%build as many transformers as required but following a index order

for k = 1:maxchannels
    % the trick here is to link channel - series - axis entries.
    cname = ['channel_index_' num2str(k)]; % as stored here.
    data_oper_rules.(cname) = argstruct({'rawdata'}, @(rawdata) str2channel(rawdata{k + 2}));
end

% We now completed the reading/transform/parsing step and the fields
% will be also in a structure with fieldnames
%
% The final step is to just match some names to fields -
% The rule here is relatively simple since it's the
% parser function job to map to IMOS/Toolbox variables
% and add comments.
%

name_map_rules = struct();
name_map_rules.date = @(x) 'TIME';

for k = 1:maxchannels
    cname = ['channel_index_' num2str(k)];
    % Variable name is defined by StarmonVariableInfo
    name_map_rules.(cname) = @(hinfo) selectChannelOrAxisName(hinfo, k);

    % cname = ['channel_units_' num2str(k)];
    % name_map_rules.(cname) = @(hinfo) selectChannelOrAxisUnits(hinfo, k);
    % aname = ['axis_index_' num2str(k - 1)];
    % name_map_rules.(aname) = @(hinfo) upper(hinfo.(aname));

end

rules = struct();
rules.header_def_rules = header_def_rules;
rules.header_oper_rules = header_oper_rules;
rules.data_def_rules = data_def_rules;
rules.data_oper_rules = data_oper_rules;
rules.name_map_rules = name_map_rules;

end

function [cnumber] = StarmonTotalNumberOfDataColumns(hinfo)
% function [cnumber] = StarmonTotalNumberOfDataColumns(hinfo)
%
% Compute the number of de-facto columns given
% a header information
%
% Inputs:
%
% hinfo - The header_information structure generated
% after reading the entire header.
%
%
% Outputs:
% cnumber - number of columns [int]
%
% Example:
%
% % basic case
% hinfo = struct('columns',6);
% cnumber = StarmonTotalNumberOfDataColumns(hinfo);
% assert(cnumber==4);
% % reconverted case
% hinfo = struct('columns',6,'reconvertion',True);
% cnumber = StarmonTotalNumberOfDataColumns(hinfo);
% assert(cnumber==6)
%
% hinfo

% header_info.channel_1 = [];
% header_info.channel_2 = [];
% [nc] = StarmonNumberOfColumns(header_info)
% assert(nc==2)
%
% author: hugo.oliveira@utas.edu.au
%

%Channels in new Starmon mini are defined by the number
% of axis and Series defs or channel defs
if isfield(hinfo,'columns')
    cnumber = hinfo.columns-2;
    return
end

z = fieldnames(hinfo);

containAxis = sum(contains(z, 'axis_index_'));
containSeries = sum(contains(z, 'series_index_'));
containChannel = sum(contains(z, 'channel_index_')); % closer match

if (containChannel && (containSeries || containAxis)) || (containAxis && containSeries && containChannel)
    error('File contains multiple column definitions')
end

if ~containChannel && (~containSeries &&~containAxis)
    error('File is missing Series/Axis definitions')
end

if containAxis > 0
    cnumber = containAxis;
else
    cnumber = containChannel;
end

end

function [timeFormat] = StarmonTimeDef(astr)
% function [timeFormat] = StarmonTimeDef(astr);
% Get the time definition from Starmon
% headers
%
% Inputs:
%
% `astr` - a string representing the value of
% the Time def. field in the header
%
% Outputs:
% `timeFormat` - a string for hour conversion.
%
% Example:
%
% [tdef] = StarmonTimeDef(':')
% assert(strcmp(tdef,'HH:MM:SS'))
% [tdef] = StarmonTimeDef('1')
% assert(strcmp(tdef,'HH.MM.SS'))
%
% author: hugo.oliveira@utas.edu.au
%
is_colon = strcmpi(astr, ':');
is_zero = strcmpi(astr, '0');

if is_colon || is_zero
    timeFormat = 'HH:MM:SS';
else
    timeFormat = 'HH.MM.SS';
end

end

function [ddef] = StarmonDateDef(astr)
% function [rec] = StarmonDateDef(astr);
% Get the date definition from Starmon
% headers
%
% Inputs:
%
% `astr` - a string representing the value of
% the Time def. field in the header
%
% Outputs:
% `ddef` - a string representing the entry for date
% conversion.
%
% Example:
%
%  [ddef] = StarmonDateDef('dd/mm/yyyy    \')
%  assert(strcmp(ddef,'dd/mm/yyyy'))
%
%  [ddef] = StarmonDateDef('0    0')
%  assert(strcmp(tdef,'dd.mm.yy');
%
% author: hugo.oliveira@utas.edu.au
%
cleanstr = strtrim(astr);

old_reg_exp = '(?<idate0>(^[0-9]))\s(?<idate1>([0-9]))';
dentry = '(d{2}|m{2}|y{2,4})';
new_reg_exp = ['^' dentry '([\/|\.])' dentry '([\/|\.])' dentry];

sdate = regexpi(cleanstr, old_reg_exp, 'names');

if ~isempty(sdate)
    b0 = str2double(sdate.idate0);
    b1 = str2double(sdate.idate1);
    ddef = StarmonDateFormat([b0 b1]);
else
    found = regexpi(cleanstr, new_reg_exp, 'end');

    if logical(found)
        ddef = cleanstr(1:found);
    else
        error('Could not define date based on input %s', astr);
    end

end

end

function [data_info] = StarmonDataDef(astr)
% function [data_info] = StarmonDataDef(astr)
%
% Get the data information - number of entries,
% date start and date end.
%
% Inputs:
%
% astr - a string representing the value of
% the Data field in the header
%
% Outputs:
% data_info - a struct with the fields
%
% Example:
%
% [data_info] = StarmonDataDef('87216	02/03/2016 00:00:00	29/12/2016 19:55:00')
% assert(data_info.total_entries==87216);
% assert(strcmpi(data_info.start_date,'02/03/2016 00:00:00'));
% assert(strcmpi(data_info.end_date,'29/12/2016 19:55:00'));
%
% author: hugo.oliveira@utas.edu.au
%

entries = '(?<total_entries>([0-9]+?(?=\s)))';
start_date = '(?<start_date>(.+?(?=\s)\s.+?(?=\s)))';
end_date = '(?<end_date>(.+?(?=\s)\s.+))';
dinfo_re = ['^' entries '\s' start_date '\s' end_date '$'];
data_info = regexpi(astr, dinfo_re, 'names');
data_info.total_entries = str2double(data_info.total_entries);

end


function [rec] = StarmonRecorder(astr)
% function [rec] = StarmonRecorder(astr);
% Compute the Recorder Information fields
% reported in Starmon headers.
%
% Inputs:
%
% astr - a string representing the value of
% the recorder field in the header
%
% Outputs:
% rec - a structure with
%    .serial - a string with the serial number
%    .instrument - a string with the instrument name
%    .recorder - a string with the recorder number
%
% Example:
%
%  [rec] = StarmonRecorder('7    Starmon mini    4047')
%  assert(strcmp(rec.serial,'4047'))
%  assert(strcmp(rec.instrument,'Starmon mini'))
%  assert(strcmp(rec.recorder,'7'))
%
%  [s,i,r] = StarmonRecorder('4T3769')
%  assert(strcmp(rec.serial,'3769'))
%  assert(strcmp(rec.instrument,'Starmon mini'))
%  assert(strcmp(rec.recorder,'4'))
%
%  [s,i,r] = StarmonRecorder('4X1010')
%  assert(strcmp(rec.serial,'1010'))
%  assert(strcmp(rec.instrument,'Starmon DST CTD'))
%  assert(strcmp(rec.recorder,'4'))

%
% author: hugo.oliveira@utas.edu.au
%

rnum_re = '(?<recorder>([0-9]+?(?=\s)))';
iname_re = '(?<instrument_name>(.+?(?=\s[0-9])))';
snumber_re = '(?<serial_number>([0-9]+))';
new_starmon_re_exp = ['^' rnum_re '\s' iname_re '\s' snumber_re];

rec = regexpi(astr, new_starmon_re_exp, 'names');

if isempty(rec)
    %Note: Older parsers ignored the first number of the recorder entry.
    % we will do the same here to maintain compatibility
    rnum_re = '(?<recorder>([0-9]))';
    snumber_re = '(?<serial_number>([A-Z][0-9]+))';
    old_starmon_re_exp = ['^' rnum_re snumber_re];
    rec = regexpi(astr, old_starmon_re_exp, 'names');

    if isempty(rec)
        error('Could not detect Recorder information at line `%s`', astr);
    end

end

if ~isfield(rec, 'instrument_name')

    if contains(rec.serial_number, 'X')
        rec.instrument_name = 'DST Tilt';
    else

        if contains(rec.serial_number, 'T')
            rec.instrument_name = 'Starmon Mini';
        else
            rec.instrument_name = 'DST CTD';
        end

    end

end

end

function [dchar] = StarmonDecimalFlag(astr)
% function [dchar] = StarmonDecimalFlag(astr);
%
% Return a valid decimal char used/reported
% in the Starmon headers
%
% Inputs:
%
% `astr` - a string
%
% Outputs:
%
% `dchar` - decimal character
%
% Example:
%
% assert(strcmp(StarmonDecimalFlag('.'),'.'))
% assert(strcmp(StarmonDecimalFlag(','),','))
% % error is raised
% StarmonDecimalFlag('abc')
%
% author: hugo.oliveira@utas.edu.au
%

dchar = strtrim(astr);
not_dot = ~strcmpi(dchar, '.');
not_comma = ~strcmpi(dchar, ',');

if not_dot && not_comma
    % old decimal flags are a boolean
    number = str2double(astr);

    if isnan(number)
        error("Could not read the decimal flag. Invalid string: '%s'", astr);
    end

    % convert the boolean to char
    if logical(number)
        dchar = '.';
    else
        dchar = ',';
    end

end

end

function [info] = StarmonChannelInfo(astr)
% function [info] = StarmonChannelInfo(astr),
% Process the channel info line in Starmon Headers.
%
% Inputs:
%
% `astr`  - string representing a line in the Starmon header with channel information..
%
% Outputs:
%
% `info` - A struct with channel information.
%
% Example:
%
%  info = StarmonChannelInfo('   Temperature(°C) Temp(°C)        2       1');
%  assert(strcmp(info.channel_name, 'Temperature'))
%  assert(strcmp(info.channel_units, '°C'))
%  assert(strcmp(info.column_name, 'Temp'))
%  assert(strcmp(info.column_units, '°C'))
%  assert(info.nDec == 2)
%  assert(info.isPositiveUp == 1)
%
% author: hugo.oliveira@utas.edu.au
%

cname_re = '(?<channel_name>(.+?(?=\()))';
cunit_re = '\((?<channel_units>(.+?(?=\))))\)';
colname_re = '(?<column_name>(.+?(?=\()))';
colunits_re = '\((?<column_units>(.+?(?=\))))\)';
ndec_re = '(?<number_of_decimals>([0-9]))';
adir_re = '(?<axis_direction>([0-9]))';
aregex = ['^' cname_re cunit_re '\s' colname_re colunits_re '\s' ndec_re '\s' adir_re '$'];
info = regexpi(astr, aregex, 'names');

if isempty(info)
    error('Could not read Channel information line `%s`', astr);
end

info.nDec = str2double(info.number_of_decimals);
info.isPositiveUp = logical(str2double(info.axis_direction));
end

function [pflag, pvalue] = StarmonPressureOffset(astr)
%function [pflag,pvalue] = StarmonPressureOffset(field)
%
% Compute the pressure Offset information in the Starmon headers
%
% Inputs:
%
% astr - a string representing the pressure offset entry
%
% Outputs:
%
% pflag - pressure offset flag
% pvalue - pressure offset value
%
% Example:
%
% astr = '1	0.000';
% [pflag,pvalue] = StarmonPressureOffset(astr);
% assert(pflag==1);
% assert(pvalue==0);
%
% author: hugo.oliveira@utas.edu.au
%

s = strsplit(astr);

if length(s) ~= 2
    error("Could not extract pressure information at line '%s'", astr);
end

pflag = str2double(s{1});
pvalue = str2double(s{2});

if isnan(pflag) || isnan(pvalue)
    error("Could not define pressure correction at line '%s'", astr)
end

end

function [fieldSep] = StarmonFieldSeparator(field_separation)
% function fieldSep = StarmonFieldSeparator(field_se)
%
% Compute the separator char used/reported
% in the Starmon headers.
%
% Inputs:
%
% field_separtion - a boolean
%
% Outputs:
%
% fieldSep - separation char
%
% Example:
%
%  [fieldSep] = StarmonFieldSeparator(0)
%  assert(strcmp(fieldSep,'\t'))
%
% author: hugo.oliveira@utas.edu.au
%

if field_separation == 0
    fieldSep = '\t';
else
    fieldSep = ' ';
end

end

function [dateFormat] = StarmonDateFormat(date_def_arr)
% function [dateFormat] = StarmonDateFormat(date_def_arr)
%
% Return the datenum format given date_def_arr defined
% in the Starmon headers.
%
% Inputs:
%
% date_def_arr - an 1x2 numeric array.
%
% Outputs:
%
% dateFormat - a string to be used in datenum.
%
% Example:
%
%  dateFormat = StarmonDateFormat([0 0])
%  assert(strcmpi(dateFormat,'dd.mm.yy'))
%
% author: hugo.oliveira@utas.edu.au
%
fmt = struct();
fmt.dot_day_format = 'dd.mm.yy';
fmt.dot_month_format = 'mm.dd.yy';
fmt.slash_day_format = 'dd/mm/yy';
fmt.slash_month_format = 'mm/dd/yy';
fmt.dash_day_format = 'dd-mm-yy';
fmt.dash_month_format = 'mm/dd/yy';

r = struct();
r.dot_day_format = date_def_arr(1) == 0 && date_def_arr(2) == 0;
r.dot_month_format = date_def_arr(1) == 1 && date_def_arr(2) == 0;
r.slash_day_format = date_def_arr(1) == 0 && date_def_arr(2) == 1;
r.slash_month_format = date_def_arr(1) == 1 && date_def_arr(2) == 1;
r.dash_day_format = date_def_arr(1) == 0 && date_def_arr(2) == 2;
r.dash_month_format = date_def_arr(1) == 1 && date_def_arr(2) == 2;

scases = fields(r);
c = 0;

for k = 1:length(scases)
    name = scases{k};

    if r.(name)
        dateFormat = fmt.(name);
        return;
    end

    c = c + 1;
end

error('No dateFormat detected');
end

function [numdate] = StarmonGenDate(date_str, date_fmt, time_fmt)
% function [FulldateFormat] = StarmonGenDate(date_str,date_fmt,
% time_fmt)
%
% Parse the date_str data block from a Starmon file.
%
% Inputs:
%
% date_str - the string representing the full date.
% date_fmt - the string fmt of date
% time_fmt - the string fmt of hour
%
% Outputs:
%
% numdate - the datenum number representation
%
% Example:
%
%  numdate = StarmonFulldateFormat('01.01.2000 00:00:00','dd.mm.yy','HH:MM:SS')
%  assert(numdate  ==  730486)
%  assert(strcmpi(datestr(numdate),'01-Jan-2000'))
%
% author: hugo.oliveira@utas.edu.au
%

datenum_str = [date_fmt ' ' time_fmt];
numdate = datenum(date_str, datenum_str);
end

function [info] = StarmonAxisInfo(astr)
% function info = StarmonAxisInfo(astr)
%
% Define the struct for the Axis info line
% in starmon headers.
%
% Inputs:
%
% astr - The string representing Axis information
%
% Outputs:
%
% info - a Structure with the axis information
%
% Example:
%
%  [info] = StarmonAxisInfo('Temperature(°C) clRed    FALSE');
%  assert(strcmpi(info.axis_name,'Temperature'));
%  assert(strcmpi(info.axis_units,'°C'));
%  assert(strcmpi(info.flag0,'clRed'));
%  assert(strcmpi(info.flag1,'FALSE'));
%
% author: hugo.oliveira@utas.edu.au
%

aname_re = '(?<axis_name>(.+?(?=\()))';
aunit_re = '\((?<axis_units>(.+?(?=\))))\)';
f0_re = '(?<flag0>(.+?(?=\s)))';
f1_re = '(?<flag1>(\w+))';
aregex = ['^' aname_re aunit_re '\s' f0_re '\s' f1_re '$'];
info = regexpi(astr, aregex, 'names');

if isempty(info)
    error("Could not read Axis information line '%s'", astr);
end

end

function [info] = StarmonSeriesInfo(astr)
% function info = StarmonSeriesInfo(astr)
%
% Define the struct for the Series info line
% in starmon headers.
%
% Inputs:
%
% astr - The string representing Series information
%
% Outputs:
%
% info - a Structure with the axis information
%
% Example:
%
%  [info] = StarmonSeriesInfo('Temperature(°C)     clRed    0    Temp(°C)    4');
%  assert(strcmpi(info.series_name_1,'Temperature'));
%  assert(strcmpi(info.series_units_1,'°C'));
%  assert(strcmpi(info.flag0,'clRed'));
%  assert(strcmpi(info.flag1,'0'));
%  assert(strcmpi(info.series_name_2,'Temp'));
%  assert(strcmpi(info.series_units_2,'°C'));
%  assert(strcmpi(info.flag2,'4'));
%
% author: hugo.oliveira@utas.edu.au
%

sname1_re = '(?<series_name_1>(.+?(?=\()))';
sunit1_re = '\((?<series_units_1>(.+?(?=\))))\)';
cname_re = '(?<cname>(.+?(?=\s)))';
f0_re = '(?<flag0>([0-9]))';
sname2_re = '(?<series_name_2>(.+?(?=\()))';
sunit2_re = '\((?<series_units_2>(.+?(?=\))))\)';
f1_re = '(?<flag1>([0-9]))';
fullregex = ['^' sname1_re sunit1_re '\s' cname_re '\s' f0_re '\s' sname2_re sunit2_re '\s' f1_re '$'];
info = regexpi(astr, fullregex, 'names');

if isempty(info)
    error("Could not read Series information line '%s'", astr);
end

end

function [varname] = StarmonVariableInfo(astr)
% function info = StarmonVariableInfo(astr)
%
% Define the variable name from the Channel, Axis,
% or Series header string.
%
% Inputs:
%
% astr - The string representing Channel, Axis,
%        or Series information.
%
% Outputs:
%
% varname - the specific variable name
%
% Example:
%
% % Starmon - channel header
% name = StarmonVariableInfo('   Temperature(°C) Temp(°C)        2       1');
% assert(name,'Temperature');
% % Starmon - Axis header
% name = StarmonVariableInfo('Temperature(°C) clRed    FALSE');
% assert(name,'Temperature');
% % Starmon - Series header
% name = StarmonSeriesInfo('Temperature(°C)     clRed    0    Temp(°C)    4');
% assert(name,'Temperature');
%
% author: hugo.oliveira@utas.edu.au
%

try
    info = StarmonChannelInfo(astr);
    varname = info.channel_name;
catch

    try
        info = StarmonAxisInfo(astr);
        varname = info.axis_name;
    catch

        try
            info = StarmonSeriesInfo(astr);
            varname = info.series_name;
        catch
            error("Could not define variable name based on line %s", astr);
        end

    end

end

end

function [varname] = selectChannelOrAxisName(hinfo, k)
% function info = selectChannelOrAxisName(hinfo,k)
%
% Select the proper name present in the header info.
% It will choose Channel if reading from
% starmon mini, or axis if from DST/others.
%
% Inputs:
%
% hinfo - The header information structure
% k - the index number.
%
% Outputs:
%
% varname - the variable name of that particular channel/axis.
%
% Example:
%
% % Starmon mini
% hinfo = struct('channel_units_3','Temperature'));
% varname = selectChannelOrAxisName(hinfo,1);
% assert(strcmp(varname,'Temperature'))
% % Starmon DST and others
% hinfo = struct('axis_units_3','Roll'));
% varname = selectChannelOrAxisName(hinfo,3);
% assert(varname,'Roll');
%
% author: hugo.oliveira@utas.edu.au
%

mini_match = ['channel_index_' num2str(k)];
oddi_match = ['axis_index_' num2str(k - 1)]; % axis are 0 based
names = fieldnames(hinfo);
is_mini = sum(contains(names, mini_match));
is_oddi = sum(contains(names, oddi_match));

if ~is_mini &&~is_oddi
    missing_entry = k == 1 && hinfo.reconvertion;

    if missing_entry
        error("Missing Channel (Axis) entry %d (%d)", k, k - 1);
    else
        varname = selectChannelOrAxisName(hinfo, k - 1);
    end

elseif is_mini
    varname = hinfo.(mini_match);
else
    varname = hinfo.(oddi_match);
end

end
