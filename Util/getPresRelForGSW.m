function [ presRel, presName ] = getPresRelForGSW( sam )
%GETPRESRELFORGSW retrieves values of pressure due to sea water in sam for 
% use in the Gibbs-SeaWater toolbox (TEOS-10). 
%
% In priority will be considered in sam the following source of presRel 
% values:
%   1. PRES_REL
%   2. PRES - 1 atmosphere
%   3. gsw_p_from_z(-DEPTH, LATITUDE)
%   4. DEPTH
%   5. gsw_p_from_z(-instrument_nominal_depth, LATITUDE)
%   6. instrument_nominal_depth
%
% Inputs:
%   sam         - structure data set.
%
% Outputs:
%   presRel     - the pressure due to sea water data retrieved from sam for
%               use in GSW.
%   presName    - the name of the variable in sam and the method used to 
%               produce presRel.
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
narginchk(1, 1);

if ~isstruct(sam),  error('sam must be a struct');  end
if isempty(sam),    return;                         end

presRel = NaN;
presName = '';

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

if ~(isPresVar || isDepthInfo), return; end

% pressure information used for Gibbs SeaWater toolbox is from the
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

