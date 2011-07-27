function sample_data = YSI6SeriesParse( filename )
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

% Outputs:
%   sample_data - Struct containing sample data.
%
% Author: Paul McCarthy <paul.mccarthy@csiro.au>
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
  error(nargchk(1,1,nargin));

  if ~iscellstr(filename)
    error('filename must be a cell array of strings'); 
  end

  % only one file supported currently
  filename = filename{1};
  
  if ~exist(filename, 'file'), error([filename ' does not exist']); end
  
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
  
  % read the record format from the header
  header = readHeader(data);
  
  % parse all of the records
  records = readRecords(header, data);
  
  sample_data.meta.instrument_make      = 'YSI';
  sample_data.meta.instrument_model     = '6 Series';
  sample_data.meta.instrument_serial_no = '';
  sample_data.meta.instrument_sample_interval = NaN;
  
  % dimensions definition must stay in this order : T, Z, Y, X, others;
  % to be CF compliant
  sample_data.dimensions{1}.name = 'TIME';
  sample_data.dimensions{1}.data = records.time';
  
  % convert time from seconds since 1 march 1984 00:00:00 
  % to days since 1 jan 0000 00:00:00
  sample_data.dimensions{1}.data = ...
    sample_data.dimensions{1}.data / 86400 + ...
    datenum('1-Mar-1984');
  
  % copy all the data types across to the sample_data struct
  fields = fieldnames(rmfield(records, 'time'));
  sample_data.variables = cell(length(fields), 1);
  for k = 1:length(fields)
    
    field = getfield(records, fields{k});

    sample_data.variables{k}.data       = field'; 
    sample_data.variables{k}.dimensions = [1];
    
    switch fields{k}
      
      case 'temperature'
        sample_data.variables{k}.name = 'TEMP';
        
      % convert conductivity from mS/cm to S/m
      case 'cond'
        sample_data.variables{k}.name = 'CNDC_1';
        sample_data.variables{k}.data = ...
          sample_data.variables{k}.data / 10.0;
        
      % convert conductivity from mS/cm to S/m
      case 'spcond'
        sample_data.variables{k}.name = 'CNDC_2';
        sample_data.variables{k}.data = ...
          sample_data.variables{k}.data / 10.0;
        sample_data.variables{k}.comment = 'Specific Conductance';
        
      % total dissolved solids
      case 'tds'
        sample_data.variables{k}.name = 'TDS';    % non IMOS
        
      case 'salinity'
        sample_data.variables{k}.name = 'PSAL';
        
      case 'ph'
        sample_data.variables{k}.name = 'ACID';   % non IMOS
      
      % oxidation reduction potential
      case 'orp'
        sample_data.variables{k}.name = 'ORP';    % non IMOS
        
      case 'depth'
        sample_data.variables{k}.name = 'DEPTH';
        
      % convert pressure from PSI to decibar
      case 'bp'
        sample_data.variables{k}.name = 'PRES';
        sample_data.variables{k}.data = ...
          sample_data.variables{k}.data / 1.45037738;
        
      case 'battery'
        sample_data.variables{k}.name = 'VOLT';   % non IMOS
      
      % ug/L == mg/m^3
      case 'chlorophyll'
        sample_data.variables{k}.name = 'CPHL';
        
      %case 'chlorophyllRFU'
      %  sample_data.variables{k}.name = 'CPHL_RFU';
        
      case 'latitude'
        sample_data.variables{k}.name = 'LATITUDE';
        
      case 'longitude'
        sample_data.variables{k}.name = 'LONGITUDE';
        
      case 'turbidity'
        sample_data.variables{k}.name    = 'TURB';
        sample_data.variables{k}.comment = 'Turbidity from 6136 sensor';
        
      % convert dissolved oxygen from % to kg/m^3
      case 'odo'
        sample_data.variables{k}.name    = 'DOXY_1';
        sample_data.variables{k}.comment = ...
          'Dissolved oxygen from Rapid Pulse Sensor (%)';
        sample_data.variables{k}.data = ...
          sample_data.variables{k}.data * 10000.0;
        
      % mg/L == kg/m^3
      case 'odo2'
        sample_data.variables{k}.name    = 'DOXY_2';
        sample_data.variables{k}.comment = ...
          'Dissolved oxygen from Rapid Pulse Sensor (mg/L)';
    end
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
  
  data = data(rIdx:end);
  
  while ~isempty(data)
    
    % pull the next record off the data array.
    record = data(1:rLen);
    data   = data(rLen+1:end);
    rNum   = rNum + 1;
    
    % missing sync byte - corrupt; fast
    % forward to the next sync byte
    if record(1) ~= 68, 
      
      while ~isempty(data) && data(1) ~= 68, data = data(2:end); end
      continue;
    end
    
    % read time and element values
    records.time(rNum) = bytecast(record(2:5),   'L', 'uint32');
    vals               = bytecast(record(6:end), 'L', 'single');
    
    % save element values to correct data array
    for k = 1:length(rFmt)
      
      val = vals(k);
      
      switch(rFmt(k))
        
        case 1,   records.temperature   (rNum) = val; % 0x01
        case 4,   records.cond          (rNum) = val; % 0x04
        case 6,   records.spcond        (rNum) = val; % 0x06
        case 10,  records.tds           (rNum) = val; % 0x0A
        case 12,  records.salinity      (rNum) = val; % 0x1C
        case 18,  records.ph            (rNum) = val; % 0x12
        case 19,  records.orp           (rNum) = val; % 0x13
        case 22,  records.depth         (rNum) = val; % 0x16
        case 24,  records.bp            (rNum) = val; % 0x18
        case 28,  records.battery       (rNum) = val; % 0x1C
        case 193, records.chlorophyll   (rNum) = val; % 0xC1
        %case 194, records.chlorophyllRFU(rNum) = val; % 0xC2
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
