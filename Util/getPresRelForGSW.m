function [ presRel, zName, zComment ] = getPresRelForGSW( sam )
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
%   zName       - the name of the variable in sam.
%   zComment    - the method used to produce presRel.
%
% Author:       Guillaume Galibert <guillaume.galibert@utas.edu.au>
%

%
% Copyright (C) 2017, Australian Ocean Data Network (AODN) and Integrated 
% Marine Observing System (IMOS).
%
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation version 3 of the License.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
% GNU General Public License for more details.

% You should have received a copy of the GNU General Public License
% along with this program.
% If not, see <https://www.gnu.org/licenses/gpl-3.0.en.html>.
%
narginchk(1, 1);

if ~isstruct(sam),  error('sam must be a struct');  end
if isempty(sam),    return;                         end

qcSet    = str2double(readProperty('toolbox.qc_set'));
rawFlag  = imosQCFlag('raw',  qcSet, 'flag');
goodFlag = imosQCFlag('good', qcSet, 'flag');
probGoodFlag = imosQCFlag('probablyGood', qcSet, 'flag');
goodFlags = [rawFlag, goodFlag, probGoodFlag];

presRel = NaN;
zName = '';
zComment = '';

presIdx       = getVar(sam.variables, 'PRES');
if presIdx
    if isfield(sam.variables{presIdx}, 'flags')
        % we don't want to consider PRES if it's all rubbish
        if ~any(ismember(sam.variables{presIdx}.flags, goodFlags))
            presIdx = 0;
        end
    end
end
presRelIdx    = getVar(sam.variables, 'PRES_REL');
if presRelIdx
    if isfield(sam.variables{presRelIdx}, 'flags')
        % we don't want to consider PRES_REL if it's all rubbish
        if ~any(ismember(sam.variables{presRelIdx}.flags, goodFlags))
            presRelIdx = 0;
        end
    end
end
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
        zName = 'PRES_REL';
    else
        % update from a relative pressure like SeaBird computes
        % it in its processed files, substracting a constant value
        % 10.1325 dbar for nominal atmospheric pressure
        presRel = sam.variables{presIdx}.data - gsw_P0/10^4;
        zName = 'PRES';
        zComment = 'substracting a constant value 10.1325 dbar for nominal atmospheric pressure';
    end
else
    % when no pressure variable exists, we use depth information either
    % from the DEPTH variable or from the instrument_nominal_depth
    % global attribute
    if depthIdx > 0
        % with depth data
        depth = sam.(depthType){depthIdx}.data;
        zName = 'DEPTH';
    else
        % with nominal depth information
        
        % get the toolbox execution mode
        mode = readProperty('toolbox.mode');
        switch mode
            case 'profile'
                dimIdx = getVar(sam.dimensions, 'DEPTH');
                if dimIdx == 0
                    dimIdx = getVar(sam.dimensions, 'MAXZ');
                end
                
            case 'timeSeries'
                dimIdx = getVar(sam.dimensions, 'TIME');
                
            otherwise
                return;
                
        end
        
        depth = sam.instrument_nominal_depth * ones(size(sam.dimensions{dimIdx}.data));
        zName = 'instrument_nominal_depth';
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
        zComment = '(assuming 1 m ~ 1 dbar)';
    end
end

end

