function sample_data = SBE19Parse( filename )
%SBE19PARSE Parses a .cnv or .hex data file from a Seabird SBE19plus V2 
% CTD recorder.
%
% This function is able to read in a .cnv or .hex data file retrieved 
% from a Seabird SBE19plus V2 CTD recorder. It makes use of two lower level
% functions, readSBE19hex and readSBE19cnv. The files consist of up to
% three sections: 
%
%   - instrument header - header information as retrieved from the instrument. 
%                         These lines are prefixed with '*'.
%   - processed header  - header information generated by SBE Data Processing. 
%                         These lines are prefixed with '#'. Not contained
%                         in .hex files.
%   - data              - Rows of data.
%
% This function reads in the header sections, and delegates to the two file
% specific sub functions to process the data.
%
% Inputs:
%   filename    - cell array of files to import (only one supported).
%
% Outputs:
%   sample_data - Struct containing sample data.
%
% Author:       Paul McCarthy <paul.mccarthy@csiro.au>
% Contributor:  Brad Morris <b.morris@unsw.edu.au>
% 				Guillaume Galibert <guillaume.galibert@utas.edu.au>
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
  
  % read in every line in the file, separating
  % them out into each of the three sections
  instHeaderLines = {};
  procHeaderLines = {};
  dataLines       = {};
  try 
    
    fid = fopen(filename, 'rt');
    line = fgetl(fid);
    while ischar(line)
      
      line = deblank(line);
      if isempty(line)
        line = fgetl(fid);
        continue; 
      end
      
      if     line(1) == '*', instHeaderLines{end+1} = line;
      elseif line(1) == '#', procHeaderLines{end+1} = line;
      else                   dataLines{      end+1} = line;
      end
      
      line = fgetl(fid);
    end
    
    fclose(fid);
    
  catch e
    if fid ~= -1, fclose(fid); end
    rethrow(e);
  end
  
  % read in the raw instrument header
  instHeader = parseInstrumentHeader(instHeaderLines);
  procHeader = parseProcessedHeader( procHeaderLines);
  
  % use the appropriate subfunction to read in the data
  % assume that anything with a suffix not equal to .hex
  % is a .cnv file
  [~, ~, ext] = fileparts(filename);
  if strcmpi(ext, '.hex')
    data = readSBE19hex(dataLines, instHeader);
  else
    data = readSBE19cnv(dataLines, instHeader, procHeader);
  end
  
  % create sample data struct, 
  % and copy all the data in
  sample_data = struct;
  sample_data.meta.instHeader = instHeader;
  sample_data.meta.procHeader = procHeader;
  
  sample_data.meta.instrument_make = 'Seabird';
  if isfield(instHeader, 'instrument_model')
    sample_data.meta.instrument_model = instHeader.instrument_model;
  else
    sample_data.meta.instrument_model = 'SBE19';
  end
  
  if isfield(instHeader, 'instrument_firmware')
    sample_data.meta.instrument_firmware = instHeader.instrument_firmware;
  else
    sample_data.meta.instrument_firmware = '';
  end
  
  if isfield(instHeader, 'instrument_serial_no')
    sample_data.meta.instrument_serial_no = instHeader.instrument_serial_no;
  else
    sample_data.meta.instrument_serial_no = '';
  end
  
  time = genTimestamps(instHeader, data);
  
  if isfield(instHeader, 'sampleInterval')
    sample_data.meta.instrument_sample_interval = instHeader.sampleInterval;
  else
    sample_data.meta.instrument_sample_interval = median(diff(time*24*3600));
  end
  
  sample_data.dimensions = {};  
  sample_data.variables  = {};
  
  % dimensions creation
  sample_data.dimensions{1}.name = 'TIME';
  % generate time data from header information
  sample_data.dimensions{1}.data = time;
  sample_data.dimensions{2}.name = 'LATITUDE';
  sample_data.dimensions{2}.data = NaN;
  sample_data.dimensions{3}.name = 'LONGITUDE';
  sample_data.dimensions{3}.data = NaN;
  
  % scan through the list of parameters that were read 
  % from the file, and create a variable for each
  vars = fieldnames(data);
  for k = 1:length(vars)
    
    if strncmp('TIME', vars{k}, 4), continue; end
    
    % dimensions definition must stay in this order : T, Z, Y, X, others;
    % to be CF compliant
    sample_data.variables{end+1}.dimensions = [1 2 3];
    
    sample_data.variables{end  }.name       = vars{k};
    sample_data.variables{end  }.data       = data.(vars{k});
    
    if strncmp('PRES_REL', vars{k}, 8)
        % let's document the constant pressure atmosphere offset previously 
        % applied by SeaBird software on the absolute presure measurement
        sample_data.variables{end  }.applied_offset = -14.7*0.689476;
    end
  end
end

function header = parseInstrumentHeader(headerLines)
%PARSEINSTRUMENTHEADER Parses the header lines from a SBE19/37 .cnv file.
% Returns the header information in a struct.
%
% Inputs:
%   headerLines - cell array of strings, the lines of the header section.
%
% Outputs:
%   header      - struct containing information that was in the header
%                 section.
%
header = struct;

% there's no real structure to the header information, which
% is annoying. my approach is to use various regexes to search
% for info we want, and to ignore everything else. inefficient,
% but it's the nicest way i can think of

headerExpr   = '^\*\s*(SBE \S+|SeacatPlus)\s+V\s+(\S+)\s+SERIAL NO.\s+(\d+)';
%BDM (18/2/2011) - new header expressions to reflect newer SBE header info
headerExpr2  = '<HardwareData DeviceType=''(\S+)'' SerialNumber=''(\S+)''>';
scanExpr     = 'number of scans to average = (\d+)';
scanExpr2    = '*\s+ <ScansToAverage>(\d+)</ScansToAverage>';
memExpr      = 'samples = (\d+), free = (\d+), casts = (\d+)';
sampleExpr   = ['sample interval = (\d+) (\w+), ' ...
    'number of measurements per sample = (\d+)'];
sampleExpr2  ='*\s+ <Samples>(\d+)</Samples>';
profExpr     = '*\s+ <Profiles>(\d+)</Profiles>';
modeExpr     = 'mode = (\w+)';
pressureExpr = 'pressure sensor = (strain gauge|quartz)';
voltExpr     = 'Ext Volt ?(\d+) = (yes|no)';
outputExpr   = 'output format = (.*)$';
castExpr     = ['(?:cast|hdr)\s+(\d+)\s+' ...
    '(\d+ \w+ \d+ \d+:\d+:\d+)\s+'...
    'samples (\d+) to (\d+), (?:avg|int) = (\d+)'];
%Replaced castExpr to be specific to NSW-IMOS PH NRT
%Note: also replace definitions below in 'case 9'
%BDM 24/01/2011
castExpr2    ='Cast Time = (\w+ \d+ \d+ \d+:\d+:\d+)';
intervalExpr = 'interval = (.*): ([\d\.\+)$';
sbe38Expr    = 'SBE 38 = (yes|no), Gas Tension Device = (yes|no)';
optodeExpr   = 'OPTODE = (yes|no)';
voltCalExpr  = 'volt (\d): offset = (\S+), slope = (\S+)';
otherExpr    = '^\*\s*([^\s=]+)\s*=\s*([^\s=]+)\s*$';
firmExpr     ='<FirmwareVersion>(\S+)</FirmwareVersion>';

exprs = {...
    headerExpr   headerExpr2    scanExpr     ...
    scanExpr2    memExpr      sampleExpr   ...
    sampleExpr2  profExpr       modeExpr     pressureExpr ...
    voltExpr     outputExpr   ...
    castExpr     castExpr2   intervalExpr ...
    sbe38Expr    optodeExpr   ...
    voltCalExpr  otherExpr ...
    firmExpr};

for k = 1:length(headerLines)
    
    % try each of the expressions
    for m = 1:length(exprs)
        
        % until one of them matches
        tkns = regexp(headerLines{k}, exprs{m}, 'tokens');
        if ~isempty(tkns)
            
            % yes, ugly, but easiest way to figure out which regex we're on
            switch m
                
                % header
                case 1
                    header.instrument_model     = tkns{1}{1};
                    header.instrument_firmware  = tkns{1}{2};
                    header.instrument_serial_no = tkns{1}{3};
                    
                % header2
                case 2
                    header.instrument_model     = tkns{1}{1};
                    header.instrument_serial_no = tkns{1}{2};
                    
                % scan
                case 3
                    header.scanAvg = str2double(tkns{1}{1});
                    
                % scan2
                case 4
                    header.scanAvg = str2double(tkns{1}{1});
                    %%ADDED by Loz
                    header.castAvg = header.scanAvg;
                    
                % mem
                case 5
                    header.numSamples = str2double(tkns{1}{1});
                    header.freeMem    = str2double(tkns{1}{2});
                    header.numCasts   = str2double(tkns{1}{3});
                    
                % sample
                case 6
                    header.sampleInterval        = str2double(tkns{1}{1});
                    header.mesaurementsPerSample = str2double(tkns{1}{2});
                    
                % sample2
                case 7
                    header.castEnd = str2double(tkns{1}{1});
                
                % profile
                case 8
                    header.castNumber = str2double(tkns{1}{1});    
                    
                % mode
                case 9
                    header.mode = tkns{1}{1};
                    
                % pressure
                case 10
                    header.pressureSensor = tkns{1}{1};
                    
                % volt
                case 11
                    for n = 1:length(tkns),
                        header.(['ExtVolt' tkns{n}{1}]) = tkns{n}{2};
                    end
                    
                % output
                case 12
                    header.outputFormat = tkns{1}{1};
                    
                % cast
                case 13                    
                    header.castNumber = str2double(tkns{1}{1});
                    header.castDate   = datenum(   tkns{1}{2}, 'dd mmm yyyy HH:MM:SS');
                    header.castStart  = str2double(tkns{1}{3});
                    header.castEnd    = str2double(tkns{1}{4});
                    header.castAvg    = str2double(tkns{1}{5});
                    
                % cast2
                case 14                    
                    header.castDate   = datenum(tkns{1}{1}, 'mmm dd yyyy HH:MM:SS');
                    
                % interval
                case 15
                    header.resolution = tkns{1}{1};
                    header.interval   = str2double(tkns{1}{2});
                    
                % sbe38 / gas tension device
                case 16
                    header.sbe38 = tkns{1}{1};
                    header.gtd   = tkns{1}{2};
                    
                % optode
                case 17
                    header.optode = tkns{1}{1};
                    
                % volt calibration
                case 18
                    header.(['volt' tkns{1}{1} 'offset']) = str2double(tkns{1}{2});
                    header.(['volt' tkns{1}{1} 'slope'])  = str2double(tkns{1}{3});
                    
                % name = value
                case 19
                    header.(genvarname(tkns{1}{1})) = tkns{1}{2};
                    
                %firmware version
                case 20
                    header.instrument_firmware  = tkns{1}{1};
                    
            end
            break;
        end
    end
end
end

function header = parseProcessedHeader(headerLines)
%PARSEPROCESSEDHEADER Parses the data contained in the header added by SBE
% Data Processing. This includes the column layout of the data in the .cnv 
% file. 
%
% Inputs:
%   headerLines - Cell array of strings, the lines in the processed header 
%                 section.
%
% Outputs:
%   header      - struct containing information that was contained in the
%                 processed header section.
%

  header = struct;
  header.columns = {};
  
  nameExpr = 'name \d+ = (.+):';
  nvalExpr = 'nvalues = (\d+)';
  badExpr  = 'bad_flag = (.*)$';
  %BDM (18/02/2011) - added to get start time
  startExpr = 'start_time = (\w+ \d+ \d+ \d+:\d+:\d+)';
  
  for k = 1:length(headerLines)
    
    % try name expr
    tkns = regexp(headerLines{k}, nameExpr, 'tokens');
    if ~isempty(tkns)
      header.columns{end+1} = tkns{1}{1};
      continue; 
    end
    
    % then try nvalues expr
    tkns = regexp(headerLines{k}, nvalExpr, 'tokens');
    if ~isempty(tkns)
      header.nValues = str2double(tkns{1}{1});
      continue;
    end
    
    % then try bad flag expr
    tkns = regexp(headerLines{k}, badExpr, 'tokens');
    if ~isempty(tkns)
      header.badFlag = str2double(tkns{1}{1});
      continue;
    end
    
    %BDM (18/02/2011) - added to get start time
    % then try startTime expr
    tkns = regexp(headerLines{k}, startExpr, 'tokens');
    if ~isempty(tkns)
      header.startTime = datenum(tkns{1}{1}, 'mmm dd yyyy HH:MM:SS');
      continue;
    end
  end
end

function time = genTimestamps(instHeader, data)
%GENTIMESTAMPS Generates timestamps for the data. Horribly ugly. I shouldn't 
% have to have a function like this, but the .cnv files do not necessarily 
% provide timestamps for each sample.
%

  % time may have been present in the sample 
  % data - if so, we don't have to do any work
  if isfield(data, 'TIME'), time = data.TIME; return; end

  time = [];
  
  % To generate timestamps for the CTD data, we need to know:
  %   - start time
  %   - sample interval
  %   - number of samples
  %
  % The SBE19 header information does not necessarily provide all, or any
  % of this information. .
  %
  start    = 0;
  interval = 0.25;
  nSamples = 0;
    
  % figure out number of samples by peeking at the 
  % number of values in the first column of 'data'
  f = fieldnames(data);
  nSamples = length(data.(f{1}));
  
  % try and find a start date - use castDate if present
  if isfield(instHeader, 'castDate')
    start = instHeader.castDate;
  end
  
  % if scanAvg field is present, use it to determine the interval
  if isfield(instHeader, 'scanAvg')
    
    interval = (0.25 * instHeader.scanAvg) / 86400;
  end
  
  % if one of the columns is 'Scan Count', use the 
  % scan count number as the basis for the timestamps 
  if isfield(data, 'ScanCount')
    
    time = ((data.ScanCount - 1) ./ 345600) + cStart;
  
  % if scan count is not present, calculate the 
  % timestamps from start, end and interval
  else
    
    time = (start:interval:start + (nSamples - 1) * interval)';
  end
end


