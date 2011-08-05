function sample_data = NXICBinaryParse( filename )
%NXICBINARYPARSE Parses a binary file retrieved from a Falmouth Scientific
% Instruments (FSI) NXIC CTD recorder.
%
% Reads in a raw (.ctd) file retrieved from an NXIC CTD instrument, and
% parses the conductivity, temperature and depth data contained within. A
% specification for the .ctd file format is not available, so this parser
% relies upon reverse engineering efforts which may not be reliable.
%
% Currently, this parser only provides conductivity, temperature and
% pressure data.
%
% Inputs:
%   filename    - cell array of strings, names of the files to import. Only 
%                 one file is supported.
%
% Outputs:
%   sample_data - struct containing sample data.
%
% Author: Paul McCarthy <paul.mccarthy@csiro.au>
%
% Charles James May 2010
% Recoded to vectorize reading and improve speed
%
% Charles James June 2010
% Added Header File information and parsing based on discussions with
% Teledyne Engineers 
%
% Charles James June 2010
% Fixed units for analog channels - all are now in voltages according to
% the RANGE setting as specified in the header file.
% Note: calibration coefficients for analog channels are unreliable - user
% should apply coefficients from sensor manufacturers data sheets.
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
  error(nargchk(1,1,nargin));

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
    fid = fopen(filename, 'rb');
    data = fread(fid, inf, '*uint8');
    fclose(fid);
  catch e
    if fid ~= -1, fclose(fid); end
    rethrow(e);
  end
  
  % the first 220 bytes aer the header 
  % section, the rest sample data
  header  = parseHeader (data(1:220));
  samples = parseSamples(data(221:end), header);
 
 
  % create the sample_data struct
  % This was what PM got out of the header
  sample_data = struct;
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
  sample_data.dimensions{1}.name = 'TIME';
  sample_data.dimensions{1}.data = samples.time;
  sample_data.dimensions{2}.name = 'LATITUDE';
  sample_data.dimensions{2}.data = NaN;
  sample_data.dimensions{3}.name = 'LONGITUDE';
  sample_data.dimensions{3}.data = NaN;
  
  sample_data.variables = {};
  sample_data.variables{1}.name = 'TEMP';
  sample_data.variables{2}.name = 'CNDC';
  sample_data.variables{3}.name = 'PRES';
  sample_data.variables{4}.name = 'PSAL';
  sample_data.variables{5}.name = 'SSPD';
  sample_data.variables{6}.name = 'VOLT';
  % these are the analog and digital channels for the external sensors
  % calibration coefficients in header file are unreliable so will need
  % processing into standard units.
  %sample_data.vairables{7}.name = '';
  %sample_data.vairables{8}.name = '';
  %sample_data.vairables{9}.name = '';
  %sample_data.vairables{10}.name = '';
  
  
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
  
  sample_data.variables{1}.data = samples.temperature;
  sample_data.variables{2}.data = samples.conductivity;
  sample_data.variables{3}.data = samples.pressure;
  sample_data.variables{4}.data = samples.salinity;
  sample_data.variables{5}.data = samples.soundSpeed;
  sample_data.variables{6}.data = samples.voltage;
  %sample_data.variables{7}.data = samples.analog1;  % FLNTU Turbidity
  %sample_data.variables{8}.data = samples.analog2;  % FLNTU Fluorescence
  %sample_data.variables{9}.data = samples.analog3;  % Biospherical PAR
  %sample_data.variables{10}.data = samples.analog4;
  
  %if isfield(samples,'digital');
  % not all instruments have a digital channel.
  %sample_data.variables{11}.name = '';
  %sample_data.variables{11}.dimensions = [1 2 3];
  %sample_data.variables{11}.data = samples.digital; % Aanderaa Optode
  %end;
  
end

function header = parseHeader(data)
%PARSEHEADER Parses the NXIC header section from the given data vector.
%
% Inputs:
%   data   - vector of bytes containing the header section.
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
  header.instrument_serial_no = num2str(bytecast(data(3:4), 'L', 'uint16'));
  
  % first Citadel we bought was Mark's 2276 for IS2
  if (header.instrument_serial_no<2276)
      header.instrument_make      = 'Falmouth Scientific Instruments';
      header.instrument_model     = 'NXIC CTD';
  else
      header.instrument_make      = 'Teledyne';
      header.instrument_model     = 'Citadel CTD';
  end
  
  % Parse Options in byte 5
  option1=dec2bin(data(5),8);
  % start with bit 7
  Options.externalSensors=strcmp(option1(1),bit); % has sensors
  Options.enableRS232=strcmp(option1(2),bit);      % use rs232
  Options.enableAutologging=strcmp(option1(3),bit);     % enable autologging
  Options.enableClock=strcmp(option1(4),bit);      % enable clock
  Options.useCheckSum=strcmp(option1(5),bit);  % run mode checksum
  Options.addressOperations=strcmp(option1(6),bit);      % address operations?
  Options.scaleOutput=strcmp(option1(7),bit);   % scaled output
  Options.continuousOn=strcmp(option1(8),bit);     % continuous on power up
  
  % Parse Options in byte 6
  option2=dec2bin(data(6),8);
  % start with bit 7
  Options.autoIntervalLogging=strcmp(option2(1),bit);% auto interval logging
  Options.delayedDateSet=strcmp(option2(2),bit); % delayed date setting
  Options.delayedTimeSet=strcmp(option2(3),bit); % delayed time setting
  Options.delayedStart=strcmp(option2(4),bit);   % delayed start operations
  
  Options.onTime=strcmp(option2(6),bit);          % on time setting
  Options.intervalTime=strcmp(option2(7),bit);    % interval time setting
  Options.intervalOperation=strcmp(option2(8),bit);           % interval operation


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
  header.sampleRate=bytecast(data(10:11),'L','uint16');
  % skip A/D sample rate bytes 12-13
  % and AdrH and AdrL 14-15
  % and spike filter 16-17
  
  % this is the delayed start date, only meaningful if delayed mode used
  % for deployment otherwise it contains the start date from the last
  % time this function was used and not necessairly the stat date of this
  % deployment!
  if Options.delayedStart
  second = double(data(18));
  minute = double(data(19));
  hour   = double(data(20));
  day    = double(data(21));
  month  = double(data(22));
  year   = double(data(23)) + 2000;
  
  header.delayedStartDate = datenum(year, month, day, hour, minute, second);
  else
      header.delayedStartDate=[];
  end
  
  % averaging interval hours and minutes
  minute=double(data(27));
  second=double(data(28));
  header.average=minute*60+second;
  
  if Options.intervalOperation
  % interval and record times are stored in seconds
      hour   = double(data(29));
      minute = double(data(30));
      second = double(data(31));
      header.interval = hour * 3600 + minute * 60 + second;
      
      hour   = double(data(32));
      minute = double(data(33));
      second = double(data(34));
      header.record = hour * 3600 + minute * 60 + second;
  else
      header.interval=0;
      header.record=inf;
  end
  % Calibration Constants;
  % Conductivity
  Calibration.Conductivity.A1=bytecast(data(35:38),'L','single');
  Calibration.Conductivity.B1=bytecast(data(39:42),'L','single');
  Calibration.Conductivity.C1=bytecast(data(43:46),'L','single');
  Calibration.Conductivity.D1=bytecast(data(47:50),'L','single');
  
  % no idea
  Calibration.Cell.Kfactor=bytecast(data(51:54),'L','single');
  
  % Temperature
  Calibration.Temperature.A2=bytecast(data(55:58),'L','single');
  Calibration.Temperature.B2=bytecast(data(59:62),'L','single');  
  Calibration.Temperature.C2=bytecast(data(63:66),'L','single');
  Calibration.Temperature.D2=bytecast(data(67:70),'L','single');  
  
  % Calibration coeffients for analog/digital channels
  % quite often appear to be wrong!
  Calibration.Analog.A1A=bytecast(data(71:74),'L','single');
  Calibration.Analog.A1B=bytecast(data(75:78),'L','single');  
  Calibration.Analog.A2A=bytecast(data(79:82),'L','single');
  Calibration.Analog.A2B=bytecast(data(83:86),'L','single');
  Calibration.Analog.A3A=bytecast(data(87:90),'L','single');  
  Calibration.Analog.A3B=bytecast(data(91:94),'L','single');  
  Calibration.Analog.A4A=bytecast(data(95:98),'L','single');
  Calibration.Analog.A4B=bytecast(data(99:102),'L','single');  
  
  % Pressure
  Calibration.Pressure.A03=bytecast(data(103:106),'L','single');
  Calibration.Pressure.B03=bytecast(data(107:110),'L','single');
  Calibration.Pressure.C03=bytecast(data(111:114),'L','single');
  
  Calibration.Pressure.A503=bytecast(data(115:118),'L','single');
  Calibration.Pressure.B503=bytecast(data(119:122),'L','single');
  Calibration.Pressure.C503=bytecast(data(123:126),'L','single');
  
  Calibration.Pressure.A1003=bytecast(data(127:130),'L','single');    
  Calibration.Pressure.B1003=bytecast(data(131:134),'L','single');
  Calibration.Pressure.C1003=bytecast(data(135:138),'L','single');
    
  Calibration.Pressure.A3=bytecast(data(139:142),'L','single');
  
  Calibration.Pressure.PS0=bytecast(data(143:146),'L','single');
  Calibration.Pressure.PS50=bytecast(data(147:150),'L','single');
  Calibration.Pressure.PS100=bytecast(data(151:154),'L','single');
  
  
  
  header.Calibration=Calibration;
  
  
 
 % test checksum (don't know what to do if fails, warn I suppose)
  isgood=bitand(sum(data(1:154)),255)==data(155);
  if ~isgood
      disp('Warning header checksum failed');
      header.checksum=false;
  else
      header.checksum=true;
  end
 
  header.Calibration.Date = char(data(156:163)');
  
  % ignore bytes 164-177 ClkA, ClkB, ClkC, current, format
  
  % Range and Gain values
  % stored in separate parts of byte
  option3=dec2bin(data(178),8);
  % first check range from first 2 bits
  switch option3(7:8)
      case '00'
          Options.RANGE=0; %+/-5V
          vunit='int16';
          vscale=5/2^15;
      case '10'
          Options.RANGE=1; %0-5V
          vunit='uint16';
          vscale=5/2^16;
      case '01'
          Options.RANGE=2; %+/- 10V
          vunit='int16';
          vscale=10/2^15;
      case '11'
          Options.RANGE=3; %0-10V
          vunit='uint16';
          vscale=10/2^16;
  end
  
  Options.analogUnit=vunit;
  Options.analogScale=vscale; % to convert from bits to voltage
  
  % next 4 bits set GAINS
  Options.GAIN0_0=strcmp(option3(6),bit);
  Options.GAIN0_1=strcmp(option3(5),bit);
  Options.GAIN1_0=strcmp(option3(4),bit);
  Options.GAIN1_1=strcmp(option3(3),bit);
  
  header.sampleLength = double(data(200));
  
  header.Options=Options;
  
  header.binaryData=data;
  
end

function sample = parseSamples(data, header)
%PARSESAMPLES Parses all of the NXIC samples contained in the given data
% vector.
%
% Inputs:
%   data    - Vector of bytes containing samples.
%   header  - Struct containing the contents of the file header.
%
% Outputs:
%   samples - struct containing sample data.
%
  len = header.sampleLength;
  Options=header.Options;
  mlstart=datenum('01-01-1970');
  
  % try to vectorize based on time stamp
  
% Data Pattern for all FSI CTDs I've seen
% Bytes 1-4 Datenumber (uint32)
% Byte  5 100/s of seconds (uint8)
% Up to 6 blocks of floating point (32 Bits) data stored little endian
% usually Cond, Temp, Press, Salinity, Sound Speed, Voltage
% Ext. Sensors stored at end
 
 itimes=1:len:length(data);
  
 % contains the start index of samples within data
 % assume uncorrupted record to start
 isample=itimes;

 % compute time at isample intervals
 times1=index2time(data,isample);
 
 dt=diff(times1);
 % sample before the last time was found in the right place
 % is the only one we know is good as the time is at the start of sample
 if header.interval > 0
     lastgood=find((dt<0)|(fix(dt)>header.interval),1)-1;
 else
     lastgood=find((dt<0),1)-1;
 end

 % count any data errors as they occur
 ierr=0;
 D=uint8([]);
 if mod(length(data),len)==0;
     % could be a flawless record?
     % if so, only allow a few short gaps in times1
     ngaps=sum(fix(dt)>header.interval);
     if (ngaps/length(times1))<1e-3
         D=reshape(data,len,length(data)./len);
     end
 end
 
 if isempty(D);
     while ~isempty(lastgood);
         ierr=ierr+1;
         % try to find new valid sample time in remaining data
         ntimes=isample(lastgood+1):length(data)-5;
         if ierr==1
             % this is a big calculation so we'll only do it once
             times2=index2time(data,ntimes);
         else
             % just adjust the existing times
             times2=times2(end-length(ntimes)+1:end);
         end
         clear ntimes;
         
         dt=times2-times1(lastgood+1);
         
         % this should be the offset to the next good sample time
         if header.interval > 0
             goodind=find((dt>0)&(fix(dt)<header.interval),1)-1;
         else
             goodind=find((dt>0),1)-1;
         end
         
         
         if isempty(goodind)
             % there are no other good samples so skip the rest of the data
             isample(lastgood+1:end)=[];
             lastgood=[];
         else
             % adjust isample indicies to apply new offset;
             isample(lastgood+1:end)=isample(lastgood+1:end)+goodind;
             isample(isample>length(data)-4)=[];
             
             % any other faults?
             times1=index2time(data,isample);
             dt=diff(times1);
             if header.interval > 0
                 lastgood=find((dt<0)|(fix(dt)>header.interval),1)-1;
             else
                 lastgood=find((dt<0),1)-1;
             end
         end
     end
 
     % map data to uniform grid each row contains data channel, each column is a
     % observation.
     
     for i=1:len;
         D(i,:)=data(isample+i-1);
     end
 end

time1=D(1:4,:);
t1=bytecast(time1(:),'L','uint32');
t2=double(D(5,:))/100;
sample.time=mlstart+(t1(:)+t2(:))/86400;

cond=D(6:9,:);
sample.conductivity=bytecast(cond(:),'L','single');
% in units of mmho/cm IMOS needs S/m
sample.conductivity=sample.conductivity./10;

temp=D(10:13,:);
sample.temperature=bytecast(temp(:),'L','single');

pres=D(14:17,:);
sample.pressure=bytecast(pres(:),'L','single');

sal=D(18:21,:);
sample.salinity=bytecast(sal(:),'L','single');

sspd=D(22:25,:);
sample.soundSpeed=bytecast(sspd(:),'L','single');

volt=D(26:29,:);
sample.voltage=bytecast(volt(:),'L','single');

a1=D(30:31,:);  % turbidity if fitted with FLNTU
sample.analog1=bytecast(a1(:),'L',Options.analogUnit).*Options.analogScale;

a2=D(32:33,:);  % fluorescence if fitted with FLNTU
sample.analog2=bytecast(a2(:),'L',Options.analogUnit).*Options.analogScale;

a3=D(34:35,:); % PAR if fitted wit Biospherical par sensor
sample.analog3=bytecast(a3(:),'L',Options.analogUnit).*Options.analogScale;

ch4=D(36:37,:); % 
sample.analog4=bytecast(ch4(:),'L',Options.analogUnit).*Options.analogScale;

if len==41;
% if digital channel exists    
dig=D(38:41,:); % may be used by Aanderra Optode
sample.digital=bytecast(dig(:),'L','single');
end

end

function times=index2time(data,index)
% function to extract FSI times given the index of the start of the sample
% check for memory limitation
ctype=computer;
switch ctype
    case 'PCWIN'
        a=memory;
        % create a chunklength well within the memory limits 
        % (need at least 2*16*4 bytes so divide by 2*16*5 bytes to be sure)
        chunklength=a.MaxPossibleArrayBytes/(2*16*5);
    case 'GLNXA64'
        % assume 4 Gig limit
        chunklength=4e9/16;
    otherwise
        % try it all
        chunklength=length(index);
end

% 5 bytes required, but only first 4 needed to generate time in seconds since Jan 1 1970
tbytes=[0 1 2 3];

for i=1:chunklength:length(index);
    if (i+chunklength-1>length(index))
        iend=length(index);
    else
        iend=i+chunklength-1;
    end
    i = uint32(i);
    iend = uint32(iend);
    index_sub=index(i:iend);
    
    [IT TB]=meshgrid(index_sub,tbytes);
    % these matrices (IT and TB) are double precision by default and
    % will require  2*4*(chunklength)*16bytes memory storage each
    IT=IT+TB;
    clear TB;
    
    IT=IT(:);
    
    % 5th byte at index_sub+4 is simply 100ths of a second
    times(i:iend)=bytecast(data(IT),'L','uint32')+double(data(index_sub+4))/100;
end
end