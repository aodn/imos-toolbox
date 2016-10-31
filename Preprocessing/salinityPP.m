function sample_data = salinityPP( sample_data, qcLevel, auto )
%SALINITYPP Adds a salinity variable to the given data sets, if they
% contain conductivity, temperature pressure and depth variables or nominal depth
% information. 
%
% This function uses the Gibbs-SeaWater toolbox (TEOS-10) to derive salinity
% data from conductivity, temperature and pressure. It adds the salinity 
% data as a new variable in the data sets. Data sets which do not contain 
% conductivity, temperature pressure and depth variables or nominal depth 
% information are left unmodified.
%
% Inputs:
%   sample_data - cell array of data sets, ideally with conductivity, 
%                 temperature and pressure variables.
%   qcLevel     - string, 'raw' or 'qc'. Some pp not applied when 'raw'.
%   auto        - logical, run pre-processing in batch mode.
%
% Outputs:
%   sample_data - the same data sets, with salinity variables added.
%
% Author:       Paul McCarthy <paul.mccarthy@csiro.au>
% Contributor:  Guillaume Galibert <guillaume.galibert@utas.edu.au>
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
narginchk(2, 3);

if ~iscell(sample_data), error('sample_data must be a cell array'); end
if isempty(sample_data), return;                                    end

% no modification of data is performed on the raw FV00 dataset except
% local time to UTC conversion
if strcmpi(qcLevel, 'raw'), return; end

% auto logical in input to enable running under batch processing
if nargin<3, auto=false; end

for k = 1:length(sample_data)
  
  sam = sample_data{k};
  
  cndcIdx       = getVar(sam.variables, 'CNDC');
  tempIdx       = getVar(sam.variables, 'TEMP');
  
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
  
  % cndc, temp, and pres/pres_rel or nominal depth not present in data set
  if ~(cndcIdx && tempIdx && (isPresVar || isDepthInfo)), continue; end
  
  % data set already contains salinity
  if getVar(sam.variables, 'PSAL'), continue; end
  
  cndc = sam.variables{cndcIdx}.data;
  temp = sam.variables{tempIdx}.data;
  
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
  
  % calculate C(S,T,P)/C(35,15,0) ratio
  % conductivity is in S/m and gsw_C3515 in mS/cm
  R = 10*cndc ./ gsw_C3515;
  
  % calculate salinity
  psal = gsw_SP_from_R(R, temp, presRel);
  
  dimensions = sam.variables{tempIdx}.dimensions;
  salinityComment = ['salinityPP.m: derived from CNDC, TEMP and ' presName ' using the Gibbs-SeaWater toolbox (TEOS-10) v3.05'];
  
  if isfield(sam.variables{tempIdx}, 'coordinates')
      coordinates = sam.variables{tempIdx}.coordinates;
  else
      coordinates = '';
  end
    
  % add salinity data as new variable in data set
  sample_data{k} = addVar(...
    sam, ...
    'PSAL', ...
    psal, ...
    dimensions, ...
    salinityComment, ...
    coordinates);

    history = sample_data{k}.history;
    if isempty(history)
        sample_data{k}.history = sprintf('%s - %s', datestr(now_utc, readProperty('exportNetCDF.dateFormat')), salinityComment);
    else
        sample_data{k}.history = sprintf('%s\n%s - %s', history, datestr(now_utc, readProperty('exportNetCDF.dateFormat')), salinityComment);
    end
end
