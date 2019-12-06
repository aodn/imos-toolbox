function sample_data = SBE3x( filename, mode )
%SBE37PARSE Parse a raw '.asc' file containing SBE37/SBE39 data.
%
% This function can read in data that has been downloaded from an SBE37
% 'Microcat' CTP sensor or an SBE39 temperature/pressure sensor
%
% The following variants of the SBE37 exist:
%   - SBE37-IM
%   - SBE37-IMP
%   - SBE37-SM  (RS232)
%   - SBE37-SM  (RS485)
%   - SBE37-SMP (RS232)
%   - SBE37-SMP (RS485)
%   - SBE37-SI  (RS232)
%   - SBE37-SI  (RS485)
%   - SBE37-SIP (RS232)
%   - SBE37-SIP (RS485)
%
% The following variants of the SBE39 exist:
%   - SBE39
%   - SBE39-IM
% 
% The SBE output format is configurable, and there are slight differences in 
% output formats between variants. Additionally, instruments which run an
% older firmware version use different commands for configuring the output 
% format and downloading data. This function will only parse sample data
% which is in the following format:
%
%   temperature[, conductivity][, pressure][, salinity], date, time
%
% where
%
%   temperature:  floating point, Degrees Celsius ITS-90
%   conductivity: floating point, S/m (only on SBE37)
%   pressure:     floating point, decibars, optional (present on instruments
%                 with optional pressure sensor)
%   salinity:     floating point, PSU, optional (may be present on SBE37
%                 instruments with firmware >= 3.0)
%   date:         dd mmm yyyy (e.g. 01 Jan 2008)
%   time:         hh:mm:ss    (e.g. 15:45:03)
%
% All SBE37 variants can be configured to output this format. SBE39 variants 
% provide data in this format only. On SBE37 instruments running firmware < 
% 3.0, the sensor should be configured as follows:
%
%   Format=1
%
% For instruments running firmware >= 3.0:
%
%   OutputFormat=1
%   OutputDepth=N   (if sensor supports this command)
%   OutputSal=N     (if sensor supports this command - Y if you want salinity)
%   OutputSV=N
%   OutputDensity=N (if sensor supports this command)
%   OutputTime=Y    (if sensor supports this command)
%
% The input file must also contain a header section which contains sensor 
% metadata and calibration information (as obtained via the 'DS' and 'DC' 
% commands) - this is the output format provided by the Windows seaterm 
% program.
%
% Inputs:
%   filename    - name of the input file to be parsed
%   mode        - Toolbox data type mode.
%
% Outputs:
%   sample_data - contains a time vector (in matlab numeric format), and a 
%                 vector of up to four variable structs, containing sample 
%                 data. The variables are as follows:
%
%                   Temperature  ('TEMP'): Degrees Celsius ITS-90 (always 
%                                          present)
%
%                   Conductivity ('CNDC'): Siemens/metre (only on SBE37)
%
%                   Pressure     ('PRES_REL'): decibars (only if optional 
%                                          pressure sensor is present) -14.7*0.689476
%
%                   Salinity     ('PSAL'): PSU (only on SBE37 sensors which
%                                          support the 'OutputSal' command)
%
%                 Also contains instrument metadata and calibration 
%                 coefficients, if this data is present in the input file 
%                 header.
%
%
% Author: 		Paul McCarthy <paul.mccarthy@csiro.au>
% Contributor:	Guillaume Galibert <guillaume.galibert>
%
% See http://www.seabird.com/products/ModelList.htm for a list of SBE variants 
% and manuals for each.
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

%% Check input, set up data structures
narginchk(1, 2);

% save file size and open file; this will throw an error if file doesn't exist
filesize = dir(filename);
filesize = filesize.bytes;
fid = fopen(filename, 'rt');

% Values used for metadata fields (IMOS compliant)
TEMPERATURE_NAME  = 'TEMP';
CONDUCTIVITY_NAME = 'CNDC';
PRESSURE_NAME     = 'PRES_REL'; % relative pressure (absolute -14.7*0.689476 dbar)
SALINITY_NAME     = 'PSAL';
TIME_NAME         = 'TIME';

%
% regular expressions used for parsing metadata
%
header_expr       = '^[\*]\s*(SBE\S+)\s+V\s+(\S+)\s+(\d+)$';
cal_coeff_expr    = '^[\*]\s*(\w+)\s*=\s*(\S+)\s*$';
sensor_cal_expr   = '^[\*]\s*(\w+):\s*(.+)\s*$';
salinity_expr     = '^[\*] output salinity.*$';
pressure_cal_expr = ['^[\*]\s*pressure\s+S/N\s+(\d+)'... % serial number
                     ',\s*range\s*=\s*(\d+)'         ... % pressure range
                     '\s+psia:?\s*(.+)\s*$'];            % cal date including Seaterm v2 variation format

%
% textscan is used for parsing sample data - much quicker than regex. 
% We start with tokens for date/time; tokens for the sample values 
% are added as we parse the calibration data, and figure out which 
% sensors are present on the instrument (thus how many fields we need
% to parse).
%
sample_expr = '%21c';

sample_data            = struct;
sample_data.meta       = struct;
sample_data.variables  = {};
sample_data.dimensions = {};
varNames               = {};
temperature            = [];
conductivity           = [];
pressure               = [];
salinity               = [];

% booleans used to determine whether to expect 
% the corresponding variable in the data
read_temp = 0;
read_sal  = 0;
read_cond = 0;
read_pres = 0;
    
sample_data.toolbox_input_file          = filename;

% The instrument_model field will be overwritten 
% as the calibration data is read in
sample_data.meta.instrument_make        = 'Sea-bird Electronics';
sample_data.meta.instrument_model       = 'SBE3x';
sample_data.meta.instrument_serial_no   = '';
sample_data.meta.featureType            = mode;

%% Read file header (which contains sensor and calibration information)
%
% The header section contains four different line formats that we want to 
% capture. The first format contains the sensor type, firmware version and 
% serial number. It is of the format:
%
%   "SBE[variant] V [firmware_version] [serial_number]"
%
% The second type of line is a name-value pair of a particular sensor type.
% These lines have the format:
%
%   sensor: info
%
% The temperature (and optional conductivity) sensor (and rtc) information is 
% just a calibration date. The (optional) pressure sensor also contains a 
% serial number and pressure range.
%
% The third type of line is an indication of whether salinity is output in
% the data. It is literally:
%
%   * output salinity with each sample
%
% as opposed to:
%   * do not output salinity with each sample
%
%
% The fourth type of line is a name-value pair of a particular calibration
% coefficient. These lines have the format:
%
%   name = value
%
line = fgetl(fid);
while (isempty(line) || line(1) == '*' || line(1) == 's') && ischar(line)
  
  if isempty(line) || line(1) == 's'
    line = fgetl(fid);
    continue;
  end
    
  %
  % try for calibration coefficient line first
  %
  tkn = regexp(line, cal_coeff_expr, 'tokens');
  if ~isempty(tkn)
    
    % save the calibration coefficient 
    sample_data.meta.(tkn{1}{1}) = str2double(tkn{1}{2});
    
    line = fgetl(fid);
    continue;
  end
  
  %
  % not calibration coefficient line - does this line have sensor info?
  %
  tkn = regexp(line, sensor_cal_expr, 'tokens');
  if ~isempty(tkn)
    
    sample_data.meta.([tkn{1}{1} '_calibration_date']) = strtrim(tkn{1}{2});
     
    if strcmp('temperature', tkn{1}{1})
      
      read_temp = 1;
      sample_expr = ['%f' sample_expr];
      varNames{end+1} = TEMPERATURE_NAME;
      
    elseif strcmp('conductivity', tkn{1}{1})
      
      read_cond = 1;
      sample_expr = ['%f' sample_expr];
      varNames{end+1} = CONDUCTIVITY_NAME;
      
    end
    
    line = fgetl(fid);
    continue;
  end
  
  %
  % not sensor info - try pressure sensor info
  %
  tkn = regexp(line, pressure_cal_expr, 'tokens');
  if ~isempty(tkn)
    
    read_pres = 1;
    sample_expr = ['%f' sample_expr];
    varNames{end+1} = PRESSURE_NAME;
    
    sample_data.meta.pressure_serial_no        = strtrim(tkn{1}{1});
    sample_data.meta.pressure_range_psia       = str2double(tkn{1}{2});
    sample_data.meta.pressure_calibration_date = strtrim(tkn{1}{3});
    line = fgetl(fid);
    
    continue;
  end
  
  %
  % ok, try instrument info
  %
  tkn = regexp(line, header_expr, 'tokens');
  if ~isempty(tkn)

    sample_data.meta.instrument_model     = tkn{1}{1};
    sample_data.meta.instrument_firmware  = tkn{1}{2};
    sample_data.meta.instrument_serial_no = tkn{1}{3};

  end
  
  %
  % finally, try salinity info
  %
  tkn = regexp(line, salinity_expr, 'tokens');
  if ~isempty(tkn)
    
    read_sal = 1;
    sample_expr = ['%f' sample_expr];
    varNames{end+1} = SALINITY_NAME;
    
  end

  line = fgetl(fid);
end

%
% the FileName line is picked up by the cal_expr expression, 
% as it has the form name = value. manually remove it
%
if isfield(sample_data, 'FileName')
 sample_data = rmfield(sample_data, 'FileName');
end

% we read one too many lines in the calibration 
% parsing, so we need to backtrack
fseek(fid, -length(line) - 1, 'cof');

%% Read sample data
if read_temp == 0 && read_cond == 0 && read_pres == 0 && read_sal == 0
    % (file format without any header)
    % We assume the first line has the correct number of columns
    nCol = length(strfind(line, ',')) + 1;
    switch nCol
        case 3
            read_temp = 1;
            sample_expr = '%f%21c';
            varNames{end+1} = TEMPERATURE_NAME;
            
        case 4
            read_temp = 1;
            read_cond = 1;
            sample_expr = '%f%f%21c';
            varNames{end+1} = TEMPERATURE_NAME;
            varNames{end+1} = CONDUCTIVITY_NAME;
            
        case 5
            read_temp = 1;
            read_cond = 1;
            read_pres = 1;
            sample_expr = '%f%f%f%21c';
            varNames{end+1} = TEMPERATURE_NAME;
            varNames{end+1} = CONDUCTIVITY_NAME;
            varNames{end+1} = PRESSURE_NAME;
            
        case 6
            read_temp = 1;
            read_cond = 1;
            read_pres = 1;
            read_sal = 1;
            sample_expr = '%f%f%f%f%21c';
            varNames{end+1} = TEMPERATURE_NAME;
            varNames{end+1} = CONDUCTIVITY_NAME;
            varNames{end+1} = PRESSURE_NAME;
            varNames{end+1} = SALINITY_NAME;
            
        otherwise
            error('Not supported file format.');
            
    end
    
    samples = textscan(fid, sample_expr, 'delimiter', ',');
    
    time = datenum(samples{end},'dd mmm yyyy, HH:MM:SS');
    
    if read_temp, temperature = samples{1}; end
    if read_cond, conductivity = samples{2}; end
    if read_pres, pressure = samples{3}; end
    if read_sal, salinity = samples{4}; end
    
else
    % (original file format with header)
    % This is a bit complex, as errors are sometimes present in the SBE output, so
    % we can't do it with a single textscan call.
    %
    % The arrays in sample_data are preallocated to improve execution speed.
    % The preallocation size is determined by approximating the number of lines in
    % the file based on the file size, and an approximate line size of 30
    % characters. This is a slightly optimistic estimate, so memory usage is not
    % optimal, however excess memory is freed after the data has been parsed.
    %
    nsamples = int32(filesize / 30);
    
    % others are allocated below as needed
    time        = zeros(nsamples,1);
    temperature = zeros(nsamples,1);
    
    if read_pres, pressure     = zeros(nsamples,1); end
    if read_cond, conductivity = zeros(nsamples,1); end
    if read_sal,  salinity     = zeros(nsamples,1); end
    
    % the nsamples index points to the next
    % free space in the variable arrays
    nsamples = 1;
    
    while ~feof(fid)
        
        % temperature[, conductivity][, pressure][, salinity], date, time
        samples = textscan(fid, sample_expr, 'delimiter', ',');
        
        % current line doesn't match expected format or doesn't have time stamp
        if isempty(samples{end}) || isempty(samples{end-1})
            fgetl(fid); % we move to the next line to re-start textscan from there
            continue;
        end
        
        block = 1;
        
        temp_block = samples{block}; block = block+1;
        
        if read_cond, cond_block = samples{block}; block = block+1; end
        if read_pres, pres_block = samples{block}; block = block+1; end
        if read_sal,  sal_block  = samples{block}; block = block+1; end
        
        time_block = cellstr(samples{block});
        
        % error on most recent line - discard it and continue
        if ~feof(fid)
            time_block = time_block(1:end-1);
            temp_block = temp_block(1:length(time_block));
            
            if read_cond, cond_block = cond_block(1:length(time_block)); end
            if read_pres, pres_block = pres_block(1:length(time_block)); end
            if read_sal,  sal_block  = sal_block( 1:length(time_block)); end
            fgetl(fid);
        end
        
        time_block = datenum(time_block, 'dd mmm yyyy, HH:MM:SS');
        
        temperature(   nsamples:nsamples+length(temp_block)-1) = temp_block;
        
        if read_cond
            conductivity(nsamples:nsamples+length(cond_block)-1) = cond_block; end
        if read_pres
            pressure(    nsamples:nsamples+length(pres_block)-1) = pres_block; end
        if read_sal
            salinity(    nsamples:nsamples+length(sal_block) -1) = sal_block;  end
        
        time(          nsamples:nsamples+length(time_block)-1) = time_block;
        
        nsamples = nsamples + length(time_block);
    end
    fclose(fid);
    
    % we overallocated memory for the sample data - truncate
    % each array so we're only using the memory that we need
    time(nsamples:end) = [];
    if ~isempty(temperature),  temperature( nsamples:end) = []; end
    if ~isempty(conductivity), conductivity(nsamples:end) = []; end
    if ~isempty(pressure),     pressure(    nsamples:end) = []; end
    if ~isempty(salinity),     salinity(    nsamples:end) = []; end
end

sample_data.meta.instrument_sample_interval = median(diff(time*24*3600));

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
  
  switch varNames{k}
    case TEMPERATURE_NAME,  sample_data.variables{end}.data = sample_data.variables{end}.typeCastFunc(temperature);
    case CONDUCTIVITY_NAME, sample_data.variables{end}.data = sample_data.variables{end}.typeCastFunc(conductivity);
    case PRESSURE_NAME
        sample_data.variables{end}.data = sample_data.variables{end}.typeCastFunc(pressure);
        % let's document the constant pressure atmosphere offset previously
        % applied by SeaBird software on the absolute presure measurement
        sample_data.variables{end}.applied_offset = sample_data.variables{end}.typeCastFunc(-14.7*0.689476);
    case SALINITY_NAME,     sample_data.variables{end}.data = sample_data.variables{end}.typeCastFunc(salinity);
  end
end
