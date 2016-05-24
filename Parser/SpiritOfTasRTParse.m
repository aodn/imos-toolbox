function sample_data = SpiritOfTasRTParse( filename, mode )
%SPIRITOFTASRTPARSE Parses a 1sec raw .log RT data file from the Spirit of
%Tasmania ship of opportunity
%
% This function is able to read in a .log file from the Spirit of Tasmania
% ship of opportunity which is a comma separated ASCII file. The fields are
% found in this order:
% -Time, in format yyyy-mm-dd HH:MM:SS
% -Status code (F=fresh flush; P=pressure suspect; null=other)
% -Product code (MEL; M2D; DEV; D2M)
% -Distance from port in km
% -Latitude
% -Longitude
% -Temperature
% -Salinity
% -Fluorescence in count
% -Turbidity in count
%
% Inputs:
%   filename    - cell array of files to import (only one supported).
%   mode        - Toolbox data type mode.
%
% Outputs:
%   sample_data - Struct containing sample data.
%
% Author:       Guillaume Galibert <guillaume.galibert@utas.edu.au>
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
  narginchk(1,2);

  if ~iscellstr(filename)
    error('filename must be a cell array of strings'); 
  end

  % only one file supported currently
  filename = filename{1};
  
  fid = fopen(filename, 'rt');
  fileContent = textscan(fid, '%s%s%s%f%f%f%f%f%f%f%*f%*f', 'Delimiter', ','); % we add a couple of extra columns just in case
  fclose(fid);
  
  % we only keep data outside fresh water flushing events and when pressure
  % is correct
  iGood = cellfun(@isempty, fileContent{2});
  
  % we only consider transect data here
  iGood = iGood & (strcmpi(fileContent{3}, 'M2D') | strcmpi(fileContent{3}, 'D2M'));
  
  dataSet.TIME.data = datenum(fileContent{1}, 'yyyy-mm-dd HH:MM:SS');
  
  % we only consider monotonic time values although sometimes the
  % instrument outputs twice the same row.
  iGood = iGood & ~[diff(dataSet.TIME.data)==0; false];
  dataSet.TIME.data(~iGood) = [];
  
  transectType = fileContent{3}(iGood);
  
  dataSet.LATITUDE.data = fileContent{5}(iGood);
  dataSet.LONGITUDE.data = fileContent{6}(iGood);
  dataSet.TEMP.data = fileContent{7}(iGood);
  dataSet.PSAL.data = fileContent{8}(iGood);
  dataSet.FLU2.data = fileContent{9}(iGood);
  dataSet.TURBC.data = fileContent{10}(iGood);
  
  % create sample data struct, 
  % and copy all the data in
  sample_data = struct;
  
  sample_data.toolbox_input_file    = filename;
  sample_data.meta.featureType      = mode;
  sample_data.meta.instrument_make  = 'Seabird';
  sample_data.meta.instrument_model = 'SBE45';
  sample_data.meta.instrument_serial_no = '';
  sample_data.meta.instrument_sample_interval = median(diff(dataSet.TIME.data*24*3600));
  sample_data.meta.transectType = transectType{1}; % we assume they're all the same value
  
  sample_data.dimensions = {};  
  sample_data.variables  = {};
  
  % dimensions creation
  sample_data.dimensions{1}.name              = 'TIME';
  sample_data.dimensions{1}.typeCastFunc      = str2func(netcdf3ToMatlabType(imosParameters(sample_data.dimensions{1}.name, 'type')));
  % generate time data from header information
  sample_data.dimensions{1}.data              = sample_data.dimensions{1}.typeCastFunc(dataSet.TIME.data);
  
  sample_data.variables{end+1}.name           = 'TRAJECTORY';
  sample_data.variables{end}.typeCastFunc     = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{end}.name, 'type')));
  sample_data.variables{end}.data             = sample_data.variables{end}.typeCastFunc(1);
  sample_data.variables{end}.dimensions       = [];
  sample_data.variables{end+1}.name           = 'LATITUDE';
  sample_data.variables{end}.typeCastFunc     = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{end}.name, 'type')));
  sample_data.variables{end}.data             = sample_data.variables{end}.typeCastFunc(dataSet.LATITUDE.data);
  sample_data.variables{end}.dimensions       = 1;
  sample_data.variables{end+1}.name           = 'LONGITUDE';
  sample_data.variables{end}.typeCastFunc     = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{end}.name, 'type')));
  sample_data.variables{end}.data             = sample_data.variables{end}.typeCastFunc(dataSet.LONGITUDE.data);
  sample_data.variables{end}.dimensions       = 1;
  sample_data.variables{end+1}.name           = 'NOMINAL_DEPTH';
  sample_data.variables{end}.typeCastFunc     = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{end}.name, 'type')));
  sample_data.variables{end}.data             = sample_data.variables{end}.typeCastFunc(NaN);
  sample_data.variables{end}.dimensions       = [];
  
  dataSet = rmfield(dataSet, {'LATITUDE', 'LONGITUDE'});
  
  % scan through the list of parameters that were read
  % from the file, and create a variable for each
  vars = fieldnames(dataSet);
  coordinates = 'TIME LATITUDE LONGITUDE NOMINAL_DEPTH';
  for i = 1:length(vars)
      
      if strncmp('TIME', vars{i}, 4), continue; end
      
      % dimensions definition must stay in this order : T, Z, Y, X, others;
      % to be CF compliant
      sample_data.variables{end+1}.dimensions   = 1;
      
      sample_data.variables{end  }.name         = vars{i};
      sample_data.variables{end  }.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{end}.name, 'type')));
      
      atts = fieldnames(dataSet.(vars{i}));
      for j = 1:length(atts)
          sample_data.variables{end  }.(atts{j})= dataSet.(vars{i}).(atts{j});
      end
      
      sample_data.variables{end  }.coordinates  = coordinates;
  end
end