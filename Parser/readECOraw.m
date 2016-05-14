function sample_data = readECOraw( filename, deviceInfo, mode )
%READECORAW parses a .raw data file retrieved from a Wetlabs ECO Triplet or PARSB instrument.
%
%
% Inputs:
%   filename    - name of the input file to be parsed
%   deviceInfo  - infos retrieved from the relevant device file
%   mode        - Toolbox data type mode ('profile' or 'timeSeries').
%
% Outputs:
%   sample_data - contains a time vector (in matlab numeric format), and a 
%                 vector of variable structs, containing sample data.
%
% Author:       Guillaume Galibert <guillaume.galibert@utas.edu.au>
%
% See http://www.wetlabs.com/products/eflcombo/triplet.htm
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

% ensure that there are exactly three arguments
narginchk(3, 3);
if ~ischar(filename), error('filename must contain a string'); end
if ~isstruct(deviceInfo), error('deviceInfo must contain a struct'); end

nColumns = length(deviceInfo.columns);
% we assume the two first columns are always DATE and TIME
% we first read everything as strings with the expected number of columns
% but ignoring as many columns as it takes (100 extra columns should be
% enough)
format = ['%s%s' repmat('%s', 1, nColumns-2) repmat('%*s', [1, 100])];

% open file, get header and data in columns
fid     = -1;
try
    fid = fopen(filename, 'rt');
    if fid == -1, error(['couldn''t open ' filename 'for reading']); end
    
    % read in the data
    samples = textscan(fid, format, 'HeaderLines', 1, 'Delimiter', '\t');
    fclose(fid);
catch e
    if fid ~= -1, fclose(fid); end
    rethrow(e);
end

% we read everything a second time only looking for a potential extra column as a diagnostic for errors
formatDiag = ['%*s%*s' repmat('%*s', 1, nColumns-2) '%s' repmat('%*s', [1, 100])];

% open file, get header and data in columns
fid     = -1;
try
    fid = fopen(filename, 'rt');
    if fid == -1, error(['couldn''t open ' filename 'for reading']); end
    
    % read in the data
    samplesDiag = textscan(fid, formatDiag, 'HeaderLines', 1, 'Delimiter', '\t');
    fclose(fid);
catch e
    if fid ~= -1, fclose(fid); end
    rethrow(e);
end

% get rid of any line which non expected extra column contains data
iExtraColumn = ~strcmpi(samplesDiag{1}, '');
if any(iExtraColumn)
    for i=1:nColumns
        samples{i}(iExtraColumn) = [];
    end
end
clear samplesDiag;

% get rid of any line which expected last column doesn't contain data
iNoLastColumn = strcmpi(samples{nColumns}, '');
if any(iNoLastColumn)
    for i=1:nColumns
        samples{i}(iNoLastColumn) = [];
    end
end

% get rid of any line which date is not in the format mm/dd/yy
control = regexp(samples{1}, '^[0-1]\d/[0-3]\d/\d\d', 'match');
iDateNoGood1 = cellfun('isempty', control);
if any(iDateNoGood1)
    for i=1:nColumns
        samples{i}(iDateNoGood1) = [];
    end
end
clear control iDateNoGood1;

[~, M, D] = datevec(samples{1}, 'mm/dd/yy');
iMonthNoGood = (M <= 0) & (M > 12);
iDayNoGood = (D <= 0) & (D > 31);
iDateNoGood2 = iMonthNoGood | iDayNoGood;
clear iMonthNoGood iDayNoGood;
if any(iDateNoGood2)
    for i=1:nColumns
        samples{i}(iDateNoGood2) = [];
    end
end
clear iDateNoGood2;

control = cellstr(datestr(datenum(samples{1}, 'mm/dd/yy'), 'mm/dd/yy'));
iDateNoGood3 = ~strcmpi(samples{1}, control);
if any(iDateNoGood3)
    for i=1:nColumns
        samples{i}(iDateNoGood3) = [];
    end
end
clear iDateNoGood3;

% get rid of any line which time is not in the format HH:MM:SS
control = regexp(strtrim(samples{2}), '^[0-2]\d:[0-6]\d:[0-6]\d', 'match');
iTimeNoGood1 = cellfun('isempty', control);
if any(iTimeNoGood1)
    for i=1:nColumns
        samples{i}(iTimeNoGood1) = [];
    end
end
clear control iTimeNoGood1;

[~, ~, ~, H, MN, S] = datevec(samples{2}, 'HH:MM:SS');
iHourNoGood = (H < 0) & (H > 24);
iMinuteNoGood = (MN < 0) & (MN > 60);
iSecondNoGood = (S < 0) & (S > 60);
iTimeNoGood2 = iHourNoGood | iMinuteNoGood | iSecondNoGood;
clear iHourNoGood iMinuteNoGood iSecondNoGood;
if any(iTimeNoGood2)
    for i=1:nColumns
        samples{i}(iTimeNoGood2) = [];
    end
end
clear iTimeNoGood2;

% get rid of any line which column other than date or time is not a number
% (we are being highly conservative)
iNaN = false(length(samples{1}), nColumns-2);
for i=3:nColumns
    iNaN(:, i-2) = isnan(str2double(samples{i}));
end
iNaN = any(iNaN, 2);
if any(iNaN)
    for i=1:nColumns
        samples{i}(iNaN) = [];
    end
end
clear iNaN;

% finally we can convert into numbers what is left
for i=3:nColumns
    samples{i} = str2double(samples{i});
end

%fill in sample and cal data
sample_data            = struct;
sample_data.meta       = struct;
sample_data.dimensions = {};
sample_data.variables  = {};

sample_data.toolbox_input_file        = filename;
sample_data.meta.instrument_make      = 'WET Labs';
sample_data.meta.instrument_model     = deviceInfo.instrument;
sample_data.meta.instrument_serial_no = deviceInfo.serial;
sample_data.meta.featureType          = mode;

% convert and save the time data
time = datenum(samples{1}, 'mm/dd/yy') + ...
    (datenum(samples{2}, 'HH:MM:SS') - datenum(datestr(now, 'yyyy0101'), 'yyyymmdd'));

sample_data.meta.instrument_sample_interval = median(diff(time*24*3600));

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

for i=3:nColumns
    [name, comment, data, calibration] = convertECOrawVar(deviceInfo.columns{i}, samples{i});
    
    if ~isempty(data)
        % dimensions definition must stay in this order : T, Z, Y, X, others;
        % to be CF compliant
        sample_data.variables{end+1}.dimensions  = 1;
        sample_data.variables{end}.name          = name;
        sample_data.variables{end}.typeCastFunc  = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{end}.name, 'type')));
        sample_data.variables{end}.data          = sample_data.variables{end}.typeCastFunc(data);
        sample_data.variables{end}.coordinates   = 'TIME LATITUDE LONGITUDE NOMINAL_DEPTH';
        sample_data.variables{end}.comment       = comment;
        
        if ~isempty(calibration)
            fields = fieldnames(calibration);
            for j=1:length(fields)
                attribute = ['calibration_' fields{j}];
                sample_data.variables{end}.(attribute) = calibration.(fields{j});
            end
        end
        
        % WQM uses SeaBird pressure sensor
        if strncmp('PRES_REL', name, 8)
            % let's document the constant pressure atmosphere offset previously
            % applied by SeaBird software on the absolute presure measurement
            sample_data.variables{end}.applied_offset = sample_data.variables{end}.typeCastFunc(-14.7*0.689476);
        end
    end
end
end