function sample_data = readWetStarraw( filename, deviceInfo, mode )
%READWETSARRAW parses a .raw data file retrieved from a Wetlabs WetStar instrument
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

nColumns = 1;
% we assume the file is a single column
format = '%s';

% open file, get header and data in columns
fid     = -1;
samples = {};
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
samples{1} = str2double(samples{1});

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
% assuming recording is performed over 60 minutes
[~, filename, ~] = fileparts(filename);
underscorePos = strfind(filename, '_');
time = filename(1:underscorePos(1)+4);
time = time(end-12:end);
time = datenum(time, 'yyyymmdd_HHMM');
nSamples = length(samples{1});
time = linspace(time, time + 1/24, nSamples);

sample_data.meta.instrument_sample_interval = 1;

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
  
[name, comment, data, calibration] = convertECOrawVar(deviceInfo.columns{1}, samples{1});

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