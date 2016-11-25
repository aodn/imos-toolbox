function sample_data = RCMParse( filename, mode )
%RCMParse Parses a .txt data file from RCM-8 and old Seaguard RCM files processed with
%Aanderaa software.
%
%   - processed header  - header information.
%                         Typically first 2 lines.
%   - data              - Rows of tab seperated data.
%
% This function reads in the header sections, and delegates to the two file
% specific sub functions to process the data.
%
% Inputs:
%   filename    - cell array of files to import (only one supported).
%   mode        - Toolbox data type mode.
%
% Outputs:
%   sample_data - Struct containing sample data.
%
% Code based on VemcoParse.m, itself base on readSBE37cnv.m
%
% Author:       Peter Jansen <peter.jansen@csiro.au>

%
% Copyright (c) 2016, Australian Ocean Data Network (AODN) and Integrated
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
%     * Neither the name of the AODN/IMOS nor the names of its contributors
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
narginchk(1,2);

if ~iscellstr(filename)
    error('filename must be a cell array of strings');
end

% only one file supported currently
filename = filename{1};

% read in every line of header in the file, then big read of data
procHeaderLines = {};
try
    % header is two lines
    fid = fopen(filename, 'rt');
    line = fgetl(fid);
    procHeaderLines{end+1} = line;
    line = fgetl(fid);
    procHeaderLines{end+1} = line;
    dataHeaderLine=line;
    
    % assume date and time would always be the first and second column, if
    % not will need to make a regexp for dataHeaderLine and get the index
    iDate=2;

    iDateTimeCol=iDate;
    ncolumns=numel(regexp(dataHeaderLine,'\t','split'));
    
    % consruct a format string using %s for date and time, and %f32 for
    % everything else
    formatstr = '';
    for k = 1:ncolumns
        if ismember(k,iDateTimeCol)
            formatstr = [formatstr '%s'];
        else
            formatstr = [formatstr '%f32'];
        end
    end
    
    dataLines = textscan(fid,formatstr,'Delimiter','\t');
    
    fclose(fid);
    
catch e
    if fid ~= -1, fclose(fid); end
    rethrow(e);
end

% read in the raw instrument header
procHeader = parseProcessedHeader( procHeaderLines, dataHeaderLine);
procHeader.toolbox_input_file = filename;

% use Vemco specific csv reader function
[data, comment] = readRCMtxt(dataLines, procHeader);

% create sample data struct,
% and copy all the data in
sample_data = struct;

sample_data.toolbox_input_file  = filename;
sample_data.meta.featureType    = mode;
sample_data.meta.procHeader     = procHeader;

sample_data.meta.instrument_make = 'Aanderaa';
if isfield(procHeader, 'instrument_model')
    sample_data.meta.instrument_model = procHeader.instrument_model;
else
    sample_data.meta.instrument_model = 'Sea Guard';
end

if isfield(procHeader, 'instrument_firmware')
    sample_data.meta.instrument_firmware = procHeader.instrument_firmware;
else
    sample_data.meta.instrument_firmware = '';
end

if isfield(procHeader, 'instrument_serial_no')
    sample_data.meta.instrument_serial_no = procHeader.instrument_serial_no;
else
    sample_data.meta.instrument_serial_no = '';
end

time = data.TIME;

if isfield(procHeader, 'sampleInterval')
    sample_data.meta.instrument_sample_interval = procHeader.sampleInterval;
else
    sample_data.meta.instrument_sample_interval = median(diff(time*24*3600));
end

sample_data.dimensions = {};
sample_data.variables  = {};

% generate time data from header information
sample_data.dimensions{1}.name          = 'TIME';
sample_data.dimensions{1}.typeCastFunc  = str2func(netcdf3ToMatlabType(imosParameters(sample_data.dimensions{1}.name, 'type')));
sample_data.dimensions{1}.data          = sample_data.dimensions{1}.typeCastFunc(time);

sample_data.variables{end+1}.name           = 'TIMESERIES';
sample_data.variables{end}.typeCastFunc     = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{end}.name, 'type')));
sample_data.variables{end}.data             = sample_data.variables{end}.typeCastFunc(1);
sample_data.variables{end}.dimensions       = [];
sample_data.variables{end+1}.name           = 'LATITUDE';
sample_data.variables{end}.typeCastFunc     = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{end}.name, 'type')));
sample_data.variables{end}.data             = sample_data.variables{end}.typeCastFunc(NaN);
sample_data.variables{end}.dimensions       = [];
sample_data.variables{end+1}.name           = 'LONGITUDE';
sample_data.variables{end}.typeCastFunc     = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{end}.name, 'type')));
sample_data.variables{end}.data             = sample_data.variables{end}.typeCastFunc(NaN);
sample_data.variables{end}.dimensions       = [];
sample_data.variables{end+1}.name           = 'NOMINAL_DEPTH';
sample_data.variables{end}.typeCastFunc     = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{end}.name, 'type')));
sample_data.variables{end}.data             = sample_data.variables{end}.typeCastFunc(NaN);
sample_data.variables{end}.dimensions       = [];

% scan through the list of parameters that were read
% from the file, and create a variable for each
vars = fieldnames(data);
coordinates = 'TIME LATITUDE LONGITUDE NOMINAL_DEPTH';
for k = 1:length(vars)
    
    if strncmp('TIME', vars{k}, 4), continue; end
    
    % dimensions definition must stay in this order : T, Z, Y, X, others;
    % to be CF compliant
    sample_data.variables{end+1}.dimensions     = 1;
    sample_data.variables{end  }.name           = vars{k};
    sample_data.variables{end  }.typeCastFunc   = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{end}.name, 'type')));
    sample_data.variables{end  }.data           = sample_data.variables{end}.typeCastFunc(data.(vars{k}));
    sample_data.variables{end  }.coordinates    = coordinates;
    sample_data.variables{end  }.comment        = comment.(vars{k});
end

end

function header = parseProcessedHeader(headerLines, dataHeaderLine)

  header = struct;
    
  header.nHeaderLines=numel(headerLines)+1;
  header.columns = regexp(dataHeaderLine,'\t','split');

end

function [data, comment] = readRCMtxt(dataLines, procHeader)
%readRCMtxt Processes data section from a aanderaa .txt file.
%
% Inputs:
%   dataLines - cell array of columns of raw data.
%   procHeader - Struct containing processed header.
%
% Outputs:
%   data       - Struct containing variable data.
%   comment    - Struct containing variable comment.
%

narginchk(2,2);

data = struct;
comment = struct;

columns = procHeader.columns;
% assume date and time would always be the first and second column
iDate=2;
iDateTimeCol=iDate;
iProcCol=setdiff((1:length(columns)),iDateTimeCol);

% I don't know how to handle seperate date/time column in loop nicely
% so pull out datetime and set here, and process the other columns in the
% loop.
data.TIME = datenum(dataLines{iDate},'dd.mm.yy HH:MM:SS');
comment.TIME = 'TIME';

for kk = 1:length(iProcCol)
    iCol=iProcCol(kk);
    
    d = dataLines{iCol};
    
    [n, d, c] = convertData(genvarname(columns{iCol}), d);
    
    if isempty(n) || isempty(d), continue; end
    
    % if the same parameter appears multiple times,
    % don't overwrite it in the data struct - append
    % a number to the end of the variable name, as
    % per the IMOS convention
    count = 0;
    nn = n;
    while isfield(data, nn)
        
        count = count + 1;
        nn = [n '_' num2str(count)];
    end
    
    data.(nn) = d;
    comment.(nn) = c;
end

end

function [name, data, comment] = convertData(name, data)
%CONVERTDATA In order to future proof the .txt file, utilize the same ideal
% as for reading SBE37 data. This function is just a big switch statement which takes
% column header as input, and attempts to convert it to IMOS compliant name and
% unit of measurement. Returns empty string/vector if the parameter is not
% supported.

    switch name

        %'Battery Voltage'
        case {'BatteryVoltage'};
            name = 'VOLT';
            comment = 'Battery Voltage';

         %'Absolute Current Speed'
        case {'AbsSpeed'};
            name = 'CSPD';
            data = data / 100; % current in cm/s
            comment = '';

         %'Direction'
        case {'Direction'};
            name = 'CDIR_MAG';
            comment = '';

         %'North'
        case {'North'};
            name = 'VCUR_MAG';
            data = data / 100; % current in cm/s
            comment = '';

         %'East'
        case {'East'};
            name = 'UCUR_MAG';
            data = data / 100; % current in cm/s
            comment = '';

         %'Heading'
        case {'Heading'};
            name = 'HEADING_MAG';
            comment = '';

         %'Tilt X'
        case {'TiltX'};
            name = 'ROLL';
            comment = '';

         %'Tilt Y'
        case {'TiltY'};
            name = 'PITCH';
            comment = '';

         %'Single-Ping Standard deviation'
        case {'SPStd'};
            name = 'CSPD_STD';
            data = data / 100; % current in cm/s
            comment = '';

         %'Signal Strength'
        case {'Strength'};
            name = 'ABSI';
            comment = '';

       otherwise
            name = '';
            data = [];
            comment = '';
    end
end

