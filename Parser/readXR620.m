function sample_data = readXR620( filename, mode )
%readXR620 Parses a data file retrieved from an RBR XR620 or XR420 depth 
% logger.
%
% This function is able to read in a single file retrieved from an RBR
% XR620 or RX420 data logger in Engineering unit .txt format (processed 
% using Ruskin software). The pressure data is returned in a sample_data 
% struct. Other RBR instrument like TDR 2050, TR 1060 might be supported
% when processed with Ruskin software.
%
% Inputs:
%   filename    - Cell array containing the name of the file to parse.
%   mode        - Toolbox data type mode.
%
% Outputs:
%   sample_data - Struct containing imported sample data.
%
% Author : Guillaume Galibert <guillaume.galibert@utas.edu.au>

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
  narginchk(2,2);
  
  if ~ischar(filename)  
    error('filename must be a string'); 
  end
  
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

  sample_data.toolbox_input_file                = filename;
  sample_data.meta.instrument_make              = header.make;
  sample_data.meta.instrument_model             = header.model;
  sample_data.meta.instrument_firmware          = header.firmware;
  sample_data.meta.instrument_serial_no         = header.serial;
  sample_data.meta.instrument_sample_interval   = median(diff(data.time*24*3600));
  sample_data.meta.featureType                  = mode;
  
  sample_data.dimensions = {};  
  sample_data.variables  = {};
  
  switch mode
      case 'profile'
          % dimensions creation
          iVarPRES = NaN;
          iVarDEPTH = NaN;
          isZ = false;
          vars = fieldnames(data);
          nVars = length(vars);
          for k = 1:nVars
              if strcmpi('DEPTH', vars{k})
                  iVarDEPTH = k;
                  isZ = true;
                  break;
              end
              if strcmpi('PRES', vars{k})
                  iVarPRES = k;
                  isZ = true;
              end
              if ~isnan(iVarDEPTH) && ~isnan(iVarPRES), break; end
          end
          
          if ~isZ
              error('There is no pressure or depth information in this file to use it in profile mode');
          end
          
          depthComment = '';
          if ~isnan(iVarDEPTH)
              iVarZ = iVarDEPTH;
              depthData = data.(vars{iVarDEPTH});
          else
              iVarZ = iVarPRES;
              depthData = data.(vars{iVarPRES} - gsw_P0/10^4);
              presComment = ['abolute '...
                  'pressure measurements to which a nominal '...
                  'value for atmospheric pressure (10.1325 dbar) '...
                  'has been substracted'];
              depthComment  = ['Depth computed from '...
                  presComment ', assuming 1dbar ~= 1m.'];
          end
          
          % let's distinguish descending/ascending parts of the profile
          nData = length(data.(vars{iVarZ}));
          zMax = max(data.(vars{iVarZ}));
          posZMax = find(data.(vars{iVarZ}) == zMax, 1, 'last'); % in case there are many times the max value
          iD = [true(posZMax, 1); false(nData-posZMax, 1)];
          
          nD = sum(iD);
          nA = sum(~iD);
          MAXZ = max(nD, nA);
          
          dNaN = nan(MAXZ-nD, 1);
          aNaN = nan(MAXZ-nA, 1);
          
          if nA == 0
              sample_data.dimensions{1}.name            = 'DEPTH';
              sample_data.dimensions{1}.typeCastFunc    = str2func(netcdf3ToMatlabType(imosParameters(sample_data.dimensions{1}.name, 'type')));
              sample_data.dimensions{1}.data            = sample_data.dimensions{1}.typeCastFunc(depthData);
              sample_data.dimensions{1}.comment         = depthComment;
              sample_data.dimensions{1}.axis            = 'Z';
              
              sample_data.variables{end+1}.name         = 'PROFILE';
              sample_data.variables{end}.typeCastFunc   = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{end}.name, 'type')));
              sample_data.variables{end}.data           = sample_data.variables{end}.typeCastFunc(1);
              sample_data.variables{end}.dimensions     = [];
          else
              sample_data.dimensions{1}.name            = 'MAXZ';
              sample_data.dimensions{1}.typeCastFunc    = str2func(netcdf3ToMatlabType(imosParameters(sample_data.dimensions{1}.name, 'type')));
              sample_data.dimensions{1}.data            = sample_data.dimensions{1}.typeCastFunc(1:1:MAXZ);
              
              sample_data.dimensions{2}.name            = 'PROFILE';
              sample_data.dimensions{2}.typeCastFunc    = str2func(netcdf3ToMatlabType(imosParameters(sample_data.dimensions{2}.name, 'type')));
              sample_data.dimensions{2}.data            = sample_data.dimensions{2}.typeCastFunc([1, 2]);
              
              disp(['Warning : ' sample_data.toolbox_input_file ...
                  ' is not IMOS CTD profile compliant. See ' ...
                  'http://help.aodn.org.au/help/sites/help.aodn.org.au/' ...
                  'files/ANMN%20CTD%20Processing%20Procedures.pdf']);
          end
          
          % Add TIME, DIRECTION and POSITION infos
          descendingTime = data.time(iD);
          descendingTime = descendingTime(1);
          
          if nA == 0
              ascendingTime = [];
              dimensions = [];
          else
              ascendingTime = data.time(~iD);
              ascendingTime = ascendingTime(1);
              dimensions = 2;
          end
          
          sample_data.variables{end+1}.dimensions   = dimensions;
          sample_data.variables{end}.name         = 'TIME';
          sample_data.variables{end}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{end}.name, 'type')));
          sample_data.variables{end}.data         = sample_data.variables{end}.typeCastFunc([descendingTime, ascendingTime]);
          sample_data.variables{end}.comment      = 'First value over profile measurement.';
          
          sample_data.variables{end+1}.dimensions = dimensions;
          sample_data.variables{end}.name         = 'DIRECTION';
          sample_data.variables{end}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{end}.name, 'type')));
          if nA == 0
              sample_data.variables{end}.data     = {'D'};
          else
              sample_data.variables{end}.data     = {'D', 'A'};
          end
          
          sample_data.variables{end+1}.dimensions = dimensions;
          sample_data.variables{end}.name         = 'LATITUDE';
          sample_data.variables{end}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{end}.name, 'type')));
          if nA == 0
              sample_data.variables{end}.data     = sample_data.variables{end}.typeCastFunc(NaN);
          else
              sample_data.variables{end}.data     = sample_data.variables{end}.typeCastFunc([NaN, NaN]);
          end
          
          sample_data.variables{end+1}.dimensions = dimensions;
          sample_data.variables{end}.name         = 'LONGITUDE';
          sample_data.variables{end}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{end}.name, 'type')));
          if nA == 0
              sample_data.variables{end}.data     = sample_data.variables{end}.typeCastFunc(NaN);
          else
              sample_data.variables{end}.data     = sample_data.variables{end}.typeCastFunc([NaN, NaN]);
          end
          
          sample_data.variables{end+1}.dimensions = dimensions;
          sample_data.variables{end}.name         = 'BOT_DEPTH';
          sample_data.variables{end}.comment      = 'Bottom depth measured by ship-based acoustic sounder at time of CTD cast.';
          sample_data.variables{end}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{end}.name, 'type')));
          if nA == 0
              sample_data.variables{end}.data     = sample_data.variables{end}.typeCastFunc(NaN);
          else
              sample_data.variables{end}.data     = sample_data.variables{end}.typeCastFunc([NaN, NaN]);
          end
          
          % Manually add variable DEPTH if multiprofile and doesn't exit
          % yet
          if isnan(iVarDEPTH) && (nA ~= 0)
              sample_data.variables{end+1}.dimensions = [1 2];
              
              sample_data.variables{end}.name         = 'DEPTH';
              sample_data.variables{end}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{end}.name, 'type')));
              
              % we need to padd data with NaNs so that we fill MAXZ
              % dimension
              sample_data.variables{end}.data         = sample_data.variables{end}.typeCastFunc([[depthData(iD); dNaN], [depthData(~iD); aNaN]]);
              
              sample_data.variables{end}.comment      = depthComment;
              sample_data.variables{end}.axis         = 'Z';
          end
          
          % scan through the list of parameters that were read
          % from the file, and create a variable for each
          for k = 1:nVars
              % we skip TIME and DEPTH
              if strcmpi('TIME', vars{k}), continue; end
              if strcmpi('DEPTH', vars{k}) && (nA == 0), continue; end
              
              [name,  data.(vars{k}), comment.(vars{k})] = convertXRengVar(vars{k},  data.(vars{k}), mode);
              
              if ~isempty(name)
                  sample_data.variables{end+1}.dimensions = [1 dimensions];
                  
                  sample_data.variables{end}.name         = name;
                  sample_data.variables{end}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{end}.name, 'type')));
                  if nA == 0
                      sample_data.variables{end  }.data   = sample_data.variables{end}.typeCastFunc(data.(vars{k})(iD));
                  else
                      % we need to padd data with NaNs so that we fill MAXZ
                      % dimension
                      sample_data.variables{end  }.data   = sample_data.variables{end}.typeCastFunc([[data.(vars{k})(iD); dNaN], [data.(vars{k})(~iD); aNaN]]);
                  end
                  sample_data.variables{end}.comment    = comment.(vars{k});
                  
                  if ~any(strcmpi(vars{k}, {'TIME', 'DEPTH'}))
                      sample_data.variables{end  }.coordinates = 'TIME LATITUDE LONGITUDE DEPTH';
                  end
              end   
          end                   
          
      case 'timeSeries'
          sample_data.dimensions{1}.name            = 'TIME';
          sample_data.dimensions{1}.typeCastFunc    = str2func(netcdf3ToMatlabType(imosParameters(sample_data.dimensions{1}.name, 'type')));
          sample_data.dimensions{1}.data            = sample_data.dimensions{1}.typeCastFunc(data.time);
          
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
          
          % copy variable data over
          data = rmfield(data, 'time');
          fields = fieldnames(data);
          coordinates = 'TIME LATITUDE LONGITUDE NOMINAL_DEPTH';
          
          for k = 1:length(fields)
              
              [name,  data.(fields{k}), comment.(fields{k})] = convertXRengVar(fields{k},  data.(fields{k}), mode);
              
              if ~isempty(name)
                  % dimensions definition must stay in this order : T, Z, Y, X, others;
                  % to be CF compliant
                  sample_data.variables{end+1}.dimensions = 1;
                  sample_data.variables{end}.name         = name;
                  sample_data.variables{end}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{end}.name, 'type')));
                  sample_data.variables{end}.data         = sample_data.variables{end}.typeCastFunc(data.(fields{k}));
                  sample_data.variables{end}.coordinates  = coordinates;
                  sample_data.variables{end}.comment      = comment.(fields{k});
              end
          end
      
    end
end
  
function header = readHeader(fid)
%READHEADER Reads the header section from the top of the file.

  header = struct;
  lines  = {};
  
  line = fgetl(fid);
  
  while isempty(strfind(line, 'Date & Time')) && ischar(line)
    lines = [lines line];
    line  = fgetl(fid);
  end
  
  header.variables = strtrim(line);
  
  % use regexp to read in all the important header information
  exprs = {
    ['^Model=+' '(\S+)$']
    ['^Firmware=+' '(\S+)$']
    ['^Serial=+' '(\S+)$']
    ['^LoggingStartDate=+' '(\S+)$']
    ['^LoggingStartTime=+' '(\S+\s?\S+)$']
    ['^LoggingEndDate=+' '(\S+)$']
    ['^LoggingEndTime=+' '(\S+\s?\S+)$']
    ['^LoggingSamplingPeriod=+' '(\d+)Hz']
    ['^LoggingSamplingPeriod=+' '(\d\d:\d\d:\d\d)']
    ['^NumberOfChannels=+' '(\d+)']
    ['^CorrectionToConductivity=+' '(\d+)']
    ['^NumberOfSamples=+' '(\d+)']
  };
  
  startDate = '';
  startTime = '';
  endDate = '';
  endTime = '';

  for k = 1:length(lines)
    
    % try exprs until we get a match
    for m = 1:length(exprs)
    
      % check for the line containing start sample time
      tkns = regexp(lines{k}, exprs{m}, 'tokens');
      
      if isempty(tkns), continue; end
      
      header.make     = 'RBR';
      
      switch m
          % instrument information
          case 1
              header.model    = genvarname(tkns{1}{1});
          case 2
              header.firmware = tkns{1}{1};
          case 3
              header.serial   = tkns{1}{1};
              
          % start of sampling
          case 4
              startDate    = tkns{1}{1};
          case 5
              startTime    = tkns{1}{1};
              
          % end of sampling
          case 6
              endDate    = tkns{1}{1};
          case 7
              endTime    = tkns{1}{1};
              
          % sample interval
          case 8
              header.interval = 1/str2double(tkns{1}{1});
              
          % other sample interval
          case 9
              [~, ~, ~, H, MN, S] = datevec(datenum(tkns{1}{1}, 'HH:MM:SS'));
              header.interval = H*3600 + MN*60 + S;
              
          % number of channels
          case 10
              header.channels = str2double(tkns{1}{1});
          
          % correction to conductivity
          case 11
              header.correction  = tkns{1}{1};
              
          % number of samples
          case 12
              header.samples  = str2double(tkns{1}{1});
      end
    end
  end
  
  if ~isempty(startDate) && ~isempty(startTime) % ruskin v1.5
      if length(startDate) == 8 
          header.start    = datenum([startDate ' ' startTime],  'yy/mm/dd HH:MM:SS.FFF');
      else
          header.start    = datenum([startDate ' ' startTime],  'yyyy/mmm/dd HH:MM:SS.FFF');
      end
  elseif isempty(startDate) && ~isempty(startTime) % ruskin v1.7
      header.start    = datenum(startTime,  'dd-mmm-yyyy HH:MM:SS.FFF');
  end
  
  if ~isempty(endDate) && ~isempty(endTime) % ruskin v1.5
      if length(endDate) == 8
          header.end      = datenum([endDate   ' ' endTime],    'yy/mm/dd HH:MM:SS.FFF');
      else
          header.end      = datenum([endDate   ' ' endTime],    'yyyy/mmm/dd HH:MM:SS.FFF');
      end
  elseif isempty(endDate) && ~isempty(endTime) % ruskin v1.7
      header.end    = datenum(endTime,  'dd-mmm-yyyy HH:MM:SS.FFF');
  end
  
end

function data = readData(fid, header)
%READDATA Reads the sample data from the file.

  data = struct;
  
  % get the column names
  % replace ' & ' or ' ' delimited variable names with a '|' delimiter
  header.variables = regexprep(header.variables, '(\s+\&\s+|\s+)', '|');
  cols = textscan(header.variables, '%s', ...
      'Delimiter', '|', ...
      'MultipleDelimsAsOne', true); % header.variables might start by a delimiter
  cols = cols{1};
  
  % rename variables with '-', ' ', '&', '(', ')' as Matlab doesn't allow 
  % them within a structure name
  cols = strrep(cols, '-', '');
  cols = strrep(cols, ' ', '');
  cols = strrep(cols, '(', '');
  cols = strrep(cols, ')', '');
  cols = strrep(cols, '&', '');
  
  % first 2 columns are date and time
  fmt  = '%s %s';
  
  % figure out number of columns from the number of channels
  fmt = [fmt repmat(' %f', [1, length(cols)-2])];
  
  % read in the sample data
  samples = textscan(fid, fmt, 'treatAsEmpty', {'null'});
  
  for k = 1:length(cols)
      % check that all columns have the same length. If not correct it.
      if k>1
          while length(samples{k}) < lenData
              samples{k}(end+1) = NaN;
          end
      else
          lenData = length(samples{k});
      end
      
      % save sample data into the data struct, 
      % using  column names as struct field names
      data.(cols{k}) = samples{k}; 
  end
  
  if length(data.Date{1}) == 8 
      data.time = datenum(data.Date, 'yy/mm/dd') + datenum(data.Time, 'HH:MM:SS.FFF') - datenum('00:00:00', 'HH:MM:SS');
  else
      if isempty(strfind(data.Date{1}, '-'))
          data.time = datenum(data.Date, 'yyyy/mmm/dd') + datenum(data.Time, 'HH:MM:SS.FFF') - datenum('00:00:00', 'HH:MM:SS');
      else
          % Ruskin version number <= 1.12 date format 'dd-mmm-yyyy'
          % Ruskin version number 1.13 date format 'yyyy-mm-dd'
          % can either do some simple date format test or see if datenum
          % can figure it out
          data.time = datenum(data.Date) + datenum(data.Time, 'HH:MM:SS.FFF') - datenum('00:00:00', 'HH:MM:SS');
      end
  end
  
  data = rmfield(data, 'Date');
  data = rmfield(data, 'Time');
end