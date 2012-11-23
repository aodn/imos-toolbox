function sample_data = makeNetCDFCompliant( sample_data )
%MAKENETCDFCOMPLIANT Adds fields in the given sample_data struct to make 
% it compliant with the IMOS NetCDF standard.
%
% Uses the template files contained in the toolbox.templateDir subdirectory to
% add fields in the given sample_data struct to make it compliant  with the 
% IMOS NetCDF standard. If a field already exists in the sample_data struct, 
% it is not overwritten, and the template value is discarded. See the 
% parseNetCDFTemplate function for more details on the template files.
%
% Inputs:
%   sample_data - a struct containing sample data.
%
% Outputs:
%   sample_data - same as input, with fields added/modified based on the
%   NeteCDF template files.
%
% Author:       Paul McCarthy <paul.mccarthy@csiro.au>
% Contributor:  Guillaume Galibert <guillaume.galibert@utas.edu.au>
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

  if ~isstruct(sample_data), error('sample_data must be a struct'); end

  % get path to templates subdirectory
  path = readProperty('toolbox.templateDir');
  if isempty(path) || ~exist(path, 'dir')
    path = fullfile(pwd, 'NetCDF', 'template');
  end
  
  %
  % global attributes
  %

  % get the toolbox execution mode. Values can be 'timeSeries' and 'profile'. 
  % If no value is set then default mode is 'timeSeries'
  mode = lower(readProperty('toolbox.mode'));
  
  % get infos from current field trip
  switch mode
      case 'profile'
          globalAttributeFile = 'global_attributes_profile.txt';
      otherwise
          globalAttributeFile = 'global_attributes_timeSeries.txt';
  end

  globAtts = parseNetCDFTemplate(...
    fullfile(path, globalAttributeFile), sample_data);

  % merge global atts into sample_data
  sample_data = mergeAtts(sample_data, globAtts);
  
  %
  % dimensions
  %
  
  % update dimensions DEPTH, LATITUDE, and LONGITUDE data from global 
  % attributes if relevant for time or time/depth dependant data
  idDepth = 0;
  idLat = 0;
  idLon = 0;
  for i=1:length(sample_data.dimensions)
      if strcmpi(sample_data.dimensions{i}.name, 'DEPTH')
          idDepth = i;
      end
      if strcmpi(sample_data.dimensions{i}.name, 'LATITUDE')
          idLat = i;
      end
      if strcmpi(sample_data.dimensions{i}.name, 'LONGITUDE')
          idLon = i;
      end
  end
  % DEPTH
  if ~isempty(globAtts.geospatial_vertical_min) && ~isempty(globAtts.geospatial_vertical_max)
      if globAtts.geospatial_vertical_min == globAtts.geospatial_vertical_max && idDepth > 0
         if length(sample_data.dimensions{idDepth}.data) == 1
            sample_data.dimensions{idDepth}.data = sample_data.dimensions{idDepth}.typeCastFunc(globAtts.geospatial_vertical_min);
         end
      end
  end
  % LATITUDE
  if ~isempty(globAtts.geospatial_lat_min) && ~isempty(globAtts.geospatial_lat_max)
      if globAtts.geospatial_lat_min == globAtts.geospatial_lat_max && idLat > 0
          if length(sample_data.dimensions{idLat}.data) == 1
              sample_data.dimensions{idLat}.data = sample_data.dimensions{idLat}.typeCastFunc(globAtts.geospatial_lat_min);
          end
      end
  end
  % LONGITUDE
  if ~isempty(globAtts.geospatial_lon_min) && ~isempty(globAtts.geospatial_lon_max)
      if globAtts.geospatial_lon_min == globAtts.geospatial_lon_max && idLon > 0
          if length(sample_data.dimensions{idLon}.data) == 1
              sample_data.dimensions{idLon}.data = sample_data.dimensions{idLon}.typeCastFunc(globAtts.geospatial_lon_min);
          end
      end
  end
  
  %
  % coordinate dimensions
  %
  existZAxis = false;
  for k = 1:length(sample_data.dimensions)

    dim = sample_data.dimensions{k};
    
    % check for specificly defined variables
    temp = fullfile(path, [lower(dim.name) '_attributes.txt']);
    if exist(temp, 'file')
        dimAtts = parseNetCDFTemplate(temp, sample_data);
        
        % check for existing Z coordinate variable
        if strcmpi(dimAtts.axis, 'Z')
            existZAxis = true;
        end
    else
        temp = fullfile(path, 'dimension_attributes.txt');

        dimAtts = parseNetCDFTemplate(temp, sample_data, k);
    end
    
    % merge dimension atts back into dimension struct
    sample_data.dimensions{k} = mergeAtts(sample_data.dimensions{k}, dimAtts);
  end

  %
  % variables
  %
  
  varAtts = [];
  for k = 1:length(sample_data.variables)
    
    
    var = sample_data.variables{k};
    
    % check for specificly defined variables
    temp = fullfile(path, [lower(var.name) '_attributes.txt']);
    if exist(temp, 'file')
        varAtts = parseNetCDFTemplate(temp, sample_data, k);
        
        % check for existing Z coordinate variable
        if isfield(varAtts, 'axis')
            if existZAxis && strcmpi(varAtts.axis, 'Z')
                % we remove it as it already exists in a dimension
                varAtts = rmfield(varAtts, 'axis');
            end
        end
    else
        temp = fullfile(path, 'variable_attributes.txt');

        varAtts = parseNetCDFTemplate(temp, sample_data, k);
    end
    
    % merge variable atts back into variable struct
    sample_data.variables{k} = mergeAtts(var, varAtts);
    
    % look for sensor serial numbers if exist
    if isfield(sample_data.meta, 'deployment')
        sample_data.variables{k}.sensor_serial_number = ...
            getSensorSerialNumber(sample_data.variables{k}.name, sample_data.meta.deployment.InstrumentID);
    elseif isfield(sample_data.meta, 'profile')
        sample_data.variables{k}.sensor_serial_number = ...
            getSensorSerialNumber(sample_data.variables{k}.name, sample_data.meta.profile.InstrumentID);
    end
  end
end

function target = mergeAtts ( target, atts )
%MERGEATTS copies the fields in the given atts struct into the given target
%struct.
%

  fields = fieldnames(atts);
  
  for m = 1:length(fields)
    
    % only overwrite existing empty fields in the target except from
    % date_created
    if isfield(target, fields{m})
        if ~isempty(target.(fields{m})) && ~strcmpi(fields{m}, 'date_created'), continue; end;
    end
    
    target.(fields{m}) = atts.(fields{m});
  end
end

function target = getSensorSerialNumber ( IMOSParam, InstrumentID )
%GETSENSORSERIALNUMBER gets the sensor serial number associated to an IMOS
%paramter for a given deployment ID
%

target = '';

% query the ddb for all sensor config related to this instrument ID
InstrumentSensorConfig = executeDDBQuery('InstrumentSensorConfig', 'InstrumentID',   InstrumentID);

lenConfig = length(InstrumentSensorConfig);
% only consider current config
for i=1:lenConfig
    if InstrumentSensorConfig(i).CurrentConfig == 1;
        % query the ddb for each sensor
        Sensors = executeDDBQuery('Sensors', 'SensorID',   InstrumentSensorConfig(i).SensorID);
        if ~isempty(Sensors)
           % check if this sensor is associated to the current IMOS parameter
           parameters = textscan(Sensors.Parameter, '%s', 'Delimiter', ',');
           if ~isempty(parameters)
               parameters = parameters{1};
               if any(strcmpi(IMOSParam, parameters))
                   target = Sensors.SerialNumber;
               end
           end
        end
    end
end
end
