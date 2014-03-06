function sample_data = NXICBinaryParse( filename, mode )
%NXICBINARYPARSE Parses a binary file retrieved from a Falmouth Scientific
% Instruments (FSI) NXIC CTD recorder.
%
% Reads in a raw (.ctd) file retrieved from an NXIC CTD instrument, and
% parses the conductivity, temperature and depth data contained within. A
% specification for the .ctd file format is not available, so this parser
% relies upon reverse engineering efforts which may not be reliable.
%
%
% Inputs:
%   filename    - cell array of strings, names of the files to import. Only 
%                 one file is supported.
%   mode        - Toolbox data type mode ('profile' or 'timeSeries').
%
% Outputs:
%   sample_data - struct containing sample data.
%
% Author:       Paul McCarthy <paul.mccarthy@csiro.au>
% Contributor:  Charles James <charles.james@sa.gov.au>
%               May 2010
%               Recoded to vectorize reading and improve speed
%
%               June 2010
%               Added Header File information and parsing based on discussions with
%               Teledyne Engineers 
%
%               Fixed units for analog channels - all are now in voltages according to
%               the RANGE setting as specified in the header file.
%               Note: calibration coefficients for analog channels are unreliable - user
%               should apply coefficients from sensor manufacturers data sheets.
%
%               Guillaume Galibert <guillaume.galibert@utas.edu.au>
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
  error(nargchk(1,2,nargin));

  if ~iscellstr(filename)
    error('filename must be a cell array of strings'); 
  end
  
  % only one input file supported
  filename = filename{1};
  
  % check that file exists
  if isempty(dir(filename)), error([filename ' does not exist']); end
  
  % read in the whole file into 'data'
  fid = -1;
  data = [];
  try
  % predefine some memmapfile objects to help organize headers and data
    Mheader = memmapfile(filename, 'format', 'uint8', 'repeat', 220);
    M.b0    = memmapfile(filename, 'format', 'uint8', 'offset', 220);
    M.b1    = memmapfile(filename, 'format', 'uint8', 'offset', 221);
    M.b2    = memmapfile(filename, 'format', 'uint8', 'offset', 222);
    M.b3    = memmapfile(filename, 'format', 'uint8', 'offset', 223);
    M.b4    = memmapfile(filename, 'format', 'uint8', 'offset', 224);
  catch e
    rethrow(e);
  end
  
  % the first 220 bytes are the header 
  % section, the rest sample data
  header  = parseHeader(Mheader);
  samples = parseSamples(M, header);
 
 
  % create the sample_data struct
  % This was what PM got out of the header
  sample_data = struct;
  
  sample_data.toolbox_input_file        = filename;
  sample_data.meta.instrument_make      = header.instrument_make;
  sample_data.meta.instrument_model     = header.instrument_model;
  sample_data.meta.instrument_serial_no = header.instrument_serial_no;
  if header.sampleRate > 0
      sample_data.meta.instrument_sample_interval = 1/header.sampleRate;
  else
      sample_data.meta.instrument_sample_interval = median(diff(samples.time*24*3600));
  end
  
  % dimensions definition must stay in this order : T, Z, Y, X, others;
  % to be CF compliant
  sample_data.dimensions = {};
  sample_data.dimensions{1}.name            = 'TIME';
  sample_data.dimensions{1}.typeCastFunc    = str2func(netcdf3ToMatlabType(imosParameters(sample_data.dimensions{1}.name, 'type')));
  sample_data.dimensions{1}.data            = sample_data.dimensions{1}.typeCastFunc(samples.time);
  sample_data.dimensions{2}.name            = 'LATITUDE';
  sample_data.dimensions{2}.typeCastFunc    = str2func(netcdf3ToMatlabType(imosParameters(sample_data.dimensions{2}.name, 'type')));
  sample_data.dimensions{2}.data            = sample_data.dimensions{2}.typeCastFunc(NaN);
  sample_data.dimensions{3}.name            = 'LONGITUDE';
  sample_data.dimensions{3}.typeCastFunc    = str2func(netcdf3ToMatlabType(imosParameters(sample_data.dimensions{3}.name, 'type')));
  sample_data.dimensions{3}.data            = sample_data.dimensions{3}.typeCastFunc(NaN);
  
  sample_data.variables = {};
  sample_data.variables{1}.name = 'TEMP';
  sample_data.variables{2}.name = 'CNDC';
  sample_data.variables{3}.name = 'PRES_REL';
  sample_data.variables{4}.name = 'PSAL';
  sample_data.variables{5}.name = 'SSPD';
  sample_data.variables{6}.name = 'VOLT'; % battery voltage
  % these are the analog and digital channels for the external sensors
  % calibration coefficients in header file are unreliable so will need
  % processing into standard units.
  %sample_data.variables{7}.name = '';
  %sample_data.variables{8}.name = '';
  %sample_data.variables{9}.name = '';
  %sample_data.variables{10}.name = '';
  
  sample_data.variables{1}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{1}.name, 'type')));
  sample_data.variables{2}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{2}.name, 'type')));
  sample_data.variables{3}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{3}.name, 'type')));
  sample_data.variables{4}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{4}.name, 'type')));
  sample_data.variables{5}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{5}.name, 'type')));
  sample_data.variables{6}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{6}.name, 'type')));
%   sample_data.variables{7}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{1}.name, 'type')));
%   sample_data.variables{8}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{1}.name, 'type')));
%   sample_data.variables{9}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{1}.name, 'type')));
%   sample_data.variables{10}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{1}.name, 'type')));
  
  sample_data.variables{1}.dimensions = [1 2 3];
  sample_data.variables{2}.dimensions = [1 2 3];
  sample_data.variables{3}.dimensions = [1 2 3];
  sample_data.variables{4}.dimensions = [1 2 3];
  sample_data.variables{5}.dimensions = [1 2 3];
  sample_data.variables{6}.dimensions = [1 2 3];
  %sample_data.variables{7}.dimensions = [1 2 3];
  %sample_data.variables{8}.dimensions = [1 2 3];
  %sample_data.variables{9}.dimensions = [1 2 3];
  %sample_data.variables{10}.dimensions = [1 2 3];
  
  sample_data.variables{1}.data = sample_data.variables{1}.typeCastFunc(samples.temperature);
  sample_data.variables{2}.data = sample_data.variables{2}.typeCastFunc(samples.conductivity);
  sample_data.variables{3}.data = sample_data.variables{3}.typeCastFunc(samples.pressure);
  sample_data.variables{3}.applied_offset = sample_data.variables{3}.typeCastFunc(-gsw_P0/10^4); % to be confirmed! (gsw_P0/10^4 = 10.1325 dbar)
  sample_data.variables{4}.data = sample_data.variables{4}.typeCastFunc(samples.salinity);
  sample_data.variables{5}.data = sample_data.variables{5}.typeCastFunc(samples.soundSpeed);
  sample_data.variables{6}.data = sample_data.variables{6}.typeCastFunc(samples.voltage);
  %sample_data.variables{7}.data = sample_data.variables{7}.typeCastFunc(samples.analog1);  % FLNTU Turbidity
  %sample_data.variables{8}.data = sample_data.variables{8}.typeCastFunc(samples.analog2);  % FLNTU Fluorescence
  %sample_data.variables{9}.data = sample_data.variables{9}.typeCastFunc(samples.analog3);  % Biospherical PAR
  %sample_data.variables{10}.data = sample_data.variables{10}.typeCastFunc(samples.analog4);
  
  %if isfield(samples,'digital');
  % not all instruments have a digital channel.
  %sample_data.variables{11}.name = '';
  %sample_data.variables{11}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{11}.name, 'type')));
  %sample_data.variables{11}.dimensions = [1 2 3];
  %sample_data.variables{11}.data = sample_data.variables{11}.typeCastFunc(samples.digital); % Aanderaa Optode
  %end;
  
end

function header = parseHeader(mheader)
%PARSEHEADER Parses the NXIC header section from the given data vector.
%
% Inputs:
%   mheaders   - memory map of header part of file.
%
% Outputs:
%   header - struct containing the contents of the header.
%
% Charles James June 2010
% Header Structure Based on Teledyne Report
% Based on EEPROM memory of instrument with two parts
% ee_data Part 1
% Bytes 1-2     Size of EEPROM memory part 1 (155)
% Bytes 3-4     Serial Number
% Byte 5        OPS (options enabled)
%               OPS Bit     Option
%               0           Continous On Power Up
%               1           Scaled Output
%               2           Address Operations
%               3           Check Sum Operations on Run Mode Messages
%               4           Clock Chip Valid
%               5           Auto-Logging
%               6           RS-232 on/off
%               7           External Sensors
% Byte 6        IntOps (interval mode settings)
%               IntOPS Bit  Option
%               0           Interval Operations
%               1           Interval Time Setting
%               2           On Time Setting
%               3           unused
%               4           Delayed Start Operations
%               5           Delayed Time Setting
%               6           Delayed Date Setting
%               7           Auto Interval Logging
% Byte 7        Baud Rate Setting
% Byte 8        Channels (which are on or off)
% Byte 9        Size of memory card
% Byte 10-11    Sample Rate
% Byte 12-13    AD2440Rate (Linear Teach A/D sampling rate)
% Byte 14-15    AdrH and AdrL??
% Byte 16-17    Value for spike filter
% Byte 18-25    Delayed Start Time (sec,min,hour,day,mon,year,wday,tsec)
% Byte 26-28    Average Interval (hour,min,sec)
% Byte 29-31    Interval (hour,min,sec)
% Byte 32-34    On Time (hour,min,sec)
% Byte 35-38    A1 (Conductivity Coefficient)
% Byte 39-42    B1 (Conductivity Coefficient)
% Byte 43-46    C1 (Conductivity Coefficient)
% Byte 47-50    D1 (Conductivity Coefficient)
% Byte 51-54    Kfactor (cell constant - may be unused)
% Byte 55-58    A2 (Temperature Coefficient)
% Byte 59-62    B2 (Temperature Coefficient)
% Byte 63-66    C2 (Temperature Coefficient)
% Byte 67-70    D2 (Temperature Coefficient)
% Byte 71-74    A1A (Analog Channel 1 Offset)
% Byte 75-78    A1B (Analog Channel 1 Slope)
% Byte 79-82    A2A (Analog Channel 2 Offset)
% Byte 83-86    A2B (Analog Channel 2 Slope)
% Byte 87-90    A3A (Analog Channel 3 Offset)
% Byte 91-94    A3B (Analog Channel 3 Slope)
% Byte 95-98    A4A (Analog Channel 4 Offset)
% Byte 99-102   A4B (Analog Channel 4 Slope)
% Byte 103-106  A03 (Pressure Coefficient)
% Byte 107-110  BO3 (Pressure Coefficient)
% Byte 111-114  C03 (Pressure Coefficient)
% Byte 115-118  A503 (Pressure Coefficient)
% Byte 119-122  B503 (Pressure Coefficient)
% Byte 123-126  C503 (Pressure Coefficient)
% Byte 127-130  A1003 (Pressure Coefficient)
% Byte 131-134  B1003 (Pressure Coefficient)
% Byte 135-138  C1003 (Pressure Coefficient)
% Byte 139-142  A3 (Pressure Coefficient)
% Byte 143-146  PS0 (Pressure Coefficient)
% Byte 147-150  PS50 (Pressure Coefficient) 
% Byte 151-154  PS100 (Pressure Coefficient)
% Byte 155      Checksum
%
% ee_data Part 2
% Byte 156-163  Calibration Date
% Byte 164-167  CLKA (not sure what this is ?)
% Byte 168-171  CLKB (?)
% Byte 172-175  CLKC (?)
% Byte 176      Current from Battery
% Byte 177      Format (setting of output format)
% Byte 178      Op2 (RANGE and GAIN values for Analog channel
%               Op2 bits 0-1    Option
%               00              Range 0 (+/- 5V)
%               10              Range 1 (0-5V)
%               01              Range 2 (+/- 10V)
%               11              Range 3 (0-10V)
%               Op2 bit     Option
%               2           GAIN0_0=1;
%               3           GAIN0_1=1;
%               4           GAIN1_0=1;
%               5           GAIN1_1=1;
% Byte 179      Op3 (PROD setting?)
% Byte 180-184  Sets ID number for ADCP Channels 1-5
% Byte 185-186  Delay between each ASCII character
% Byte 187-188  Delay between each ASCII line
% Byte 189-190  N1 (number of points in Options Filter)
% Byte 191-194  BioScale (coefficients used in sensor math)
% Byte 195-196  Constant Pressure Value (user option)
%
% From here things differ between old NXIC and format provided by Teledyne
% Presumably this applies for CTDs with Rinko O2 sensors on them.  First
% Citadel we looked at seemed to be the same format as old NXIC.
%
% Byte 197-200  Alpha (Coef for P,T compensation for Cond.)
% Byte 201-204  Beta (Coef for P,T compensation for Cond.)
% Byte 205-208  Beta2 (Coef for P,T compensation for Cond.)
% Byte 209-212  Pad (Rinko Sensor Coefficient)
% Byte 213-216  A3RA (Rinko Sensor Coefficient)
% Byte 217-220  A3RB (Rinko Sensor Coefficient)
% Byte 221-224  A3RC (Rinko Sensor Coefficient)
% Byte 225-228  A3RD (Rinko Sensor Coefficient)
% Byte 229-342  A3RE (Rinko Sensor Coefficient)
% Byte 243-246  A3RF (Rinko Sensor Coefficient)
% Byte 247-250  A3RG (Rinko Sensor Coefficient)
% Byte 251-254  A3RH (Rinko Sensor Coefficient)
% Byte 255-258  A4RA (Rinko Sensor Coefficient)
% Byte 259-262  A4RB (Rinko Sensor Coefficient)
% Byte 263-266  A4RC (Rinko Sensor Coefficient)
% Byte 267-270  A4RD (Rinko Sensor Coefficient)
%
% looking at the data it appeaers that
% Byte 200 = sample length 41 or 37 bytes w or w/o digital channel

% if interval is set then
% Byte 215-217 = Byte 29-31 Interval
% Byte 218-220 = Byte 32-34 On Time

  bit='1';

  header = struct;
  % data bytes 1-2
  header.instrument_serial_no = num2str(bytecast(mheader.Data(3:4), 'L', 'uint16'));
  
  % first Citadel we bought was Mark's 2276 for IS2
  if (header.instrument_serial_no<2276)
      header.instrument_make      = 'Falmouth Scientific Instruments';
      header.instrument_model     = 'NXIC CTD';
  else
      header.instrument_make      = 'Teledyne';
      header.instrument_model     = 'Citadel CTD';
  end
  
  % Parse Options in byte 5
  option1 = dec2bin(mheader.Data(5),8);
  % start with bit 7
  Options.externalSensors   = strcmp(option1(1),bit);	% has sensors
  Options.enableRS232       = strcmp(option1(2),bit);	% use rs232
  Options.enableAutologging = strcmp(option1(3),bit);	% enable autologging
  Options.enableClock       = strcmp(option1(4),bit);	% enable clock
  Options.useCheckSum       = strcmp(option1(5),bit);	% run mode checksum
  Options.addressOperations = strcmp(option1(6),bit);	% address operations?
  Options.scaleOutput       = strcmp(option1(7),bit);   % scaled output
  Options.continuousOn      = strcmp(option1(8),bit);	% continuous on power up
  
  % Parse Options in byte 6
  option2 = dec2bin(mheader.Data(6),8);
  % start with bit 7
  Options.autoIntervalLogging   = strcmp(option2(1),bit);   % auto interval logging
  Options.delayedDateSet        = strcmp(option2(2),bit);	% delayed date setting
  Options.delayedTimeSet        = strcmp(option2(3),bit);	% delayed time setting
  Options.delayedStart          = strcmp(option2(4),bit);	% delayed start operations
  
  Options.onTime                = strcmp(option2(6),bit);	% on time setting
  Options.intervalTime          = strcmp(option2(7),bit);	% interval time setting
  Options.intervalOperation     = strcmp(option2(8),bit);	% interval operation


  % mode depends on Opt1 and Opt2 settings
  %if Options.continuousOn
  %    mode1='continuous on power-on';
  %    mode2='';     
  %else
  %    if Options.delayedStart
  %        mode1='delayed';
  %    else
  %        mode1='no delay';
  %    end
  %    if Options2.intervalOperation
  %        mode2=' interval';
  %    else
  %        mode2=' continuous';
  %    end
  %end
  %disp([mode1 mode2]);
  % skip bytes 7-9 (baud rate, channels, mem card)
  
  % Sample frequency in Hz
  header.sampleRate = bytecast(mheader.Data(10:11),'L','uint16');
  % skip A/D sample rate bytes 12-13
  % and AdrH and AdrL 14-15
  % and spike filter 16-17
  
  % this is the delayed start date, only meaningful if delayed mode used
  % for deployment otherwise it contains the start date from the last
  % time this function was used and not necessairly the stat date of this
  % deployment!
  if Options.delayedStart
      second = double(mheader.Data(18));
      minute = double(mheader.Data(19));
      hour   = double(mheader.Data(20));
      day    = double(mheader.Data(21));
      month  = double(mheader.Data(22));
      year   = double(mheader.Data(23)) + 2000;
      
      header.delayedStartDate = datenum(year, month, day, hour, minute, second);
  else
      header.delayedStartDate = [];
  end
  
  % averaging interval hours and minutes
  minute = double(mheader.Data(27));
  second = double(mheader.Data(28));
  header.average = minute * 60 + second;
  
  if Options.intervalOperation
      % interval and record times are stored in seconds
      hour   = double(mheader.Data(29));
      minute = double(mheader.Data(30));
      second = double(mheader.Data(31));
      header.interval = hour * 3600 + minute * 60 + second;
      
      hour   = double(mheader.Data(32));
      minute = double(mheader.Data(33));
      second = double(mheader.Data(34));
      header.record = hour * 3600 + minute * 60 + second;
  else
      header.interval = 0;
      header.record = inf;
  end
  % Calibration Constants;
  % Conductivity
  Calibration.Conductivity.A1 = bytecast(mheader.Data(35:38),'L','single');
  Calibration.Conductivity.B1 = bytecast(mheader.Data(39:42),'L','single');
  Calibration.Conductivity.C1 = bytecast(mheader.Data(43:46),'L','single');
  Calibration.Conductivity.D1 = bytecast(mheader.Data(47:50),'L','single');
  
  % no idea
  Calibration.Cell.Kfactor = bytecast(mheader.Data(51:54),'L','single');
  
  % Temperature
  Calibration.Temperature.A2 = bytecast(mheader.Data(55:58),'L','single');
  Calibration.Temperature.B2 = bytecast(mheader.Data(59:62),'L','single');  
  Calibration.Temperature.C2 = bytecast(mheader.Data(63:66),'L','single');
  Calibration.Temperature.D2 = bytecast(mheader.Data(67:70),'L','single');  
  
  % Calibration coeffients for analog/digital channels
  % quite often appear to be wrong!
  Calibration.Analog.A1A = bytecast(mheader.Data(71:74),'L','single');
  Calibration.Analog.A1B = bytecast(mheader.Data(75:78),'L','single');  
  Calibration.Analog.A2A = bytecast(mheader.Data(79:82),'L','single');
  Calibration.Analog.A2B = bytecast(mheader.Data(83:86),'L','single');
  Calibration.Analog.A3A = bytecast(mheader.Data(87:90),'L','single');  
  Calibration.Analog.A3B = bytecast(mheader.Data(91:94),'L','single');  
  Calibration.Analog.A4A = bytecast(mheader.Data(95:98),'L','single');
  Calibration.Analog.A4B = bytecast(mheader.Data(99:102),'L','single');  
  
  % Pressure
  Calibration.Pressure.A03 = bytecast(mheader.Data(103:106),'L','single');
  Calibration.Pressure.B03 = bytecast(mheader.Data(107:110),'L','single');
  Calibration.Pressure.C03 = bytecast(mheader.Data(111:114),'L','single');
  
  Calibration.Pressure.A503 = bytecast(mheader.Data(115:118),'L','single');
  Calibration.Pressure.B503 = bytecast(mheader.Data(119:122),'L','single');
  Calibration.Pressure.C503 = bytecast(mheader.Data(123:126),'L','single');
  
  Calibration.Pressure.A1003 = bytecast(mheader.Data(127:130),'L','single');    
  Calibration.Pressure.B1003 = bytecast(mheader.Data(131:134),'L','single');
  Calibration.Pressure.C1003 = bytecast(mheader.Data(135:138),'L','single');
    
  Calibration.Pressure.A3 = bytecast(mheader.Data(139:142),'L','single');
  
  Calibration.Pressure.PS0      = bytecast(mheader.Data(143:146),'L','single');
  Calibration.Pressure.PS50     = bytecast(mheader.Data(147:150),'L','single');
  Calibration.Pressure.PS100    = bytecast(mheader.Data(151:154),'L','single');

  header.Calibration = Calibration;
 
 % test checksum (don't know what to do if fails, warn I suppose)
  isgood = bitand(sum(mheader.Data(1:154)),255) == mheader.Data(155);
  if ~isgood
      fprintf('%s\n', ['Warning : ' filename ' header checksum failed']);
      header.checksum = false;
  else
      header.checksum = true;
  end
 
  header.Calibration.Date = char(mheader.Data(156:163)');
  
  % ignore bytes 164-177 ClkA, ClkB, ClkC, current, format
  
  % Range and Gain values
  % stored in separate parts of byte
  option3 = dec2bin(mheader.Data(178),8);
  % first check range from first 2 bits
  switch option3(7:8)
      case '00'
          Options.RANGE = 0; %+/-5V
          vunit     = 'int16';
          vscale    = 5/2^15;
      case '10'
          Options.RANGE = 1; %0-5V
          vunit     = 'uint16';
          vscale    = 5/2^16;
      case '01'
          Options.RANGE = 2; %+/- 10V
          vunit     = 'int16';
          vscale    = 10/2^15;
      case '11'
          Options.RANGE = 3; %0-10V
          vunit     = 'uint16';
          vscale    = 10/2^16;
  end
  
  Options.analogUnit  = vunit;
  Options.analogScale = vscale; % to convert from bits to voltage
  
  % next 4 bits set GAINS
  Options.GAIN0_0 = strcmp(option3(6),bit);
  Options.GAIN0_1 = strcmp(option3(5),bit);
  Options.GAIN1_0 = strcmp(option3(4),bit);
  Options.GAIN1_1 = strcmp(option3(3),bit);
  
  header.sampleLength = double(mheader.Data(200));
  
  header.Options = Options;
  
  header.binaryData = mheader.Data;
  
end

function sample = parseSamples(M, header)
%PARSESAMPLES Parses all of the NXIC samples contained in the given data
% vector.
%
% Inputs:
%   M -        Struct of memmapfile objects of data samples
%   header   - Struct containing the contents of the file header.
%
% Outputs:
%   samples - struct containing sample data.
%
len = header.sampleLength;
Options = header.Options;
mlstart = datenum('01-01-1970');
msamples = M.b0;

% try to vectorize based on time stamp

% Data Pattern for all FSI CTDs I've seen
% Bytes 1-4 Datenumber (uint32)
% Byte  5 100/s of seconds (uint8)
% Up to 6 blocks of floating point (32 Bits) data stored little endian
% usually Cond, Temp, Press, Salinity, Sound Speed, Voltage
% Ext. Sensors stored at end


rdatlen=length(msamples.Data);
% for very long records break up the processing into blocks
% this number can be modified
blocklength = 5000*len;
% overlap a few record lengths to ensure all samples are read
blockoverlap = 2*len;

% create logical index with true values at predicted start of each sample
% false everywhere else
time_logic=false(size(msamples.Data));
time_logic(1:len:end)=true;
% compute time (UNIX based) at isample intervals

times=index2time(M,time_logic);

%calculate sample intervals to look for misaligned data
dt=diff(times);

% double check header.interval (it has been wrong on an instrument)
sampleinterval=getSampleIntervalInfo(times);
if sampleinterval>0;
    interval=sampleinterval;
else
    % only other option - just hope it's right!
    interval=header.interval;
end

% look for misalingments
% timebase errors are big jumps (dt>interval*2)
tberror=(abs(dt)>interval*2);
ierr=0;
D=uint8([]);

% if times and size are ok we may only need to reshape data
if (mod(rdatlen,len)==0)&&~any(tberror);
    % Can only do this if it is a flawless record
    % i.e. sampleinterval not -1
    if sampleinterval>0
        D=reshape(msamples.Data,len,rdatlen./len);
    end
end

% if there are any errors we must attempt to realign the data
% so far we have seen:
% repeated sections following a glitch
% extended burstsamples (60min or longer instead of 30s)



% while errors in the timebase exist try and fix
while any(tberror);
    % track number of alignment errors
    ierr=ierr+1;
    % the index of the last sample starting with correct time - this is
    % probably the sample that glitched
    ibad=find(tberror,1);
    tbad=times(ibad);
    
    % start first block at first error
    blockstart=ibad;
    % try to find new valid sample time in block
    % 5 data bytes required for conversion to time
    
    % need to track redumbs that cross multiple blocks
    foundstart=false;
    
    endofblock=false;
    while ~endofblock;
        blockend=blockstart+blocklength+blockoverlap;
        
        % check for end of block
        if blockend>rdatlen
            blockend=rdatlen-4;
            endofblock=true;
        end
        
        % set index sequence for this block
        blockindex=blockstart:blockend;
        
        % form vector of all possible times starting with the first bad
        % point - just do this once and save result for later
        reftimes=index2time(M,blockindex);
        
        % build index of bad time stamps
        istart=find(reftimes==tbad);
        
        if ~isempty(istart);
            if length(istart)>1
                % assume we have found at least one redump of the data in
                % this block
                % clear old time_logic indicies
                time_logic(blockstart+min(istart):end)=false;
                % tag new start in time_logic index
                time_logic(blockstart+max(istart)-1:len:end-4)=true;
            elseif length(istart)==1
                time_logic(blockstart+istart:end)=false;
                if foundstart
                    time_logic(blockstart+istart-1:len:end-4)=true;
                else
                    foundstart=true;
                end
            end
        end
            
        if ~endofblock
            % reset next blockstart to last end - overlap
            blockstart=blockend-blockoverlap;
        end
    end
    % check the new proposed times stamps
    times=index2time(M,time_logic);
    
    % check for any more errors and repeat routine if necessary to align
    dt=diff(times);
    tberror=(abs(dt)>interval*2);
end

isample=find(time_logic);

% re-sort for occasional time step reversals (only small ones)
% change sample order for monotonically increasing time
[reftimes isort]=sort(times);
isample=isample(isort);

% remove duplicate times
[reftimes usort]=unique(reftimes,'last');
isample=isample(usort);


% map data to uniform grid each row contains data channel, each column is a
% observation.
for i=1:len;
    D(i,:)=msamples.Data(isample+i-1);
end
time1 = D(1:4,:);
t1 = bytecast(time1(:), 'L', 'uint32');
t2 = double(D(5,:))/100;
sample.time = mlstart + (t1(:) + t2(:))/86400;

cond = D(6:9,:);
sample.conductivity = bytecast(cond(:), 'L', 'single');
% in units of mmho/cm IMOS needs S/m
sample.conductivity = sample.conductivity./10;

temp = D(10:13,:);
sample.temperature = bytecast(temp(:), 'L', 'single');

pres = D(14:17,:);
sample.pressure = bytecast(pres(:), 'L', 'single');

sal = D(18:21,:);
sample.salinity = bytecast(sal(:), 'L', 'single');

sspd = D(22:25,:);
sample.soundSpeed = bytecast(sspd(:), 'L', 'single');

volt = D(26:29,:);
sample.voltage = bytecast(volt(:), 'L', 'single');

a1 = D(30:31,:);  % turbidity if fitted with FLNTU
sample.analog1 = bytecast(a1(:), 'L', Options.analogUnit).*Options.analogScale;

a2 = D(32:33,:);  % fluorescence if fitted with FLNTU
sample.analog2 = bytecast(a2(:), 'L', Options.analogUnit).*Options.analogScale;

a3 = D(34:35,:); % PAR if fitted with Biospherical par sensor
sample.analog3 = bytecast(a3(:), 'L', Options.analogUnit).*Options.analogScale;

ch4 = D(36:37,:); % 
sample.analog4 = bytecast(ch4(:), 'L', Options.analogUnit).*Options.analogScale;

if len==41
    % if digital channel exists
    dig = D(38:41,:); % may be used by Aanderra Optode
    sample.digital = bytecast(dig(:), 'L', 'single');
end

end

function times = index2time(M, index)
% function to extract times in 5 byte FSI format from data file at index
% points.

% At this point it is possible that index=true in one of the last 5 places
% which will cause an oversize index error (only use an index that will fit
% into the shifted b4 data)
indexmaxlen=length(M.b4.Data);
lenindex=length(index);
if indexmaxlen<lenindex
    index=index(1:indexmaxlen);
end

% 5 byte format first 4 bytes give datenumber to minutes 5th byte contains
% 100ths of seconds - need double precicison to preserve seconds.
if islogical(index);
    N = sum(index)*4;
else
    N = length(index)*4;
end

% This now forms the times from the 5 consecutive bytes formed from the
% offset memmapfile objects
times =...
    bytecast(reshape(...
    [M.b0.Data(index) M.b1.Data(index) ...
    M.b2.Data(index) M.b3.Data(index)]'...
    , N, 1), 'L', 'uint32') + ...
    double(M.b4.Data(index))/100;

end

function [sampleinterval burstinterval nburst] = getSampleIntervalInfo(t)
% determines sampling parameters from the actual time data

dt = diff(t);

% if averaging time is less than record time there will be multiple dt
% how many time differences are there?
dt = dt(:)';
dts = sort(dt);
dts = [dts(diff(dts) > 0) dts(end)];

if length(dts) > 200;
    % data is probably not aligned yet so we can't calculate this
    burstinterval = -1;
    nburst = -1;
    sampleinterval = -1;
else
    % find a mid point between bursts and records
    mid = mean(dts);
    
    burstinterval = median(dt(dt < mid));
    recinterval = median(dt(dt > mid));
    nburst = median(diff(find(dt > mid)));
    sampleinterval = recinterval + burstinterval*(nburst-1);
end

end