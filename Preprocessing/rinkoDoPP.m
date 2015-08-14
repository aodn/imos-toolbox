function sample_data = rinkoDoPP( sample_data, qcLevel, auto )
%RINKODOPP Adds a disolved oxygen variable to the given data sets, if they
% contain analog voltages from Rinko temperature and DO sensors.
%
% This function uses the Rinko formula + coefficients calibration and
% atmospheric pressure at the time of calibration.
%
% Inputs:
%   sample_data - cell array of data sets, ideally with conductivity, 
%                 temperature and pressure variables.
%   qcLevel     - string, 'raw' or 'qc'. Some pp not applied when 'raw'.
%   auto        - logical, run pre-processing in batch mode.
%
% Outputs:
%   sample_data - the same data sets, with dissolved oxygen variables added.
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
error(nargchk(2, 3, nargin));

if ~iscell(sample_data), error('sample_data must be a cell array'); end
if isempty(sample_data), return;                                    end

if strcmpi(qcLevel, 'raw'), return; end

% auto logical in input to enable running under batch processing
if nargin<3, auto=false; end

for k = 1:length(sample_data)
  
  sam = sample_data{k};
  
  rinko01Idx    = getVar(sam.variables, 'volt_RINKO1');
  rinko02Idx    = getVar(sam.variables, 'volt_RINKO2');
  
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
  
  % volt do, volt do temp, and pres/pres_rel or nominal depth not present in data set
  if ~(rinko01Idx && rinko02Idx && (isPresVar || isDepthInfo)), continue; end
  
  % data set already contains DOXS
  if getVar(sam.variables, 'DOXS'), continue; end
  
  voltDO = sam.variables{rinko01Idx}.data;
  voltTempDO = sam.variables{rinko02Idx}.data;
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
      if depthIdx > 0
          depth = sam.(depthType){depthIdx}.data;
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
              presName = 'DEPTH';
          else
              % without latitude information, we assume 1dbar ~= 1m
              presRel = depth;
              presName = 'DEPTH (assuming 1 m ~ 1 dbar)';
          end
          
      else
          presRel = sam.instrument_nominal_depth*ones(size(temp));
          presName = 'instrument_nominal_depth (assuming 1 m ~ 1 dbar)';
      end
  end
  
  % define Temp DO coefficients
  A = -5.015006;
  B = 16.78886;
  C = -2.211178;
  D = 0.4738992;
  
  tempDO = A + B*voltTempDO + C*voltTempDO.^2 + D*voltTempDO.^3;
  
  % define DO coefficients
  A = -43.32265;
  B = 144.4138;
  C = -0.3548429;
  D = 0.0105;
  E = 0.0053;
  F = 0;
  
  ParamFile = ['Preprocessing' filesep 'rinkoDoPP.txt'];
  G = str2double(readProperty('G', ParamFile, ','));
  H = str2double(readProperty('H', ParamFile, ','));
  
  % RINKO III correction formulae on temperature
  DO = A/(1 + D*(tempDO - 25)) + B/((voltDO - F).*(1 + D*(tempDO - 25)) + C + F);
  
  % correction for the ageing sensing foil
  DO = G + H*DO';
  
  % correction for pressure
  DO = DO.*(1 + E*presRel);
  
  % must be between 0 and 1
  DO(DO<0) = NaN;
  DO(DO>1) = NaN;
  
  dimensions = sam.variables{rinko01Idx}.dimensions;
  doComment = ['rinkoDoPP.m: dissolved oxygen derived from rinko dissolved oxygen and temperature voltages and ' presName ' using the RINKO III Correction method on Temperature and Pressure with G=' num2str(G) ' and H=' num2str(H) '.'];
  tempDoComment = 'rinkoDoPP.m: temperature for dissolved oxygen sensor derived from rinko temperature voltages.';
  
  if isfield(sam.variables{rinko01Idx}, 'coordinates')
      coordinates = sam.variables{rinko01Idx}.coordinates;
  else
      coordinates = '';
  end
    
  % add DO data as new variable in data set
  sample_data{k} = addVar(...
    sam, ...
    'DOXS', ...
    DO*100, ... % percentage
    dimensions, ...
    doComment, ...
    coordinates);

  sample_data{k} = addVar(...
    sample_data{k}, ...
    'DOXY_TEMP', ...
    tempDO, ...
    dimensions, ...
    tempDoComment, ...
    coordinates);

    history = sample_data{k}.history;
    if isempty(history)
        sample_data{k}.history = sprintf('%s - %s', datestr(now_utc, readProperty('exportNetCDF.dateFormat')), doComment);
        sample_data{k}.history = sprintf('%s\n%s - %s', history, datestr(now_utc, readProperty('exportNetCDF.dateFormat')), tempDoComment);
    else
        sample_data{k}.history = sprintf('%s\n%s - %s', history, datestr(now_utc, readProperty('exportNetCDF.dateFormat')), doComment);
        sample_data{k}.history = sprintf('%s\n%s - %s', history, datestr(now_utc, readProperty('exportNetCDF.dateFormat')), tempDoComment);
    end
end
