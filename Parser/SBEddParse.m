function sample_data = SBEddParse( fn, mode )
%SBEddParse Parse a raw '.asc' file containing SBE37/SBE39 data.
%
% This function can read in data that has been downloaded from an SBE37
% 'Microcat' CTP sensor or an SBE39 temperature/pressure sensor
%
% Outputs:
%   sample_data - contains a time vector (in matlab numeric format)
%
% Author: 		Peter Jansen
%

%
% Copyright (c) 2017, Australian Ocean Data Network (AODN) and Integrated 
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

% Check input, set up data structures
narginchk(1, 2);

if iscellstr(fn)
    filename = fn{1};
else
    filename = fn;
end

if ~exist(filename, 'file')
    e = sprintf('File not found : %s\n', filename);
    error(e);
end

% save file size and open file; this will throw an error if file doesn't exist
filedir = dir(filename);
filesize = filedir.bytes;
fid = fopen(filename, 'rt');

% Values used for metadata fields (IMOS compliant)
TEMPERATURE_NAME  = 'TEMP';
CONDUCTIVITY_NAME = 'CNDC';
PRESSURE_NAME     = 'PRES_REL'; % relative pressure (absolute -14.7*0.689476 dbar)
SALINITY_NAME     = 'PSAL';
OXYGEN_NAME       = 'DOX';
TIME_NAME         = 'TIME';

varOrder{1} = {TEMPERATURE_NAME};
varOrder{2} = {TEMPERATURE_NAME, CONDUCTIVITY_NAME};
% varOrder{2} = {TEMPERATURE_NAME, PRESSURE_NAME}; % SBE39 data
varOrder{3} = {TEMPERATURE_NAME, CONDUCTIVITY_NAME, PRESSURE_NAME};
varOrder{4} = {TEMPERATURE_NAME, CONDUCTIVITY_NAME, PRESSURE_NAME, SALINITY_NAME};
varOrder{5} = {TEMPERATURE_NAME, CONDUCTIVITY_NAME, PRESSURE_NAME, OXYGEN_NAME, SALINITY_NAME};
varOrder{10} = {TEMPERATURE_NAME, CONDUCTIVITY_NAME, PRESSURE_NAME, 'VOLT1', 'VOLT2', 'VOLT3', 'VOLT4', 'VOLT5', 'VOLT6', SALINITY_NAME};

%
% regular expressions used for parsing metadata
%

dataline_expr    = '^( *(\-?[\d\.]+),)+.*(\d{2} \S{3} \d{4})(,? +)(\d{2}:\d{2}:\d{2})';

header_expr       = '(SBE ?\S+)\s+[vV].?(\S+)\s+SERIAL NO.\s+(\S+)';
nSamples_expr     = 'samplenumber = (\d+)';
sample_int_expr   = 'sample interval = (\d+)';

newHeaderExpr   = '<HardwareData DeviceType=''(\S+)'' SerialNumber=''(\S+)''>';
firmExpr        = '<FirmwareVersion>(\S+)</FirmwareVersion>';

salinity1_expr  = 'output salinity = yes';
salinity2_expr  = 'output salinity';
salinity3_expr  = 'output salinity with each sample';
salinity4_expr  = 'do not output salinity with each sample';

sound_vel1_expr = 'output sound velocity = no';
sount_vel2_expr = 'output sound velocity with each sample'
sount_vel3_expr = 'do not output sound velocity with each sample'

sample_interval = -1;

% output struct
sample_data            = struct;
sample_data.meta       = struct;
sample_data.variables  = {};
sample_data.dimensions = {};

% sample data and names, gleaned from the file
samples                = [];
varNames               = {};
    
sample_data.toolbox_input_file          = filename;

% The instrument_model field will be overwritten from the file header
sample_data.meta.instrument_make        = 'Sea-bird Electronics';
sample_data.meta.instrument_model       = 'SBExx';
sample_data.meta.instrument_serial_no   = '';
sample_data.meta.featureType            = mode;

header = true; % start out looking for header
commaSepDate = false; % some data downloads (SBE16) dont have a comma in the date time

lineno = 1;
datalineno = 0;
nSamples = 0;
nDataValues = 0;

% Read file 

line = fgetl(fid);
while (~feof(fid))
    
    % parse the header
    if header
        % check for old model/serial number/firmware version
        tkn = regexp(line, header_expr, 'tokens');
        if ~isempty(tkn) 
            sample_data.meta.instrument_model     = tkn{1}{1};
            sample_data.meta.instrument_firmware  = tkn{1}{2};
            sample_data.meta.instrument_serial_no = tkn{1}{3};
        end
        % check for XML type model/serial number
        tkn = regexp(line, newHeaderExpr, 'tokens');
        if ~isempty(tkn) 
            sample_data.meta.instrument_model     = tkn{1}{1};
            sample_data.meta.instrument_serial_no = tkn{1}{3};
        end
        % check for number of samples
        tkn = regexp(line, nSamples_expr, 'tokens');
        if ~isempty(tkn) 
            nS = textscan(tkn{1}{1}, '%f');
            nSamples = nS{1};
            fprintf('number of samples %d\n', nSamples);
        end
        % check for sample interval
        tkn = regexp(line, sample_int_expr, 'tokens');
        if ~isempty(tkn) 
            nS = textscan(tkn{1}{1}, '%f');
            sample_interval = nS{1};
            fprintf('sample interval %d\n', sample_interval);
        end
        % does the line parse as a data line, if so go to data line parsing
        tkn = regexp(line, dataline_expr, 'tokens');
        if ~isempty(tkn) 
            header = false;   
            comma = strfind(line, ',');
            % do we have a , separating the date and time of the data string
            if isempty(strfind(tkn{1}{end-1},','))
                commaSepDate = true;
                nDataValues = size(comma,2);
            else
                nDataValues = size(comma,2)-1;                
            end
            % create a list of varNames from the possiable configurations
            % based on number of data variables
            for i=1:nDataValues
                varNames{end+1} = varOrder{nDataValues}{i};
            end
            % allocate space for all samples in sample array, will be
            % trimed to number of samples read later
            if (nDataValues > 0) && (nSamples > 0)
                % create a sample array to store data
                samples = zeros(nSamples, nDataValues);
                time = zeros(nSamples, 1);
            end
        end
    end
    
    if ~header
        % read datalines
        comma = strfind(line, ',');
        datalineno = datalineno + 1;
        if (commaSepDate)
            time(datalineno) = datenum(line(comma(end)+1:end),'dd mmm yyyy HH:MM:SS');
        else
            time(datalineno) = datenum(line(comma(end-1)+1:end),'dd mmm yyyy, HH:MM:SS');
        end
        % read data line, using a , as separator
        samples(datalineno,:) = cell2mat(textscan(line, '%f', nDataValues, 'Delimiter', ','));
        
    end
    line = fgetl(fid);
    lineno = lineno + 1;
end

fprintf('samples read %d\n', datalineno);

% trim sample data to number of lines read
time = time(1:(datalineno));
samples = samples(1:(datalineno),:);

% set the sample interval if we did not read it from the header
if (sample_interval < 0)
    sample_data.meta.instrument_sample_interval = median(diff(time*24*3600));
else
    sample_data.meta.instrument_sample_interval = sample_interval;
end

% copy the data into the sample_data struct
sample_data.dimensions{1}.name          = TIME_NAME;
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

for k = 1:length(varNames)
  % dimensions definition must stay in this order : T, Z, Y, X, others;
  % to be CF compliant
  sample_data.variables{end+1}.dimensions = 1;
  sample_data.variables{end}.name         = varNames{k};
  sample_data.variables{end}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(varNames{k}, 'type')));
  sample_data.variables{end}.coordinates  = 'TIME LATITUDE LONGITUDE NOMINAL_DEPTH';
  
  sample_data.variables{end}.data = sample_data.variables{end}.typeCastFunc(samples(:,k));
  
  if (strcmp(varNames{k}, PRESSURE_NAME))
        % let's document the constant pressure atmosphere offset previously
        % applied by SeaBird software on the absolute presure measurement
        sample_data.variables{end}.applied_offset = sample_data.variables{end}.typeCastFunc(-14.7*0.689476);
  end
end
