function sample_data = populateMetadata( sample_data )
%POPULATEMETADATA poulates metadata fields in the given sample_data struct 
% given the content of existing metadata and data.
%
% Mainly populates depth metadata according to PRES, PRES_REL, DEPTH or 
% HEIGHT_ABOVE_SENSOR/DIST_ALONG_BEAMS data from moored/profiling CTD or moored ADCP.
%
% Inputs:
%   sample_data - a struct containing sample data.
%
% Outputs:
%   sample_data - same as input, with fields added/modified based on 
%   existing metadata/data.
%
% Author:       Guillaume Galibert <guillaume.galibert@utas.edu.au>
%

%
% Copyright (c) 2016, Australian Ocean Data Network (AODN) and Integrated 
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
%     * Neither the name of the AODN/IMOS nor the names of its contributors 
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
  narginchk(1,1);

  if ~isstruct(sample_data), error('sample_data must be a struct'); end
  
  % get the toolbox execution mode
  mode = readProperty('toolbox.mode');
  
  idDepth = 0;
  idHeight = 0;
  for i=1:length(sample_data.dimensions)
      if strcmpi(sample_data.dimensions{i}.name, 'DEPTH')
          idDepth = i;
      end
      if strcmpi(sample_data.dimensions{i}.name, 'HEIGHT_ABOVE_SENSOR')
          idHeight = i;
      end
      % is equivalent to HEIGHT_ABOVE_SENSOR in the case of a non-tilted ADCP
      if strcmpi(sample_data.dimensions{i}.name, 'DIST_ALONG_BEAMS')
          idHeight = i;
      end
  end
  
  ivDepth = 0;
  ivNomDepth = 0;
  ivLat = 0;
  ivLon = 0;
  ivBotDepth = 0;
  for i=1:length(sample_data.variables)
      if strcmpi(sample_data.variables{i}.name, 'LATITUDE')
          ivLat = i;
      end
      if strcmpi(sample_data.variables{i}.name, 'LONGITUDE')
          ivLon = i;
      end
      if strcmpi(sample_data.variables{i}.name, 'NOMINAL_DEPTH')
          ivNomDepth = i;
      end
      if strcmpi(sample_data.variables{i}.name, 'DEPTH')
          ivDepth = i;
      end
      if strcmpi(sample_data.variables{i}.name, 'BOT_DEPTH')
          ivBotDepth = i;
      end
  end
  
  metadataChanged = false;
  
  % geospatial_vertical  
  updateFromDepth = false;
  if idDepth > 0 && idHeight == 0
      if ~all(isnan(sample_data.dimensions{idDepth}.data(:))) && ...
              isempty(sample_data.geospatial_vertical_min) && ...
              isempty(sample_data.geospatial_vertical_max)
        updateFromDepth = true;
        
        dataDepth = sample_data.dimensions{idDepth}.data;
        iNan = isnan(dataDepth);
        dataDepth = dataDepth(~iNan);
      end
  end
  if ivDepth > 0 && idHeight == 0
      if ~all(isnan(sample_data.variables{ivDepth}.data(:))) && ...
              isempty(sample_data.geospatial_vertical_min) && ...
              isempty(sample_data.geospatial_vertical_max)
        updateFromDepth = true;
        
        dataDepth = sample_data.variables{ivDepth}.data;
        iNan = isnan(dataDepth);
        dataDepth = dataDepth(~iNan);
      end
  end

  if updateFromDepth
      % Update from DEPTH data
      maxDepth      = max(dataDepth);
      minDepth      = min(dataDepth);
      
      verticalComment = ['Geospatial vertical min/max information has '...
          'been filled using the DEPTH min and max.'];
      
      sample_data.geospatial_vertical_min = minDepth;
      sample_data.geospatial_vertical_max = maxDepth;
      
      if isempty(sample_data.comment)
          sample_data.comment = verticalComment;
      elseif ~strcmpi(sample_data.comment, verticalComment)
          sample_data.comment = [sample_data.comment ' ' verticalComment];
      end
      
      metadataChanged = true;
  else
      % Update from NOMINAL_DEPTH if available
      if ivNomDepth > 0
          % Update from NOMINAL_DEPTH data
          dataNominalDepth = sample_data.variables{ivNomDepth}.data;
          iNan = isnan(dataNominalDepth);
          dataNominalDepth = dataNominalDepth(~iNan);
          
          verticalComment = ['Geospatial vertical min/max information has '...
              'been filled using the NOMINAL_DEPTH.'];
          
          sample_data.geospatial_vertical_min = dataNominalDepth;
          sample_data.geospatial_vertical_max = dataNominalDepth;
          
          if isempty(sample_data.comment)
              sample_data.comment = verticalComment;
          elseif ~strcmpi(sample_data.comment, verticalComment)
              sample_data.comment = [sample_data.comment ' ' verticalComment];
          end
          
          metadataChanged = true;
      end
  end
  
  % Now let's synchronise metadata and Dimensions/Variables
  % LATITUDE
  if ~isempty(sample_data.geospatial_lat_min) && ~isempty(sample_data.geospatial_lat_max)
      if sample_data.geospatial_lat_min == sample_data.geospatial_lat_max
          switch mode
              case 'profile'
                  sample_data.variables{ivLat}.data = sample_data.variables{ivLat}.typeCastFunc(ones(size(sample_data.variables{ivLat}.data))*sample_data.geospatial_lat_min);
                  
              case 'timeSeries'
                  if length(sample_data.variables{ivLat}.data) == 1
                      sample_data.variables{ivLat}.data = sample_data.variables{ivLat}.typeCastFunc(sample_data.geospatial_lat_min);
                  end
                  
          end
      end
  else
      
  end
  
  % LONGITUDE
  if ~isempty(sample_data.geospatial_lon_min) && ~isempty(sample_data.geospatial_lon_max)
      if sample_data.geospatial_lon_min == sample_data.geospatial_lon_max
          switch mode
              case 'profile'
                  sample_data.variables{ivLon}.data = sample_data.variables{ivLon}.typeCastFunc(ones(size(sample_data.variables{ivLon}.data))*sample_data.geospatial_lon_min);
                  
              case 'timeSeries'
                  if length(sample_data.variables{ivLon}.data) == 1
                      sample_data.variables{ivLon}.data = sample_data.variables{ivLon}.typeCastFunc(sample_data.geospatial_lon_min);
                  end
                  
          end
      end
  end
  
  % NOMINAL_DEPTH (so far only supported for timeseries)
  if ivNomDepth > 0
      if ~isempty(sample_data.instrument_nominal_depth)
          switch mode
              case 'timeSeries'
                  if length(sample_data.variables{ivNomDepth}.data) == 1
                      sample_data.variables{ivNomDepth}.data = sample_data.variables{ivNomDepth}.typeCastFunc(sample_data.instrument_nominal_depth);
                  end
                  
%               case 'profile'
%                   sample_data.variables{ivNomDepth}.data = sample_data.variables{ivNomDepth}.typeCastFunc(ones(size(sample_data.variables{ivNomDepth}.data))*sample_data.instrument_nominal_depth);
                  
          end
      end
  end
  
  % BOT_DEPTH (so far only supported for CTD profiles)
  if ivBotDepth > 0
      switch mode
          case 'profile'
              if ~isempty(sample_data.site_depth_at_station)
                  sample_data.variables{ivBotDepth}.data = sample_data.variables{ivBotDepth}.typeCastFunc(ones(size(sample_data.variables{ivBotDepth}.data))*sample_data.site_depth_at_station);
              elseif ~isempty(sample_data.site_nominal_depth)
                  sample_data.variables{ivBotDepth}.data = sample_data.variables{ivBotDepth}.typeCastFunc(ones(size(sample_data.variables{ivBotDepth}.data))*sample_data.site_nominal_depth);
              end
              
%           case 'timeSeries'
%               if ~isempty(sample_data.site_depth_at_deployment)
%                   sample_data.variables{ivBotDepth}.data = sample_data.variables{ivBotDepth}.typeCastFunc(ones(size(sample_data.variables{ivBotDepth}.data))*sample_data.site_depth_at_deployment);
%               elseif ~isempty(sample_data.site_nominal_depth)
%                   sample_data.variables{ivBotDepth}.data = sample_data.variables{ivBotDepth}.typeCastFunc(ones(size(sample_data.variables{ivBotDepth}.data))*sample_data.site_nominal_depth);
%               end
      end
  end
  
  % regenerate table content
  if metadataChanged
      hPanel = findobj('Tag', 'metadataPanel');
      updateViewMetadata(hPanel, sample_data, mode);
  end
end