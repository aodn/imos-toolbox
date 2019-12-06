function sample_data = sensusUltraParse( filename, mode )
%sensusUltra Parses a data file retrieved from a ReefNet Sensus Ultra logger.
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
  
% ensure that there is exactly one argument, 
% and that it is a cell array of strings
narginchk(1,2);

if ~iscellstr(filename), error('filename must be a cell array of strings'); end

% only one file supported currently
filename = filename{1};
if ~ischar(filename), error('filename must contain a string'); end
  
  % open the file, and read in the data
  try 
    
    fid    = fopen(filename, 'rt');
    data   = readData(fid);
    fclose(fid);
  
  catch e
    if fid ~= -1, fclose(fid); end
    rethrow(e);
  end
  
  % copy all of the information over to the sample data struct
  sample_data = struct;

  sample_data.toolbox_input_file        = filename;
  sample_data.meta.instrument_make      = 'ReefNet';
  sample_data.meta.instrument_model     = 'SensusUltra';
  sample_data.meta.instrument_firmware  = '3.02';
  sample_data.meta.instrument_serial_no = data.serial{1};
  sample_data.meta.instrument_sample_interval = median(diff(data.time*24*3600));
  sample_data.meta.featureType          = mode;
  
  sample_data.dimensions = {};
  sample_data.variables  = {};

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
  
  for k = 1:length(fields)
    
      comment = '';
      name = '';
      
      switch fields{k}
          %Temperature (Celsius degree)
          case 'Temp', name = 'TEMP';
              
          %Pressure (dBar)
          case 'Pres', name = 'PRES';
      end
    
      if ~strcmpi(name, '')
          % dimensions definition must stay in this order : T, Z, Y, X, others;
          % to be CF compliant
          sample_data.variables{end+1}.dimensions = 1;
          sample_data.variables{end}.name         = name;
          sample_data.variables{end}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{end}.name, 'type')));
          sample_data.variables{end}.data         = sample_data.variables{end}.typeCastFunc(data.(fields{k}));
          sample_data.variables{end}.coordinates  = 'TIME LATITUDE LONGITUDE NOMINAL_DEPTH';
          sample_data.variables{end}.comment      = comment;
      end
  end
end

function data = readData(fid)
%READDATA Reads the sample data from the file.

  data = struct;
  
  fmt  = '%n%s%s%f%f%f%f%f%f%f%f%f';
  
  samples = textscan(fid, fmt, 'Delimiter', ',');
  
  data.dive = samples{1};
  data.serial = samples{2};
  data.time = datenum(samples{4}, samples{5}, samples{6}, ...
      samples{7}, samples{8}, samples{9}+samples{10});
  data.Temp = samples{12} - 273.15; % Kelvin to Celsius degres
  data.Pres = samples{11}/100; % mbar to dbar
end
