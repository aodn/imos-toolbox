function sample_data = populateMetadata( sample_data )
%POPULATEMETADATA poulates metadata fields in the given sample_data struct 
% given the content of existing metadata and data.
%
% Mainly populates depth metadata according to PRES or HEIGHT_ABOVE_SENSOR 
% data from moored/profiling CTD or moored ADCP.
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
  error(nargchk(1,1,nargin));

  if ~isstruct(sample_data), error('sample_data must be a struct'); end
  
  idDepth = 0;
  idHeight = 0;
  idLat = 0;
  idLon = 0;
  for i=1:length(sample_data.dimensions)
      if strcmpi(sample_data.dimensions{i}.name, 'DEPTH')
          idDepth = i;
      end
      if strcmpi(sample_data.dimensions{i}.name, 'HEIGHT_ABOVE_SENSOR')
          idHeight = i;
      end
      if strcmpi(sample_data.dimensions{i}.name, 'LATITUDE')
          idLat = i;
      end
      if strcmpi(sample_data.dimensions{i}.name, 'LONGITUDE')
          idLon = i;
      end
  end
  
  metadataChanged = false;
  
  % geospatial_vertical  
  updateFromDepth = false;
  ivDepth = getVar(sample_data.variables, 'DEPTH');
  if idDepth > 0 && idHeight == 0
      if ~all(isnan(sample_data.dimensions{idDepth}.data)) && ...
              isempty(sample_data.geospatial_vertical_min) && ...
              isempty(sample_data.geospatial_vertical_max);
        updateFromDepth = true;
      end
  end
  if ivDepth > 0 && idHeight == 0
      if ~all(isnan(sample_data.variables{ivDepth}.data)) && ...
              isempty(sample_data.geospatial_vertical_min) && ...
              isempty(sample_data.geospatial_vertical_max);
        updateFromDepth = true;
      end
  end
  
  if updateFromDepth
      % Update from DEPTH data
      % Let's find out if it's a profile or a mooring
      if ivDepth > 0
          iNan = isnan(sample_data.variables{ivDepth}.data);
          dataDepth = sample_data.variables{ivDepth}.data(~iNan);
          maxDepth      = max(dataDepth);
          minDepth      = min(dataDepth);
          MedianDepth   = median(dataDepth);
      end
      if idDepth > 0
          iNan = isnan(sample_data.dimensions{idDepth}.data);
          dataDepth = sample_data.dimensions{idDepth}.data(~iNan);
          maxDepth      = max(dataDepth);
          minDepth      = min(dataDepth);
          MedianDepth   = median(dataDepth);
      end
      
      threshold = maxDepth - maxDepth*20/100;
      iDataDeploying = sample_data.variables{ivDepth}.data < threshold;
      nDataDeploying = sum(iDataDeploying);
      nDataMooring = sum(~iDataDeploying);
      
      verticalComment = ['Geospatial vertical min/max information has '...
              'been filled using the'];
      
      if nDataDeploying < nDataMooring/10
          % Moored => geospatial_vertical_min ~=
          % geospatial_vertical_max
          sample_data.geospatial_vertical_min = MedianDepth;
          sample_data.geospatial_vertical_max = MedianDepth;
          verticalComment = [verticalComment ' DEPTH median (mooring).'];
      else
          % Profile
          sample_data.geospatial_vertical_min = minDepth;
          sample_data.geospatial_vertical_max = maxDepth;
          verticalComment = [verticalComment ' DEPTH min and max (vertical profile).'];
      end
      
      if isempty(sample_data.comment)
          sample_data.comment = verticalComment;
      else
          sample_data.comment = [sample_data.comment ' ' verticalComment];
      end
      
      metadataChanged = true;
  else
      % Update from PRES if available
      ivPres = getVar(sample_data.variables, 'PRES');
      if ivPres > 0
          % update from a relative pressure like SeaBird computes
          % it in its processed files, substracting a constant value
          % 14.7*0.689476 dBar for nominal atmospheric pressure
          relPres = sample_data.variables{ivPres}.data - 14.7*0.689476;
          if ~isempty(sample_data.geospatial_lat_min) && ~isempty(sample_data.geospatial_lat_max)
              % compute vertical min/max with SeaWater toolbox
              if sample_data.geospatial_lat_min == sample_data.geospatial_lat_max
                  computedDepth         = sw_dpth(relPres, ...
                      sample_data.geospatial_lat_min);
                  computedMedianDepth   = sw_dpth(median(relPres), ...
                      sample_data.geospatial_lat_min);
                  computedMinDepth      = sw_dpth(min(relPres), ...
                      sample_data.geospatial_lat_min);
                  computedMaxDepth      = sw_dpth(max(relPres), ...
                      sample_data.geospatial_lat_min);
                  computedDepthComment  = ['depthPP: Depth computed using the '...
                      'SeaWater toolbox from latitude and absolute '...
                      'pressure measurements to which a nominal '...
                      'value for atmospheric pressure (14.7*0689476 dBar) '...
                      'has been substracted.'];
                  computedMedianDepthComment  = ['Geospatial vertical '...
                      'min/max information has been computed using the '...
                      'SeaWater toolbox from latitude and absolute '...
                      'pressure measurements median to which a nominal '...
                      'value for atmospheric pressure (14.7*0689476 dBar) '...
                      'has been substracted.'];
              else
                  meanLat = sample_data.geospatial_lat_min + ...
                      (sample_data.geospatial_lat_max - sample_data.geospatial_lat_min)/2;
                  
                  computedDepth         = sw_dpth(relPres, meanLat);
                  computedMedianDepth   = sw_dpth(median(relPres), meanLat);
                  computedMinDepth      = sw_dpth(min(relPres), meanLat);
                  computedMaxDepth      = sw_dpth(max(relPres), meanLat);
                  computedDepthComment  = ['depthPP: Depth computed using the '...
                      'SeaWater toolbox from mean latitude and absolute '...
                      'pressure measurements to which a nominal '...
                      'value for atmospheric pressure (14.7*0689476 dBar) '...
                      'has been substracted.'];
                  computedMedianDepthComment  = ['Geospatial vertical '...
                      'min/max information has been computed using the '...
                      'SeaWater toolbox from mean latitude and absolute '...
                      'pressure measurements median to which a nominal '...
                      'value for atmospheric pressure (14.7*0689476 dBar) '...
                      'has been substracted.'];
              end
          else
              % without latitude information, we assume 1dBar ~= 1m
              computedDepth         = relPres;
              computedMedianDepth   = median(relPres);
              computedMinDepth      = min(relPres);
              computedMaxDepth      = max(relPres);
              computedDepthComment  = ['depthPP: Depth computed from absolute '...
                  'pressure measurements to which a nominal '...
                  'value for atmospheric pressure (14.7*0689476 dBar) '...
                  'has been substracted, assuming 1dBar ~= 1m.'];
              computedMedianDepthComment  = ['Geospatial vertical min/max '...
                  'information has been computed from absolute '...
                  'pressure measurements median to which a nominal '...
                  'value for atmospheric pressure (14.7*0689476 dBar) '...
                  'has been substracted, assuming 1dBar ~= 1m.'];
          end
          computedDepth         = round(computedDepth*100)/100;
          computedMedianDepth   = round(computedMedianDepth*100)/100;
          computedMinDepth      = round(computedMinDepth*100)/100;
          computedMaxDepth      = round(computedMaxDepth*100)/100;
          
          if idHeight > 0
              % ADCP
              % Let's compare this computed depth from pressure
              % with the maximum distance the ADCP can measure. Sometimes,
              % PRES from ADCP pressure sensor is just wrong
              maxDistance = round(max(sample_data.dimensions{idHeight}.data)*100)/100;
              diff = abs(maxDistance - computedMedianDepth)/max(maxDistance, computedMedianDepth);
              
              % update vertical min/max metadata from data
              % we assume that data is collected between the
              % vertical extremes of surface and sensor depth
              if isempty(sample_data.geospatial_vertical_min) && isempty(sample_data.geospatial_vertical_max)
                  sample_data.geospatial_vertical_min = 0;
                  
                  if diff < 10/100
                      % Depth from PRES Ok if diff < 10% and latitude
                      % filled
                      sample_data.geospatial_vertical_max = computedMedianDepth;
                      comment  = strrep(computedMedianDepthComment, 'min/', '');
                  else
                      % Depth is taken from maxDistance between ADCP and bins
                      sample_data.geospatial_vertical_max = maxDistance;
                      comment  = ['Geospatial vertical max '...
                          'information has been assumed as the distance '...
                          'between the ADCP''s tranducers and the furthest '...
                          'bin measured.'];
                  end
                  
                  if isempty(sample_data.comment)
                      sample_data.comment = comment;
                  else
                      sample_data.comment = [sample_data.comment ' ' comment];
                  end
                  
                  metadataChanged = true;
              end
          else
              % Not an ADCP, so we can update existing DEPTH dimension/variable from PRES data
              if idDepth > 0
                  sample_data.dimensions{idDepth}.data = computedDepth;
                  sample_data.dimensions{idDepth}.comment = computedDepthComment;
                  metadataChanged = true;
              end
              if ivDepth > 0
                  sample_data.variables{ivDepth}.data = computedDepth;
                  sample_data.variables{ivDepth}.comment = computedDepthComment;
                  metadataChanged = true;
              end
              
              % Let's find out if it's a profile or a mooring
              nDataDeploying = 0;
              nDataMooring = 0;
              
              if ivPres > 0
                  maxPressure = max(relPres);
                  threshold = maxPressure - maxPressure*20/100;
                  iDataDeploying = relPres < threshold;
                  nDataDeploying = sum(iDataDeploying);
                  nDataMooring = sum(~iDataDeploying);
              end
          
              if isempty(sample_data.geospatial_vertical_min) && isempty(sample_data.geospatial_vertical_max)
                  if nDataDeploying < nDataMooring/10 || ivPres == 0
                      % Moored => geospatial_vertical_min ~=
                      % geospatial_vertical_max
                      sample_data.geospatial_vertical_min = computedMedianDepth;
                      sample_data.geospatial_vertical_max = computedMedianDepth;
                      comment  = strrep(computedMedianDepthComment, 'median', 'median (mooring)');
                      metadataChanged = true;
                  else
                      % Profile
                      sample_data.geospatial_vertical_min = computedMinDepth;
                      sample_data.geospatial_vertical_max = computedMaxDepth;
                      comment  = strrep(computedMedianDepthComment, 'median', 'min and max (vertical profile)');
                      metadataChanged = true;
                  end
                  
                  if isempty(sample_data.comment)
                      sample_data.comment = comment;
                  else
                      sample_data.comment = [sample_data.comment ' ' comment];
                  end
              end
          end
      end
  end
  
  % Now let's synchronise metadata and Dimensions
  % LATITUDE
  if ~isempty(sample_data.geospatial_lat_min) && ~isempty(sample_data.geospatial_lat_max)
      if sample_data.geospatial_lat_min == sample_data.geospatial_lat_max && idLat > 0
          if length(sample_data.dimensions{idLat}.data) == 1
              sample_data.dimensions{idLat}.data = sample_data.geospatial_lat_min;
          end
      end
  else
      
  end
  
  % LONGITUDE
  if ~isempty(sample_data.geospatial_lon_min) && ~isempty(sample_data.geospatial_lon_max)
      if sample_data.geospatial_lon_min == sample_data.geospatial_lon_max && idLon > 0
          if length(sample_data.dimensions{idLon}.data) == 1
              sample_data.dimensions{idLon}.data = sample_data.geospatial_lon_min;
          end
      end
  end
  
  % DEPTH
  if ~isempty(sample_data.geospatial_vertical_min) && ~isempty(sample_data.geospatial_vertical_max)
      if sample_data.geospatial_vertical_min == sample_data.geospatial_vertical_max && idDepth > 0
         if length(sample_data.dimensions{idDepth}.data) == 1
            sample_data.dimensions{idDepth}.data = sample_data.geospatial_vertical_min; 
         end
      end
  end
  
  % regenerate table content
  if metadataChanged
      hPanel = findobj('Tag', 'metadataPanel');
      updateViewMetadata(hPanel, sample_data);
  end
end