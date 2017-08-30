function sample_data = infinitySDLoggerParse( filename, mode )
%infinitySDLogger Parses a .csv data file retrieved from a JFE Infinity ACLW-USB logger.
%
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
  
% ensure that there is one or two arguments
narginchk(1,2);

% and that it is a cell array of strings
if ~iscellstr(filename), error('filename must be a cell array of strings'); end

% only one file supported currently
filename = filename{1};
if ~ischar(filename), error('filename must contain a string'); end

% open the file, and read in the data
try
    fid = fopen(filename, 'rt');
    rawText = textscan(fid, '%s', 'Delimiter', '');
    fclose(fid);
    
    [header, iData] = readHeader(rawText{1});
    data            = readData(rawText{1}(iData:end));
catch e
    if fid ~= -1, fclose(fid); end
    rethrow(e);
end

% copy all of the information over to the sample data struct
sample_data = struct;

sample_data.toolbox_input_file              = filename;
sample_data.meta.instrument_make            = 'JFE';
sample_data.meta.instrument_model           = header.SondeName;
sample_data.meta.instrument_serial_no       = header.SondeNo;
sample_data.meta.instrument_sample_interval = median(diff(data.TIME.values*24*3600));
sample_data.meta.featureType                = mode;

sample_data.dimensions = {};
sample_data.variables  = {};

sample_data.dimensions{1}.name              = 'TIME';
sample_data.dimensions{1}.typeCastFunc      = str2func(netcdf3ToMatlabType(imosParameters(sample_data.dimensions{1}.name, 'type')));
sample_data.dimensions{1}.data              = sample_data.dimensions{1}.typeCastFunc(data.TIME.values);

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
data = rmfield(data, 'TIME');
fields = fieldnames(data);

for k = 1:length(fields)
    name = fields{k};
    
    % dimensions definition must stay in this order : T, Z, Y, X, others;
    % to be CF compliant
    sample_data.variables{end+1}.dimensions = 1;
    sample_data.variables{end}.name         = name;
    sample_data.variables{end}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{end}.name, 'type')));
    sample_data.variables{end}.data         = sample_data.variables{end}.typeCastFunc(data.(fields{k}).values);
    sample_data.variables{end}.coordinates  = 'TIME LATITUDE LONGITUDE NOMINAL_DEPTH';
    sample_data.variables{end}.comment      = data.(fields{k}).comment;
end
end

function [header, iData] = readHeader(rawText)
%READHEADER Reads the header from the file.
  header = struct;
  iData = [];
  
  startHeader = '[Head]';
  endHeader = '[Item]';
  fmtHeader  = '%s%s';
  delimHeader = '=';
  
  iStartHeader = find(strcmp(startHeader, rawText)) + 1;
  iEndHeader = find(strcmp(endHeader, rawText)) - 1;
  iData = iEndHeader + 1;
  
  headerCell = rawText(iStartHeader:iEndHeader);
  nFields = length(headerCell);
  for i=1:nFields
      tuple = textscan(headerCell{i}, fmtHeader, 'Delimiter', delimHeader);
      if ~isempty(tuple{2})
          header.(tuple{1}{1}) = tuple{2}{1};
      end
  end
end

function data = readData(rawTextData)
%READDATA Reads the sample data from the file.

  data = struct;
  dataDelim = ','; 
  
  params = rawTextData{2};
  iParams = strfind(params, ',');
  nParams = length(iParams);
  paramsFmt = repmat('%s', 1, nParams);
  params = textscan(params, paramsFmt, 'Delimiter', dataDelim);
  dataFmt = ['%s', repmat('%f', 1, nParams-1)];
  
  nData = length(rawTextData(3:end));
  values = cellfun(@textscan, rawTextData(3:end), repmat({dataFmt}, nData, 1), repmat({'Delimiter'}, nData, 1), repmat({dataDelim}, nData, 1), 'UniformOutput', false);
  values = vertcat(values{:});
  
  for i=1:nParams
      switch params{i}{1}
          case {'Date', 'Meas date'}
              data.TIME.values = datenum(vertcat(values{:,i}), 'yyyy/mm/dd HH:MM:SS');
              data.TIME.comment = '';
              
          case {'Temp.[deg C]', 'Temp.[degC]'}
              data.TEMP.values = vertcat(values{:,i});
              data.TEMP.comment = '';
              
          case 'Chl-a[ug/l]'
              data.CPHL.values = vertcat(values{:,i});
              data.CPHL.comment = ['Artificial chlorophyll data '...
                  'computed from bio-optical sensor raw counts measurements. The '...
                  'fluorometre is equipped with a 470nm peak wavelength LED to irradiate and a '...
                  'photodetector paired with an optical filter which measures everything '...
                  'that fluoresces in the region of 650nm to 1000nm. '...
                  'Originally expressed in ug/l, 1l = 0.001m3 was assumed.'];
              
          case {'Turb. -M[FTU]', 'Turb.-M[FTU]'}
              data.TURBF.values = vertcat(values{:,i});
              data.TURBF.comment = ['Turbidity data '...
                  'computed from bio-optical sensor raw counts measurements. The '...
                  'turbidity sensor is equipped with a 880nm peak wavelength LED to irradiate and a '...
                  'photodetector paired with an optical filter which measures everything '...
                  'that backscatters in the region of 650nm to 1000nm.'];
              
          case 'Batt.[V]'
              data.VOLT.values = vertcat(values{:,i});
              data.VOLT.comment = '';
              
      end
  end
end
