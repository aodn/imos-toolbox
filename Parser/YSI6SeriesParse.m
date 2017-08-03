function sample_data = YSI6SeriesParse( filename, mode )
%YSI6SERIESPARSE Parser for YSI 6 series MultiParameter data logger files.
%
% This function is able to parse .DAT files retrieved from YSI 6 series 
% data loggers. YSI do not provide a file format specification, so this 
% function relies upon reverse engineering efforts, which can be found at:
%
%   http://code.google.com/p/imos-toolbox/wiki/YSIBinaryFormat
%
% Inputs:
%   filename    - Cell array of input files; all but the first entry are
%                 ignored.
%   mode        - Toolbox data type mode.

% Outputs:
%   sample_data - Struct containing sample data.
%
% Author:       Paul McCarthy <paul.mccarthy@csiro.au>
% Contributor:  Guillaume Galibert <guillaume.galibert@utas.edu.au>
%

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
  
  if ~exist(filename, 'file'), error([filename ' does not exist']); end
  
  % read in the whole file into 'data'
  fid = -1;
  try
    fid = fopen(filename, 'rb');
    data = fread(fid, inf, '*uint8');
    fclose(fid);
  catch e
    if fid ~= -1, fclose(fid); end
    rethrow(e);
  end
  
  % read the record format from the header
  header = readHeader(data);
  
  % parse all of the records
  records = readRecords(header, data);
    
  sample_data.toolbox_input_file                = filename;
  sample_data.meta.instrument_make              = 'YSI';
  sample_data.meta.instrument_model             = '6 Series';
  sample_data.meta.instrument_serial_no         = '';
  sample_data.meta.instrument_sample_interval   = median(diff(records.time*24*3600));
  sample_data.meta.featureType                  = mode;
  
  sample_data.dimensions = {};
  sample_data.variables  = {};

  sample_data.dimensions{1}.name          = 'TIME';
  sample_data.dimensions{1}.typeCastFunc  = str2func(netcdf3ToMatlabType(imosParameters(sample_data.dimensions{1}.name, 'type')));
  sample_data.dimensions{1}.data          = sample_data.dimensions{1}.typeCastFunc(records.time');
  
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

  % convert time from seconds since 1 march 1984 00:00:00 
  % to days since 1 jan 0000 00:00:00
  sample_data.dimensions{1}.data = ...
    sample_data.dimensions{1}.data / 86400 + ...
    datenum('1-Mar-1984');
  
  fields = fieldnames(rmfield(records, 'time'));
  coordinates = 'TIME LATITUDE LONGITUDE NOMINAL_DEPTH';
  
  % copy all the data types across to the sample_data struct
  sample_data.variables = cell(length(fields), 1);
  for k = 1:length(fields)
    
    field = records.(fields{k});

    % dimensions definition must stay in this order : T, Z, Y, X, others;
    % to be CF compliant
    if any(strcmpi(field, {'LATITUDE', 'LONGITUDE'}))
        sample_data.variables{end+1}.dimensions = [];
    else
        sample_data.variables{end+1}.dimensions = 1;
    end
    
    switch fields{k}
      case 'temperature'
        sample_data.variables{end}.name           = 'TEMP';
        sample_data.variables{end}.typeCastFunc   = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{end}.name, 'type')));
        sample_data.variables{end}.data           = sample_data.variables{end}.typeCastFunc(field');
        
      % convert conductivity from mS/cm to S/m
      case 'cond'
        sample_data.variables{end}.name           = 'CNDC';
        sample_data.variables{end}.typeCastFunc   = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{end}.name, 'type')));
        sample_data.variables{end}.data           = sample_data.variables{end}.typeCastFunc(field' / 10.0);
        
      % convert conductivity from mS/cm to S/m
      case 'spcond'
        sample_data.variables{end}.name           = 'SPEC_CNDC';
        sample_data.variables{end}.typeCastFunc   = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{end}.name, 'type')));
        sample_data.variables{end}.data           = sample_data.variables{end}.typeCastFunc(field' / 10.0);
        
      % total dissolved solids
      case 'tds'
        sample_data.variables{end}.name           = 'TDS';    % non IMOS
        sample_data.variables{end}.typeCastFunc   = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{end}.name, 'type')));
        sample_data.variables{end}.data           = sample_data.variables{end}.typeCastFunc(field');
        
      case 'salinity'
        sample_data.variables{end}.name           = 'PSAL';
        sample_data.variables{end}.typeCastFunc   = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{end}.name, 'type')));
        sample_data.variables{end}.data           = sample_data.variables{end}.typeCastFunc(field');
        
      case 'ph'
        sample_data.variables{end}.name           = 'ACID';   % non IMOS
        sample_data.variables{end}.typeCastFunc   = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{end}.name, 'type')));
        sample_data.variables{end}.data           = sample_data.variables{end}.typeCastFunc(field');
        
      % oxidation reduction potential
      case 'orp'
        sample_data.variables{end}.name           = 'ORP';    % non IMOS
        sample_data.variables{end}.typeCastFunc   = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{end}.name, 'type')));
        sample_data.variables{end}.data           = sample_data.variables{end}.typeCastFunc(field');
        
      case 'depth'
        sample_data.variables{end}.name           = 'DEPTH';
        sample_data.variables{end}.typeCastFunc   = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{end}.name, 'type')));
        sample_data.variables{end}.data           = sample_data.variables{end}.typeCastFunc(field');
        
      % convert pressure from PSI to decibar
      case 'bp'
        sample_data.variables{end}.name           = 'PRES';
        sample_data.variables{end}.typeCastFunc   = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{end}.name, 'type')));
        sample_data.variables{end}.data = sample_data.variables{end}.typeCastFunc(field' / 1.45037738);
        
      case 'battery' % battery voltage
        sample_data.variables{end}.name           = 'VOLT';
        sample_data.variables{end}.typeCastFunc   = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{end}.name, 'type')));
        sample_data.variables{end}.data           = sample_data.variables{end}.typeCastFunc(field');
        
      % ug/L == mg/m^3
      case 'chlorophyll'
        sample_data.variables{end}.name           = 'CPHL';
        sample_data.variables{end}.typeCastFunc   = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{end}.name, 'type')));
        sample_data.variables{end}.data           = sample_data.variables{end}.typeCastFunc(field');
        sample_data.variables{end}.comment        = ['Artificial chlorophyll data '...
            'computed from bio-optical sensor raw counts measurements. The '...
            'fluorometre is equipped with a 470nm peak wavelength LED to irradiate and a '...
            'photodetector paired with an optical filter which measures everything '...
            'that fluoresces in the region above 630nm'...
            'Originally expressed in ug/l, 1l = 0.001m3 was assumed.'];
        
      % relative fluorescence unit
      %case 'chlorophyllRFU'
      %  sample_data.variables{end}.name = 'CPHL_RFU';
        
      case 'latitude'
        sample_data.variables{2}.data             = sample_data.variables{2}.typeCastFunc(field');
        
      case 'longitude'
        sample_data.variables{3}.data             = sample_data.variables{3}.typeCastFunc(field');
        
      case 'turbidity'
        sample_data.variables{end}.name           = 'TURB';
        sample_data.variables{end}.typeCastFunc   = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{end}.name, 'type')));
        sample_data.variables{end}.data           = sample_data.variables{end}.typeCastFunc(field');
        sample_data.variables{end}.comment        = 'Turbidity from 6136 sensor.';
        
      % % saturation
      case 'odo'
        sample_data.variables{end}.name           = 'DOXS';
        sample_data.variables{end}.typeCastFunc   = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{end}.name, 'type')));
        sample_data.variables{end}.data           = sample_data.variables{end}.typeCastFunc(field');
        sample_data.variables{end}.comment        = ...
          'Dissolved oxygen saturation from ROX optical sensor.';
        
      % mg/l
      case 'odo2'
        sample_data.variables{end}.name           = 'DOXY';
        sample_data.variables{end}.typeCastFunc   = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{end}.name, 'type')));
        sample_data.variables{end}.data           = sample_data.variables{end}.typeCastFunc(field');
        sample_data.variables{end}.comment        = ...
          'Dissolved oxygen from ROX optical sensor.';
    end
    sample_data.variables{end}.coordinates = coordinates;
  end
end


function header = readHeader(data)
%READHEADER Reads the file header and returns the header information in a
% struct.
%
  header = struct;

  header.recordFmt = [];
  
  % find the first record sync byte (0x42)
  idx = find(data == 66, 1);
  
  % read in all the entries in the header
  k = 1;
  while true
    
    % get the next entry
    entry = data(idx:idx+14);
    
    % we've run out of entries
    if entry(1) ~= 66, break; end
    
    % save the entry type
    header.recordFmt(k) = entry(4);
    
    % move to the next entry
    k   = k   + 1;
    idx = idx + 15;
    
  end
  
  header.recordStart  = idx;
  header.recordLength = 1 + (length(header.recordFmt) + 1) * 4;
  
end

function records = readRecords(header, data)
%READRECORDS Reads the records contained in the given vector of bytes.
%
  records = struct;
  
  rLen = header.recordLength;
  rIdx = header.recordStart;
  rFmt = header.recordFmt;
  rNum = 0;
  
  [~, ~, cpuEndianness] = computer;
  
  data = data(rIdx:end);
  
  while ~isempty(data)
    
    % pull the next record off the data array.
    record = data(1:rLen);
    data   = data(rLen+1:end);
    rNum   = rNum + 1;
    
    % missing sync byte - corrupt; fast
    % forward to the next sync byte (0x44)
    if record(1) ~= 68, 
      
      while ~isempty(data) && data(1) ~= 68, data = data(2:end); end
      continue;
    end
    
    % read time and element values
    records.time(rNum) = bytecast(record(2:5),   'L', 'uint32', cpuEndianness);
    vals               = bytecast(record(6:end), 'L', 'single', cpuEndianness);
    
    % save element values to correct data array
    for k = 1:length(rFmt)
      
      val = vals(k);
      
      switch(rFmt(k))
        
        case 1,   records.temperature   (rNum) = val; % 0x01
        case 4,   records.cond          (rNum) = val; % 0x04
        case 6,   records.spcond        (rNum) = val; % 0x06
        case 10,  records.tds           (rNum) = val; % 0x0A
        case 12,  records.salinity      (rNum) = val; % 0x0C
        case 18,  records.ph            (rNum) = val; % 0x12
        case 19,  records.orp           (rNum) = val; % 0x13
        case 22,  records.depth         (rNum) = val; % 0x16
        case 24,  records.bp            (rNum) = val; % 0x18
        case 28,  records.battery       (rNum) = val; % 0x1C
        case 193, records.chlorophyll   (rNum) = val; % 0xC1
        %case 194, records.chlorophyllRFU(rNum) = val;% 0xC2
        case 196, records.latitude      (rNum) = val; % 0xC4
        case 197, records.longitude     (rNum) = val; % 0xC5
        case 203, records.turbidity     (rNum) = val; % 0xCB
        case 211, records.odo           (rNum) = val; % 0xD3
        case 212, records.odo2          (rNum) = val; % 0xD4
      end
    end
    
    rIdx = rIdx + rLen;
  end
end
