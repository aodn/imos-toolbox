function sample_data = XR420Parse( filename )
%XR420PARSE Parses a data file retrieved from an RBR XR420 depth logger.
%
% This function is able to read in a single file retrieved from an RBR
% XR420 data logger. The pressure data is returned in a sample_data
% struct.
%
% Inputs:
%   filename    - Cell array containing the name of the file to parse.
%
% Outputs:
%   sample_data - Struct containing imported sample data.
%
% Contributor : Laurent Besnard <laurent.besnard@utas.edu.au>
% 				Guillaume Galibert <guillaume.galibert@utas.edu.au>

%
% Copyright (c) 2010, eMarine Information Infrastructure (eMII) and Integrated 
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
  
  % only one file supported
  filename = filename{1};
  
  % open the file, and read in the header and data
  try 
    
    fid    = fopen(filename, 'rt');
    header = readHeader(fid);
    data   = readData(fid, header);
    fclose(fid);
  
  catch e
    if fid ~= -1, fclose(fid); end
    rethrow(e);
  end
  
  % copy all of the information over to the sample data struct
  sample_data = struct;
  
  sample_data.meta.instrument_make      = header.make;
  sample_data.meta.instrument_model     = header.model;
  sample_data.meta.instrument_firmware  = header.firmware;
  sample_data.meta.instrument_serial_no = header.serial;
  sample_data.meta.instrument_sample_interval = 24*3600*header.interval;
  sample_data.meta.correction           = header.correction;
  
  % dimensions definition must stay in this order : T, Z, Y, X, others;
  % to be CF compliant
  sample_data.dimensions{1}.name = 'TIME';
  sample_data.dimensions{1}.data = data.time;
  sample_data.dimensions{2}.name = 'LATITUDE';
  sample_data.dimensions{2}.data = NaN;
  sample_data.dimensions{3}.name = 'LONGITUDE';
  sample_data.dimensions{3}.data = NaN;
  
  % copy variable data over
  data = rmfield(data, 'time');
  fields = fieldnames(data);
  
  for k = 1:length(fields)
    
      switch fields{k}
          
          case 'Cond', name = 'CNDC';
          case 'Temp', name = 'TEMP';
          case 'Pres', name = 'PRES';
          case 'FlCa', name = 'CPHL';
      end
    
      sample_data.variables{k}.name       = name;
      sample_data.variables{k}.data       = data.(fields{k});
      sample_data.variables{k}.dimensions = [1 2 3];
  end
end
  
function header = readHeader(fid)
%READHEADER Reads the header section from the top of the file.

  header = struct;
  lines  = {};
  
  line = fgetl(fid);
  
  % a single blank line separates the header from the data
  while ~isempty(line)
    
    lines = [lines line];
    line  = fgetl(fid);
  end
  
  % use regexp to read in all the important header information
  exprs = {
     '^([^ ]+) +([^ ]+) +([\d\.]+) +(\d+) '
    ['^Logging start +' '(\d\d/\d\d/\d\d \d\d:\d\d:\d\d)$']
    ['^Logging end +'   '(\d\d/\d\d/\d\d \d\d:\d\d:\d\d)$']
    ['^Sample period +'                '(\d\d:\d\d:\d\d)$']
     '^Correction to conductivity: (.*)$'
     '^Number of channels = +(\d)+, number of samples = +(\d)+'
  };
  
  for k = 1:length(lines)
    
    % try exprs until we get a match
    for m = 1:length(exprs)
    
      % check for the line containing start sample time
      tkns = regexp(lines{k}, exprs{m}, 'tokens');
      
      if isempty(tkns), continue; end
      
      switch m
        % instrument information
        case 1, header.make     = tkns{1}{1};
                header.model    = tkns{1}{2};
                header.firmware = tkns{1}{3};
                header.serial   = tkns{1}{4};
        
        % start of sampling
        case 2, header.start    = datenum(tkns{1}{1},   'yy/mm/dd HH:MM:SS');
        
        % end of sampling
        case 3, header.end      = datenum(tkns{1}{1},   'yy/mm/dd HH:MM:SS');
        
        % sample interval
        case 4, tkns{1}{1}      = ['0000/01/00 ' tkns{1}{1}];
                header.interval = datenum(tkns{1}{1}, 'yyyy/mm/dd HH:MM:SS');
        
        % comment
        case 5, header.correction  = tkns{1}{1};
        
        % number of channels, number of samples
        case 6, header.channels = str2double(tkns{1}{1});
                header.samples  = str2double(tkns{1}{2});
      end
    end
  end
end

function data = readData(fid, header)
%READDATA Reads the sample data from the file.

  data = struct;
  
  fmt  = '';
  
  % figure out number of columns from the number of channels
  for k = 1:header.channels, fmt = [fmt '%n']; end
  
  cols = {};
  
  % get the column names
  colLine = fgetl(fid);
  [col, colLine] = strtok(colLine);
  while ~isempty(colLine)
    
    cols           = [cols col];
    [col, colLine] = strtok(colLine);
  end
  cols{4}='FlCa'; %renaim FlC-a to FlCa because Matlbal doesn't understand - whitin a structure name
  % read in the sample data
  samples = textscan(fid, fmt);
  
  % save sample data into the data struct, 
  % using  column names as struct field names
  for k = 1:length(cols), data.(cols{k}) = samples{k}; end
  
  % regenerate interval from start/end time, and number of 
  % samples, rather than using the one listed in the header
  nSamples = length(samples{1});
  
 %This section is overwriting the interval with an incorrect value so can
 %we comment it out
 % header.interval = (header.end - header.start) / (nSamples-1); 
  
  % generate time stamps from start/interval/end
  data.time = header.start:header.interval:header.end;
  data.time = data.time(1:length(samples{1}))';
end