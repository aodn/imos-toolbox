function [sample_data cal_data] = SBE3x( filename )
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
%   temperature[, conductivity][, pressure], date, time
%
% where
%
%   temperature:  floating point, Degrees Celsius ITS-90
%   conductivity: floating point, S/m (only on SBE37)
%   pressure:     floating point, decibars, optional (present on instruments
%                 with optional pressure sensor)
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
%   OutputSal=N
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
%
% Outputs:
%   sample_data - contains a time vector (in matlab numeric format), and a 
%                 vector of up to three parameter structs, containing sample 
%                 data. The parameters are as follows:
%
%                   Temperature  ('TEMP'): Degrees Celsius ITS-90 (always 
%                                          present)
%
%                   Conductivity ('CNDC'): Siemens/metre (only on SBE37)
%
%                   Pressure     ('PRES'): decibars (only if optional 
%                                          pressure sensor is present)
%
%   cal_data    - contains instrument metadata and calibration coefficients, 
%                 if this data is present in the input file header.
%
%
% Author: Paul McCarthy <paul.mccarthy@csiro.au>
%
% See http://www.seabird.com/products/ModelList.htm for a list of SBE variants 
% and manuals for each.
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

%% Check input, set up data structures

% ensure that there is exactly one argument, and that it is a string
error(nargchk(1, 1, nargin));
if ~ischar(filename), error('filename must be a string'); end

% save file size and open file; this will throw an error if file doesn't exist
filesize = dir(filename);
filesize = filesize.bytes;
fid = fopen(filename);

% Values used for metadata fields (IMOS compliant)
TEMPERATURE_NAME  = 'TEMP';
CONDUCTIVITY_NAME = 'CNDC';
PRESSURE_NAME     = 'PRES';

%
% regular expressions used for parsing metadata
%
header_expr       = '^[\*]\s*(SBE\S+)\s+V\s+(\S+)\s+(\d+)$';
cal_coeff_expr    = '^[\*]\s*(\w+)\s*=\s*(\S+)\s*$';
sensor_cal_expr   = '^[\*]\s*(\w+):\s*(.+)\s*$';
pressure_cal_expr = ['^[\*]\s*pressure\s+S/N\s+(\d+)'... % serial number
                     ',\s*range\s*=\s*(\d+)'         ... % pressure range
                     '\s+psia:\s*(.+)\s*$'];             % cal date

%
% textscan is used for parsing sample data - much quicker than regex. 
% We start with tokens for date/time; tokens for the sample values 
% are added as we parse the calibration data, and figure out which 
% sensors are present on the instrument (thus how many fields we need
% to parse).
%
sample_expr = '%21c';

sample_data = struct;
sample_data.parameters = [];
cal_data    = struct;
temperature  = [];
conductivity = [];
pressure     = [];
time         = [];

% The instrument_model field will be overwritten 
% as the calibration data is read in
cal_data.instrument_make  = 'Sea-bird Electronics';
cal_data.instrument_model = 'SBE3x';

%% Read file header (which contains sensor and calibration information)
%
% The header section contains three different line formats that we want to 
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
% The third type of line is a name-value pair of a particular calibration
% coefficient. These lines have the format:
%
%   name = value
%
line = fgetl(fid);
while isempty(line) || line(1) == '*' || line(1) == 's'
  
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
    cal_data.(tkn{1}{1}) = str2double(tkn{1}{2});
    
    line = fgetl(fid);
    continue;
  end
  
  %
  % not calibration coefficient line - does this line have sensor info?
  %
  tkn = regexp(line, sensor_cal_expr, 'tokens');
  if ~isempty(tkn)
    
    cal_data.([tkn{1}{1} '_calibration_date']) = strtrim(tkn{1}{2});
     
    if strcmp('temperature', tkn{1}{1})
      
      sample_expr = ['%f' sample_expr];
      sample_data.parameters(end+1).name = TEMPERATURE_NAME;
      
    elseif strcmp('conductivity', tkn{1}{1})
      
      sample_expr = ['%f' sample_expr];
      sample_data.parameters(end+1).name = CONDUCTIVITY_NAME;
      
    end
    
    line = fgetl(fid);
    continue;
  end
  
  %
  % not sensor info - try pressure sensor info
  %
  tkn = regexp(line, pressure_cal_expr, 'tokens');
  if ~isempty(tkn)
    
    sample_expr = ['%f' sample_expr];
    sample_data.parameters(end+1).name = PRESSURE_NAME;
    
    cal_data.pressure_serial_no        = strtrim(tkn{1}{1});
    cal_data.pressure_range_psia       = str2double(tkn{1}{2});
    cal_data.pressure_calibration_date = strtrim(tkn{1}{3});
    line = fgetl(fid);
    
    continue;
  end
  
  %
  % finally, try sensor info
  %
  tkn = regexp(line, header_expr, 'tokens');
  if ~isempty(tkn)

    cal_data.instrument_model     = tkn{1}{1};
    cal_data.instrument_firmware  = tkn{1}{2};
    cal_data.instrument_serial_no = tkn{1}{3};

  end

  line = fgetl(fid);
end

%
% the FileName line is picked up by the cal_expr expression, 
% as it has the form name = value. manually remove it
%
if isfield(cal_data, 'FileName')
 cal_data = rmfield(cal_data, 'FileName');
end

% we read one too many lines in the calibration 
% parsing, so we need to backtrack
fseek(fid, -length(line) - 1, 'cof');

%% Read sample data
%
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
time        = zeros(1,nsamples);
temperature = zeros(1,nsamples);

%
% separate loops for sbe37/sbe39 with/without pressure to minimise the 
% amount of in-loop processing involved, so the loop runs as quickly as
% possible. ugly, but faster.
%
if strncmp('SBE37', cal_data.instrument_model, 5)
  
  % sbe37 with temperature and conductivity
  if length(sample_data.parameters) == 2
    
    conductivity = zeros(1,nsamples);
    
    % the nsamples index points to the next free space in the parameter arrays
    nsamples = 1;
    
    while ~feof(fid)

      % temperature, conductivity, date, time
      samples = textscan(fid, sample_expr, 'delimiter', ',');

      temp_block = samples{1};
      cond_block = samples{2};
      time_block = cellstr(samples{3});
      
      % error on most recent line - discard it and continue
      if ~feof(fid)
        time_block = time_block(1:end-1);
        temp_block = temp_block(1:length(time_block));
        cond_block = cond_block(1:length(time_block));
        fgetl(fid);
      end
      
      % convert date to numeric representation
      time_block = datenum(time_block, 'dd mmm yyyy, HH:MM:SS');

      % copy data in to sample_data struct
      temperature( nsamples:nsamples+length(temp_block)-1) = temp_block;
      conductivity(nsamples:nsamples+length(cond_block)-1) = cond_block;
      time(        nsamples:nsamples+length(time_block)-1) = time_block;
              
      nsamples = nsamples + length(time_block);
    end
    
  % sbe37 with temperature, conductivity and pressure
  elseif length(sample_data.parameters) == 3
    
    conductivity = zeros(1,nsamples);
    pressure     = zeros(1,nsamples);
    
    nsamples = 1;
      
    while ~feof(fid)

      % temperature, conductivity, pressure, date, time
      samples = textscan(fid, sample_expr, 'delimiter', ',');
      
      temp_block = samples{1};
      cond_block = samples{2};
      pres_block = samples{3};
      time_block = cellstr(samples{4});
      
      % error on most recent line - discard it and continue
      if ~feof(fid)
        time_block = time_block(1:end-1);
        temp_block = temp_block(1:length(time_block));
        cond_block = cond_block(1:length(time_block));
        pres_block = pres_block(1:length(time_block));
        fgetl(fid);
      end
      
      time_block = datenum(time_block, 'dd mmm yyyy, HH:MM:SS');

      temperature( nsamples:nsamples+length(temp_block)-1) = temp_block;
      conductivity(nsamples:nsamples+length(cond_block)-1) = cond_block;
      pressure(    nsamples:nsamples+length(pres_block)-1) = pres_block;
      time(        nsamples:nsamples+length(time_block)-1) = time_block;

      nsamples = nsamples + length(time_block);
    end
  end
  
elseif strncmp('SBE39', cal_data.instrument_model, 5)
  
  % sbe39 with temperature
  if length(sample_data.parameters) == 1
    
    nsamples = 1;
    
    while ~feof(fid)

      % temperature, date, time
      samples = textscan(fid, sample_expr, 'delimiter', ',');
      temp_block = samples{1};
      time_block = cellstr(samples{2});
      
      % error on most recent line - discard it and continue
      if ~feof(fid)
        time_block = time_block(1:end-1);
        temp_block = temp_block(1:length(time_block));
        fgetl(fid);
      end
      
      time_block = datenum(time_block, 'dd mmm yyyy, HH:MM:SS');

      temperature(nsamples:nsamples+length(temp_block)-1) = temp_block;
      time(       nsamples:nsamples+length(time_block)-1) = time_block;

      nsamples = nsamples + length(time_block);
    end
    
  % sbe39 with temperature and pressure
  elseif length(sample_data.parameters) == 2
    
    pressure = zeros(1,nsamples);
    
    nsamples = 1;
      
    while ~feof(fid)

      % temperature, pressure, date, time
      samples = textscan(fid, sample_expr, 'delimiter', ',');
      temp_block = samples{1};
      pres_block = samples{2};
      time_block = cellstr(samples{3});
      
      % error on most recent line - discard it and continue
      if ~feof(fid)
        time_block = time_block(1:end-1);
        temp_block = temp_block(1:length(time_block));
        pres_block = pres_block(1:length(time_block));
        fgetl(fid);
      end
      
      time_block = datenum(time_block, 'dd mmm yyyy, HH:MM:SS');

      temperature(nsamples:nsamples+length(temp_block)-1) = temp_block;
      pressure(   nsamples:nsamples+length(pres_block)-1) = pres_block;
      time(       nsamples:nsamples+length(time_block)-1) = time_block;

      nsamples = nsamples + length(time_block);
    end
  end
end

%% Clean up

fclose(fid);

% we overallocated memory for the sample data - truncate 
% each array so we're only using the memory that we need
time(nsamples:end) = [];
if ~isempty(temperature),  temperature( nsamples:end) = []; end
if ~isempty(conductivity), conductivity(nsamples:end) = []; end
if ~isempty(pressure),     pressure(    nsamples:end) = []; end

% copy the data into the sample_data struct
sample_data.time = time;
for k = 1:length(sample_data.parameters)
  
  switch sample_data.parameters(k).name
    case TEMPERATURE_NAME,  sample_data.parameters(k).data = temperature;
    case CONDUCTIVITY_NAME, sample_data.parameters(k).data = conductivity;
    case PRESSURE_NAME,     sample_data.parameters(k).data = pressure;
  end
end
