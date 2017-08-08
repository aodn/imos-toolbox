function [presRel, presName] = presRelFromSampleData(sam)

% get the pressure relative to the sea surface from the sample data, use
% the best value from
% 1. measured PRES_REL
% 2. measured PRES -> convert to PRES_REL by subtracting atmospheric pressure
% 3. DEPTH variable from gsw_pres_from_z if latitude is avaliable,
%          else lets just assume pres_rel = depth
%

  tempIdx       = getVar(sam.variables, 'TEMP');
  temp = sam.variables{tempIdx}.data;

  presIdx       = getVar(sam.variables, 'PRES');
  presRelIdx    = getVar(sam.variables, 'PRES_REL');
  isPresVar     = logical(presIdx || presRelIdx);
  
  isDepthInfo   = false;
  depthType     = 'variables';
  depthIdx      = getVar(sam.(depthType), 'DEPTH');
  if depthIdx == 0
      depthType     = 'dimensions';
      depthIdx      = getVar(sam.(depthType), 'DEPTH');
  end
  if depthIdx > 0, isDepthInfo = true; end
  
  if isfield(sam, 'instrument_nominal_depth')
      if ~isempty(sam.instrument_nominal_depth)
          isDepthInfo = true;
      end
  end
  
  presRel = [];
  presName = '';
  
  % temp, and pres/pres_rel or nominal depth not present in data set
  if ~(tempIdx && (isPresVar || isDepthInfo)), return; end
  
% pressure information used for Salinity computation is from the
  % PRES or PRES_REL variables in priority
  if isPresVar
      if presRelIdx > 0
          presRel = sam.variables{presRelIdx}.data;
          presName = 'PRES_REL';
      else
          % update from a relative pressure like SeaBird computes
          % it in its processed files, substracting a constant value
          % 10.1325 dbar for nominal atmospheric pressure
          presRel = sam.variables{presIdx}.data - gsw_P0/10^4;
          presName = 'PRES substracting a constant value 10.1325 dbar for nominal atmospheric pressure';
      end
  else
      % when no pressure variable exists, we use depth information either 
      % from the DEPTH variable or from the instrument_nominal_depth 
      % global attribute
      if depthIdx > 0
          % with depth data
          depth = sam.(depthType){depthIdx}.data;
          presName = 'DEPTH';
      else
          % with nominal depth information
          depth = sam.instrument_nominal_depth*ones(size(temp));
          presName = 'instrument_nominal_depth';
      end
      
      % any depth values <= -5 are discarded (reminder, depth is
      % positive down), this allow use of gsw_p_from_z without error.
      depth(depth <= -5) = NaN;
      
      % pressure information needed for Salinity computation is either
      % retrieved from gsw_p_from_z when latitude is available or by 
      % simply assuming 1dbar ~= 1m
      if ~isempty(sam.geospatial_lat_min) && ~isempty(sam.geospatial_lat_max)
          % compute depth with Gibbs-SeaWater toolbox
          % relative_pressure ~= gsw_p_from_z(-depth, latitude)
          if sam.geospatial_lat_min == sam.geospatial_lat_max
              presRel = gsw_p_from_z(-depth, sam.geospatial_lat_min);
          else
              meanLat = sam.geospatial_lat_min + ...
                  (sam.geospatial_lat_max - sam.geospatial_lat_min)/2;
              presRel = gsw_p_from_z(-depth, meanLat);
          end
      else
          % without latitude information, we assume 1dbar ~= 1m
          presRel = depth;
          presName = [presName ' (assuming 1 m ~ 1 dbar)'];
      end
  end
end
