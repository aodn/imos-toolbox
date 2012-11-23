function sample_data = sensusUltraParse( filename, mode )
%sensusUltra Parses a data file retrieved from a ReefNet Sensus Ultra logger.
%
%
% Inputs:
%   filename    - Cell array containing the name of the file to parse.
%   mode        - Toolbox data type mode ('profile' or 'timeSeries').
%
% Outputs:
%   sample_data - Struct containing imported sample data.
%
% Author : Guillaume Galibert <guillaume.galibert@utas.edu.au>

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
  
% ensure that there is exactly one argument, 
% and that it is a cell array of strings
error(nargchk(1,2,nargin));

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
  
  % dimensions definition must stay in this order : T, Z, Y, X, others;
  % to be CF compliant
  sample_data.dimensions{1}.name = 'TIME';
  sample_data.dimensions{1}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data.dimensions{1}.name, 'type')));
  sample_data.dimensions{1}.data = sample_data.dimensions{1}.typeCastFunc(data.time);
  sample_data.dimensions{2}.name = 'LATITUDE';
  sample_data.dimensions{2}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data.dimensions{2}.name, 'type')));
  sample_data.dimensions{2}.data = sample_data.dimensions{2}.typeCastFunc(NaN);
  sample_data.dimensions{3}.name = 'LONGITUDE';
  sample_data.dimensions{3}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data.dimensions{3}.name, 'type')));
  sample_data.dimensions{3}.data = sample_data.dimensions{3}.typeCastFunc(NaN);
  
  % copy variable data over
  data = rmfield(data, 'time');
  fields = fieldnames(data);
  
  l = 1;
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
          sample_data.variables{l}.name         = name;
          sample_data.variables{l}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{l}.name, 'type')));
          sample_data.variables{l}.data         = sample_data.variables{l}.typeCastFunc(data.(fields{k}));
          sample_data.variables{l}.dimensions   = [1 2 3];
          sample_data.variables{l}.comment      = comment;
          l = l+1;
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