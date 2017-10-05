function sample_data = readBB9raw( filename, deviceInfo, mode )
%READBB9RAW parses a .raw data file retrieved from a Wetlabs ECO BB9 instrument
%deployed at the Lucinda Jetty.
%
%
% Inputs:
%   filename    - name of the input file to be parsed
%   deviceInfo  - infos retrieved from the relevant device file
%   mode        - Toolbox data type mode.
%
% Outputs:
%   sample_data - contains a time vector (in matlab numeric format), and a 
%                 vector of variable structs, containing sample data.
%
% Author:       Guillaume Galibert <guillaume.galibert@utas.edu.au>
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

% ensure that there are exactly three arguments
narginchk(3, 3);
if ~ischar(filename), error('filename must contain a string'); end
if ~isstruct(deviceInfo), error('deviceInfo must contain a struct'); end

nColumns = length(deviceInfo.columns);
% we assume the first column is a string while all the next are numbers.
format = ['%s' repmat('%s', [1, nColumns-1])];

% open file, get header and data in columns
fid     = -1;
try
    fid = fopen(filename, 'rt');
    if fid == -1, error(['couldn''t open ' filename 'for reading']); end
    
    % read in the data
    samples = textscan(fid, format, 'Delimiter', '\t');
    fclose(fid);
catch e
    if fid ~= -1, fclose(fid); end
    rethrow(e);
end

% we can convert into numbers, any input with characters will end up as
% NaN
for i=2:nColumns
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

% infer time information from start time in filename (already in UTC) and 
% assuming sampling rate is 1Hz
[~, filename, ~] = fileparts(filename);
underscorePos = strfind(filename, '_');
time = filename(1:underscorePos(1)+4);
time = time(end-12:end);
time = datenum(time, 'yyyymmdd_HHMM');
nSamples = length(samples{1});
time = time + (0:1:nSamples-1)/(24*3600);

sample_data.meta.instrument_sample_interval = 1;

% Let's find each start of bursts if any
dt = [0; diff(time)];
iBurst = [1; find(dt>(sample_data.meta.instrument_sample_interval/24/60)); length(time)+1];
nBurst = length(iBurst)-1;

if nBurst > 1
    % let's read data burst by burst
    firstTimeBurst = zeros(nBurst, 1);
    sampleIntervalInBurst = zeros(nBurst, 1);
    durationBurst = zeros(nBurst, 1);
    for i=1:nBurst
        timeBurst = time(iBurst(i):iBurst(i+1)-1);
        sampleIntervalInBurst(i) = median(diff(timeBurst*24*3600));
        firstTimeBurst(i) = timeBurst(1);
        durationBurst(i) = (timeBurst(end) - timeBurst(1))*24*3600 + sampleIntervalInBurst(i);
    end
    
    sample_data.meta.instrument_sample_interval   = round(median(sampleIntervalInBurst));
    sample_data.meta.instrument_burst_interval    = round(median(diff(firstTimeBurst*24*3600)));
    sample_data.meta.instrument_burst_duration    = round(median(durationBurst));
end

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

for i=2:nColumns
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
            fields = fielnames(calibration);
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