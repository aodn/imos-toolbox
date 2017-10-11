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
narginchk(2, 3);

if ~iscell(sample_data), error('sample_data must be a cell array'); end
if isempty(sample_data), return;                                    end

% no modification of data is performed on the raw FV00 dataset except
% local time to UTC conversion
if strcmpi(qcLevel, 'raw'), return; end

% auto logical in input to enable running under batch processing
if nargin<3, auto=false; end

ParamFile = ['Preprocessing' filesep 'rinkoDoPP.txt'];
voltDOLabel     = readProperty('voltDO', ParamFile);
voltTempDOLabel = readProperty('voltTempDO', ParamFile);

for k = 1:length(sample_data)
    
    sam = sample_data{k};
    
    voltDOIdx     = getVar(sam.variables, ['volt_' voltDOLabel]);
    voltTempDOIdx = getVar(sam.variables, ['volt_' voltTempDOLabel]);
    
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
    
    % volt DO, volt temp DO, and pres/pres_rel or nominal depth not present in data set
    if ~(voltDOIdx && voltTempDOIdx && (isPresVar || isDepthInfo)), continue; end
    
    voltDO = sam.variables{voltDOIdx}.data;
    voltTempDO = sam.variables{voltTempDOIdx}.data;
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
            
            % any depth values <= -5 are discarded (reminder, depth is
            % positive down), this allow use of gsw_p_from_z without error.
            depth(depth <= -5) = NaN;
    
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
            
            presRel = sam.instrument_nominal_depth * ones(size(sam.dimensions{dimIdx}.data));
            presName = 'instrument_nominal_depth (assuming 1 m ~ 1 dbar)';
        end
    end
    
    % define Temp DO coefficients
    A = str2double(readProperty('aTempDO', ParamFile));
    B = str2double(readProperty('bTempDO', ParamFile));
    C = str2double(readProperty('cTempDO', ParamFile));
    D = str2double(readProperty('dTempDO', ParamFile));
    
    tempDO = A + B*voltTempDO + C*voltTempDO.^2 + D*voltTempDO.^3;
    
    % define DO coefficients
    A = str2double(readProperty('aDO', ParamFile));
    B = str2double(readProperty('bDO', ParamFile));
    C = str2double(readProperty('cDO', ParamFile));
    D = str2double(readProperty('dDO', ParamFile));
    E = str2double(readProperty('eDO', ParamFile));
    F = str2double(readProperty('fDO', ParamFile));
    G = str2double(readProperty('gDO', ParamFile));
    H = str2double(readProperty('hDO', ParamFile));
    
    % RINKO III correction formulae on temperature
    DO = A./(1 + D*(tempDO - 25)) + B./((voltDO - F).*(1 + D*(tempDO - 25)) + C + F);
    
    % correction for the ageing sensing foil
    DO = G + H*DO;
    
    % correction for pressure
    DO = DO.*(1 + E*presRel/100); % pressRel/100 => conversion dBar to MPa (see rinko correction formula pdf). DO is in % of dissolved oxygen during calibration at this stage.
    
    % add DO data as new variable in data set
    dimensions = sam.variables{voltDOIdx}.dimensions;
    
    doComment = ['rinkoDoPP.m: dissolved oxygen in % of saturation derived ' ...
        'from rinko dissolved oxygen and temperature voltages and ' presName ...
        ' using the RINKO III Correction method on Temperature and Pressure ' ...
        'with instrument and calibration coefficients.'];
    tempDoComment = ['rinkoDoPP.m: temperature for dissolved oxygen sensor ' ...
        'derived from rinko temperature voltages.'];
    
    if isfield(sam.variables{voltDOIdx}, 'coordinates')
        coordinates = sam.variables{voltDOIdx}.coordinates;
    else
        coordinates = '';
    end
    
    sample_data{k} = addVar(...
        sam, ...
        'DOXS', ...
        DO, ...
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