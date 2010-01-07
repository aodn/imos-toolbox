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
    rethrow e;
  end
  
  % the first 220 bytes aer the header 
  % section, the rest sample data
  header  = parseHeader (data(1:220));
  samples = parseSamples(data(221:end), header);
  
  % create the sample_data struct
  sample_data = struct;
  sample_data.meta.instrument_make      = header.instrument_make;
  sample_data.meta.instrument_model     = header.instrument_model;
  sample_data.meta.instrument_serial_no = header.instrument_serial_no;
  
  sample_data.dimensions = {};
  sample_data.dimensions{1}.name = 'TIME';
  sample_data.dimensions{1}.data = samples.time;
  
  sample_data.variables = {};
  
  sample_data.variables{1}.name = 'TEMP';
  sample_data.variables{2}.name = 'CNDC';
  sample_data.variables{3}.name = 'PRES';
  sample_data.variables{4}.name = 'PSAL';
  sample_data.variables{5}.name = 'VOLT';
  
  sample_data.variables{1}.dimensions = [1];
  sample_data.variables{2}.dimensions = [1];
  sample_data.variables{3}.dimensions = [1];
  sample_data.variables{4}.dimensions = [1];
  sample_data.variables{5}.dimensions = [1];
  
  sample_data.variables{1}.data = samples.temperature;
  sample_data.variables{2}.data = samples.conductivity;
  sample_data.variables{3}.data = samples.pressure;
  sample_data.variables{4}.data = samples.salinity;
  sample_data.variables{5}.data = samples.voltage;
  
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

  header = struct;
  
  header.instrument_make      = 'Falmouth Scientific Instruments';
  header.instrument_model     = 'NXIC CTD';
  header.instrument_serial_no = num2str(bytecast(data(3:4), 'L', 'uint16'));
  
  second = double(data(18));
  minute = double(data(19));
  hour   = double(data(20));
  day    = double(data(21));
  month  = double(data(22));
  year   = double(data(23)) + 2000;
  
  header.startDate = datenum(year, month, day, hour, minute, second);
  
  % interval and record times are stored in seconds
  hour   = double(data(29));
  minute = double(data(30));
  second = double(data(31));
  header.interval = hour * 3600 + minute * 60 + second;
  
  hour   = double(data(32));
  minute = double(data(33));
  second = double(data(34));
  header.record = hour * 3600 + minute * 60 + second;
  
  header.calibrationDate = char(data(156:162)');
  header.sampleLength = double(data(200));
end

function samples = parseSamples(data, header)
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
  idx = 1;
  
  % estimate the number of samples in the file
  nSamples = ceil(length(data) / len);
  
  samples = struct;
  
  samples.time         = zeros(nSamples, 1);
  samples.conductivity = zeros(nSamples, 1);
  samples.temperature  = zeros(nSamples, 1);
  samples.pressure     = zeros(nSamples, 1);
  samples.salinity     = zeros(nSamples, 1);
  samples.voltage      = zeros(nSamples, 1);
  
  nSamples = 1;
  while idx <= length(data)-len+1
    
    sample = data(idx:idx+len-1);
    idx    = idx + len;
    
    samples.time(nSamples) = bytecast(sample(1:4), 'L', 'uint32');
    samples.time(nSamples) = samples.time(nSamples) + double(sample(5)) / 100;
    
    % sync check - required to handle corrupt files. One of the example 
    % data sets I am working from literally has an 8 byte gap in a sample
    % entry about 3/4 of the way through the file. 
    if nSamples > 1
      
      % Check the difference between the last time stamp and the current
      % one. If bigger than the interval period, assume that we've got a
      % corrupt file. We need to discard the previous sample, as the gap
      % may have been contained in that sample (meaning that some of its
      % data may be corrupt).
      lastSampleTime = samples.time(nSamples-1);
      timeDiff = samples.time(nSamples) - lastSampleTime;
      if (timeDiff < 0) || (timeDiff > header.interval)
        
        % 'delete' the previous sample
        nSamples = nSamples -  1;
        
        % The only way I can think of recovering is to scan ahead to find 
        % the next set of 5 bytes which represent a valid time stamp (i.e. 
        % one within the interval period of the last sample).
        while idx < length(data)-4
          
          idx = idx + 1;
          
          newTime = bytecast(data(idx:idx+3), 'L', 'uint32');
          newTime = newTime + double(data(idx+4)) / 100;
          timeDiff = newTime - lastSampleTime;
          if (timeDiff > 0) && (timeDiff < header.interval), break; end
          
        end
        
        % restart from the new index
        continue;
      end
    end
    
    block = bytecast(sample(6:29), 'L', 'single');
    
    samples.conductivity(nSamples) = block(1);
    samples.temperature (nSamples) = block(2);
    samples.pressure    (nSamples) = block(3);
    samples.salinity    (nSamples) = block(4);
    samples.voltage     (nSamples) = block(6);
    
    nSamples = nSamples + 1;
  end
  
  % we may have overallocated - trim the data vectors
  samples.time         = samples.time        (1:nSamples-1);
  samples.conductivity = samples.conductivity(1:nSamples-1);
  samples.temperature  = samples.temperature (1:nSamples-1);
  samples.pressure     = samples.pressure    (1:nSamples-1);
  samples.salinity     = samples.salinity    (1:nSamples-1);
  samples.voltage      = samples.voltage     (1:nSamples-1);
  
  % time: unix time  -> matlab time
  % cndc: mmho/cm    -> S/m
  samples.time         = (samples.time ./ 86400) + datenum('01-01-1970');
  samples.conductivity = samples.conductivity ./ 10;
end
