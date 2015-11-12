function sample_data = readWetStarraw( filename, deviceInfo )
%READWETSARRAW parses a .raw data file retrieved from a Wetlabs WetStar instrument
%deployed at the Lucinda Jetty.
%
%
% Inputs:
%   filename    - name of the input file to be parsed
%   deviceInfo  - infos retrieved from the relevant device file
%
% Outputs:
%   sample_data - contains a time vector (in matlab numeric format), and a 
%                 vector of variable structs, containing sample data.
%
% Author:       Guillaume Galibert <guillaume.galibert@utas.edu.au>
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

% ensure that there is exactly one argument
narginchk(2, 2);
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
  
[name, comment, data] = getParamDetails(deviceInfo.columns{1}, samples{1});

if ~isempty(data)
    % dimensions definition must stay in this order : T, Z, Y, X, others;
    % to be CF compliant
    sample_data.variables{end+1}.dimensions  = 1;
    sample_data.variables{end}.name          = name;
    sample_data.variables{end}.typeCastFunc  = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{end}.name, 'type')));
    sample_data.variables{end}.data          = sample_data.variables{end}.typeCastFunc(data);
    sample_data.variables{end}.coordinates   = 'TIME LATITUDE LONGITUDE NOMINAL_DEPTH';
    sample_data.variables{end}.comment       = comment;
    
    % WQM uses SeaBird pressure sensor
    if strncmp('PRES_REL', name, 8)
        % let's document the constant pressure atmosphere offset previously
        % applied by SeaBird software on the absolute presure measurement
        sample_data.variables{end}.applied_offset = sample_data.variables{end}.typeCastFunc(-14.7*0.689476);
    end
end
  
end

function [name, comment, data] = getParamDetails(columnsInfo, sample)
name = '';
comment = '';
data = [];

switch upper(columnsInfo.type)
    case 'N/U'
        % ignored
        
    case 'IENGR'
        % not identified by IMOS, won't be output in NetCDF
        name = ['ECO3_' columnsInfo.type];
        data = sample;
        
    case 'PAR'
        % not sure about what to do with this measurement from this
        % instrument so for the time being won't be output in NetCDF
        name = ['ECO3_' columnsInfo.type];
        data = sample;
        if isfield(columnsInfo, 'offset')
            data = data - columnsInfo.offset;
        end
        if isfield(columnsInfo, 'scale')
            data = data * columnsInfo.scale;
        end
        
    case 'CHL' %ug/l (470/695nm)
        name = 'CPHL';
        comment = ['Artificial chlorophyll data computed from bio-optical ' ...
            'sensor raw counts measurements. Originally expressed in ' ...
            'ug/l, 1l = 0.001m3 was assumed.'];
        data = sample;
        data = (data - columnsInfo.offset)*columnsInfo.scale;
        
    case 'PHYCOERYTHRIN' %ug/l (540/570nm)
        % not identified by IMOS, won't be output in NetCDF
        name = ['ECO3_' columnsInfo.type];
        data = sample;
        data = (data - columnsInfo.offset)*columnsInfo.scale;
        
    case 'PHYCOCYANIN' %ug/l (630/680nm)
        % not identified by IMOS, won't be output in NetCDF
        name = ['ECO3_' columnsInfo.type];
        data = sample;
        data = (data - columnsInfo.offset)*columnsInfo.scale;
        
    case 'URANINE' %ppb (470/530nm)
        % not identified by IMOS, won't be output in NetCDF
        name = ['ECO3_' columnsInfo.type];
        data = sample;
        data = (data - columnsInfo.offset)*columnsInfo.scale;
        
    case 'RHODAMINE' %ug/l (540/570nm)
        % not identified by IMOS, won't be output in NetCDF
        name = ['ECO3_' columnsInfo.type];
        data = sample;
        data = (data - columnsInfo.offset)*columnsInfo.scale;
        
    case 'CDOM' %ppb
        name = 'CDOM';
        data = sample;
        data = (data - columnsInfo.offset)*columnsInfo.scale;
        
    case 'NTU'
        name = 'TURB';
        data = sample;
        data = (data - columnsInfo.offset)*columnsInfo.scale;
        
    case 'LAMBDA' %m-1 sr-1
        name = ['VSF' num2str(columnsInfo.measWaveLength)];
        data = sample;
        data = (data - columnsInfo.offset)*columnsInfo.scale;
        
    otherwise
        % not identified by IMOS, won't be output in NetCDF
        name = ['ECO3_' columnsInfo.type];
        data = sample;
        if isfield(columnsInfo, 'offset')
            data = data - columnsInfo.offset;
        end
        if isfield(columnsInfo, 'scale')
            data = data * columnsInfo.scale;
        end

end
end
