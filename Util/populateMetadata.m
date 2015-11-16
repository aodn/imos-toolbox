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
  narginchk(1,1);

  if ~isstruct(sample_data), error('sample_data must be a struct'); end
  
  % get the toolbox execution mode. Values can be 'timeSeries' and 'profile'. 
  % If no value is set then default mode is 'timeSeries'
  mode = lower(readProperty('toolbox.mode'));
  
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
  ivPres = 0;
  ivPresRel = 0;
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
      if strcmpi(sample_data.variables{i}.name, 'PRES')
          ivPres = i;
      end
      if strcmpi(sample_data.variables{i}.name, 'PRES_REL')
          ivPresRel = i;
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
      MedianDepth   = median(dataDepth);
      
      maxDepth      = round(maxDepth*100)/100;
      minDepth      = round(minDepth*100)/100;
      MedianDepth   = round(MedianDepth*100)/100;
      
      verticalComment = ['Geospatial vertical min/max information has '...
          'been filled using the'];
      
      switch mode
          case 'profile'
              sample_data.geospatial_vertical_min = minDepth;
              sample_data.geospatial_vertical_max = maxDepth;
              verticalComment = [verticalComment ' DEPTH min and max (vertical profile).'];
              
          otherwise
              % Moored => geospatial_vertical_min ~= geospatial_vertical_max
              sample_data.geospatial_vertical_min = MedianDepth;
              sample_data.geospatial_vertical_max = MedianDepth;
              verticalComment = [verticalComment ' DEPTH median (mooring).'];
              
      end
      
      if isempty(sample_data.comment)
          sample_data.comment = verticalComment;
      elseif ~strcmpi(sample_data.comment, verticalComment)
          sample_data.comment = [sample_data.comment ' ' verticalComment];
      end
      
      metadataChanged = true;
  else
      % Update from PRES if available
      if ivPres > 0 || ivPresRel > 0
          if ivPresRel == 0
              % update from a relative pressure like SeaBird computes
              % it in its processed files, substracting a constant value
              % 10.1325 dbar for nominal atmospheric pressure
              relPres = sample_data.variables{ivPres}.data - gsw_P0/10^4;
              presComment = ['absolute '...
                  'pressure measurements to which a nominal '...
                  'value for atmospheric pressure (10.1325 dbar) '...
                  'has been substracted'];
              iNanRelPres = isnan(relPres);
          else
              % update from a relative measured pressure
              relPres = sample_data.variables{ivPresRel}.data;
              presComment = ['relative '...
                  'pressure measurements (calibration offset '...
                  'usually performed to balance current '...
                  'atmospheric pressure and acute sensor '...
                  'precision at a deployed depth)'];
              iNanRelPres = isnan(relPres);
          end
          if ~isempty(sample_data.geospatial_lat_min) && ~isempty(sample_data.geospatial_lat_max)
              % compute vertical min/max with Gibbs-SeaWater toolbox (TEOS-10)
              if sample_data.geospatial_lat_min == sample_data.geospatial_lat_max
                  computedDepth         = - gsw_z_from_p(relPres, ...
                      sample_data.geospatial_lat_min);
                  computedMedianDepth   = - gsw_z_from_p(median(relPres(~iNanRelPres)), ...
                      sample_data.geospatial_lat_min);
                  computedMinDepth      = - gsw_z_from_p(min(relPres(~iNanRelPres)), ...
                      sample_data.geospatial_lat_min);
                  computedMaxDepth      = - gsw_z_from_p(max(relPres(~iNanRelPres)), ...
                      sample_data.geospatial_lat_min);
                  computedDepthComment  = ['depthPP: Depth computed using the '...
                      'Gibbs-SeaWater toolbox (TEOS-10) v3.05 from latitude and '...
                      presComment '.'];
                  computedMedianDepthComment  = ['Geospatial vertical '...
                      'min/max information has been computed using the '...
                      'Gibbs-SeaWater toolbox (TEOS-10) v3.05 from latitude and '...
                      presComment '.'];
              else
                  meanLat = sample_data.geospatial_lat_min + ...
                      (sample_data.geospatial_lat_max - sample_data.geospatial_lat_min)/2;
                  
                  computedDepth         = - gsw_z_from_p(relPres, meanLat);
                  computedMedianDepth   = - gsw_z_from_p(median(relPres(~iNanRelPres)), meanLat);
                  computedMinDepth      = - gsw_z_from_p(min(relPres(~iNanRelPres)), meanLat);
                  computedMaxDepth      = - gsw_z_from_p(max(relPres(~iNanRelPres)), meanLat);
                  computedDepthComment  = ['depthPP: Depth computed using the '...
                      'Gibbs-SeaWater toolbox (TEOS-10) v3.05 from mean latitude and '...
                      presComment '.'];
                  computedMedianDepthComment  = ['Geospatial vertical '...
                      'min/max information has been computed using the '...
                      'Gibbs-SeaWater toolbox (TEOS-10) v3.05 from mean latitude and '...
                      presComment '.'];
              end
          else
              % without latitude information, we assume 1dbar ~= 1m
              computedDepth         = relPres;
              computedMedianDepth   = median(relPres(~iNanRelPres));
              computedMinDepth      = min(relPres(~iNanRelPres));
              computedMaxDepth      = max(relPres(~iNanRelPres));
              computedDepthComment  = ['depthPP: Depth computed from '...
                  presComment ', assuming 1dbar ~= 1m.'];
              computedMedianDepthComment  = ['Geospatial vertical min/max '...
                  'information has been computed from '...
                  presComment ', assuming 1dbar ~= 1m.'];
          end
            
          computedMedianDepth   = round(computedMedianDepth*100)/100;
          computedMinDepth      = round(computedMinDepth*100)/100;
          computedMaxDepth      = round(computedMaxDepth*100)/100;
          
          if idHeight > 0
              % ADCP
              if all(sample_data.dimensions{idHeight}.data >= 0) % upward looking configuration
                  maxDistance = round(max(sample_data.dimensions{idHeight}.data)*100)/100; % HEIGHT_ABOVE_SENSOR is positive when upward
                  % update vertical min/max metadata from data
                  % we assume that depth data is reliable
                  if isempty(sample_data.geospatial_vertical_min) && isempty(sample_data.geospatial_vertical_max)
                      
                      sample_data.geospatial_vertical_min = max(0, computedMedianDepth - maxDistance); % cannot be above surface
                      sample_data.geospatial_vertical_max = computedMedianDepth;
                      comment  = strrep(computedMedianDepthComment, 'min/', '');
                      
                      if isempty(sample_data.comment)
                          sample_data.comment = comment;
                      elseif ~strcmpi(sample_data.comment, comment)
                          sample_data.comment = [sample_data.comment ' ' comment];
                      end
                      
                      metadataChanged = true;
                  end
              else % downward looking configuration
                  maxDistance = - round(min(sample_data.dimensions{idHeight}.data)*100)/100; % HEIGHT_ABOVE_SENSOR is negative when downward
                  % update vertical min/max metadata from data
                  % we assume that depth data is reliable
                  if isempty(sample_data.geospatial_vertical_min) && isempty(sample_data.geospatial_vertical_max)
                      
                      sample_data.geospatial_vertical_min = computedMedianDepth;
                      sample_data.geospatial_vertical_max = computedMedianDepth + maxDistance;
                      comment  = strrep(computedMedianDepthComment, '/max', '');
                      
                      if computedMedianDepth + maxDistance > sample_data.site_nominal_depth; % cannot be below bottom
                          sample_data.geospatial_vertical_max = sample_data.site_nominal_depth;
                      end
                      
                      if computedMedianDepth + maxDistance > sample_data.site_depth_at_deployment; % cannot be below bottom
                          sample_data.geospatial_vertical_max = sample_data.site_depth_at_deployment;
                      end
                      
                      if isempty(sample_data.comment)
                          sample_data.comment = comment;
                      elseif ~strcmpi(sample_data.comment, comment)
                          sample_data.comment = [sample_data.comment ' ' comment];
                      end
                      
                      metadataChanged = true;
                  end
              end
          else
              % Not an ADCP, so we can update existing DEPTH dimension/variable from PRES data
              if idDepth > 0
                  sample_data.dimensions{idDepth}.data = sample_data.dimensions{idDepth}.typeCastFunc(computedDepth);
                  comment = sample_data.dimensions{idDepth}.comment;
                  if isempty(comment)
                      sample_data.dimensions{idDepth}.comment = computedDepthComment;
                  elseif ~strcmpi(computedDepthComment, comment)
                      sample_data.dimensions{idDepth}.comment = [comment ' ' computedDepthComment];
                  end
                  metadataChanged = true;
              end
              if ivDepth > 0
                  sample_data.variables{ivDepth}.data = sample_data.variables{ivDepth}.typeCastFunc(computedDepth);
                  comment = sample_data.variables{ivDepth}.comment;
                  if isempty(comment)
                      sample_data.variables{ivDepth}.comment = computedDepthComment;
                  elseif ~strcmpi(computedDepthComment, comment)
                      sample_data.variables{ivDepth}.comment = [comment ' ' computedDepthComment];
                  end
                  metadataChanged = true;
              end
          
              if isempty(sample_data.geospatial_vertical_min) && isempty(sample_data.geospatial_vertical_max)
                  switch mode
                      case 'profile'
                          sample_data.geospatial_vertical_min = 0;
                          sample_data.geospatial_vertical_max = computedMaxDepth;
                          comment  = strrep(computedMedianDepthComment, 'median', 'max (vertical profile)');
                          
                      otherwise
                          % Moored => geospatial_vertical_min ~= geospatial_vertical_max
                          sample_data.geospatial_vertical_min = computedMedianDepth;
                          sample_data.geospatial_vertical_max = computedMedianDepth;
                          comment  = strrep(computedMedianDepthComment, 'median', 'median (mooring)');        
                          
                  end
                  
                  metadataChanged = true;
                  
                  if isempty(sample_data.comment)
                      sample_data.comment = comment;
                  elseif ~strcmpi(sample_data.comment, comment)
                      sample_data.comment = [sample_data.comment ' ' comment];
                  end
              end
          end
      end
  end
  
  % Now let's synchronise metadata and Dimensions/Variables
  % LATITUDE
  if ~isempty(sample_data.geospatial_lat_min) && ~isempty(sample_data.geospatial_lat_max)
      if sample_data.geospatial_lat_min == sample_data.geospatial_lat_max
          switch mode
              case 'profile'
                  sample_data.variables{ivLat}.data = sample_data.variables{ivLat}.typeCastFunc(ones(size(sample_data.variables{ivLat}.data))*sample_data.geospatial_lat_min);
                  
              otherwise
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
                  
              otherwise
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
                  
%               otherwise
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
              
%           otherwise
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