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
  idSDepth = 0;
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
      if strcmpi(sample_data.dimensions{i}.name, 'SENSOR_DEPTH')
          idSDepth = i;
      end
  end
  
  metadataChanged = false;
  
  % geospatial_vertical
  idPres = getVar(sample_data.variables, 'PRES');
  if idPres > 0
      % update from PRES via a relative pressure
      relPres = sample_data.variables{idPres}.data - min(sample_data.variables{idPres}.data);
      if ~isempty(sample_data.geospatial_lat_min) && ~isempty(sample_data.geospatial_lat_max)
          % compute vertical min/max with SeaWater toolbox
          if sample_data.geospatial_lat_min == sample_data.geospatial_lat_max
              computedMedianDepth = sw_dpth(median(relPres), ...
                  sample_data.geospatial_lat_min);
              computedMinDepth = sw_dpth(min(relPres), ...
                  sample_data.geospatial_lat_min);
              computedMaxDepth = sw_dpth(max(relPres), ...
                  sample_data.geospatial_lat_min);
          else
              computedMedianDepth = sw_dpth(median(relPres), ...
                  sample_data.geospatial_lat_min + (sample_data.geospatial_lat_max - sample_data.geospatial_lat_min)/2);
              computedMinDepth = sw_dpth(min(relPres), ...
                  sample_data.geospatial_lat_min + (sample_data.geospatial_lat_max - sample_data.geospatial_lat_min)/2);
              computedMaxDepth = sw_dpth(max(relPres), ...
                  sample_data.geospatial_lat_min + (sample_data.geospatial_lat_max - sample_data.geospatial_lat_min)/2);
          end
      else
          % without latitude information, we assume 1dBar ~= 1m
          computedMedianDepth = median(relPres);
          computedMinDepth = min(relPres);
          computedMaxDepth = max(relPres);
      end
      computedMedianDepth = round(computedMedianDepth*100)/100;
      computedMinDepth = round(computedMinDepth*100)/100;
      computedMaxDepth = round(computedMaxDepth*100)/100;
      
      if idSDepth > 0 && idHeight > 0
          % ADCP
          % Let's compare this computed depth from pressure
          % with the maximum distance the ADCP can measure
          maxDistance = round(max(sample_data.dimensions{idHeight}.data)*100)/100;
          diff = abs(maxDistance - computedMedianDepth)/max(maxDistance, computedMedianDepth);
          
          % update sensor_depth metadata from data if
          % empty
          if isempty(sample_data.sensor_depth)
              if diff < 10/100 && ...
                      ~isempty(sample_data.geospatial_lat_min) && ~isempty(sample_data.geospatial_lat_max)
                  % Depth from PRES Ok if diff < 10% and latitude
                  % filled
                  sample_data.sensor_depth = computedMedianDepth;
                  sample_data.sensor_depth_source = ...
                      'Depth computed from median of pressure measurements and latitude (SeaWater toolbox).';
              else
                  % Depth is taken from maxDistance between ADCP and bins
                  sample_data.sensor_depth = maxDistance;
                  sample_data.sensor_depth_source = ...
                      'Depth assumed as the distance between the ADCP''s tranducers and the furthest bin measured.';
              end
              metadataChanged = true;
          end
          
          % we assume that data is collected between the
          % vertical extremes of surface and sensor depth
          if isempty(sample_data.geospatial_vertical_min) && isempty(sample_data.geospatial_vertical_max)
              sample_data.geospatial_vertical_min = 0;
              sample_data.geospatial_vertical_max = sample_data.sensor_depth;
              metadataChanged = true;
          end
      else
          % CTD
          % Let's find out if it's a profile CTD or a moored CTD
          nDataDeploying = 0;
          nDataMooring = 0;
          
          if idPres > 0
              maxPressure = max(relPres);
              threshold = maxPressure - maxPressure*20/100;
              iDataDeploying = relPres < threshold;
              nDataDeploying = sum(iDataDeploying);
              nDataMooring = sum(~iDataDeploying);
          end
          
          if nDataDeploying < nDataMooring/10 || idPres == 0
              % Moored => geospatial_vertical_min ~=
              % geospatial_vertical_max
              if isempty(sample_data.geospatial_vertical_min) && isempty(sample_data.geospatial_vertical_max)
                  sample_data.geospatial_vertical_min = computedMedianDepth;
                  sample_data.geospatial_vertical_max = computedMedianDepth;
                  metadataChanged = true;
              end
          else
              % Profile
              if isempty(sample_data.geospatial_vertical_min) && isempty(sample_data.geospatial_vertical_max)
                  sample_data.geospatial_vertical_min = computedMinDepth;
                  sample_data.geospatial_vertical_max = computedMaxDepth;
                  metadataChanged = true;
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
  
  % SENSOR_DEPTH
  if ~isempty(sample_data.sensor_depth) && idSDepth > 0
      sample_data.dimensions{idSDepth}.data = sample_data.sensor_depth;
  end
  
  % regenerate table content
  if metadataChanged
      hPanel = findobj('Tag', 'metadataPanel');
      updateViewMetadata(hPanel, sample_data);
  end
end