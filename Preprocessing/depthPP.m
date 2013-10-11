function sample_data = depthPP( sample_data, auto )
%DEPTHPP Adds a depth variable to the given data sets, if they contain a
% pressure variable.
%
% This function uses the Gibbs-SeaWater toolbox (TEOS-10) to derive depth data
% from pressure. It adds the depth data as a new variable in the data sets.
% Data sets which do not contain a pressure variable are left unmodified 
% when loaded alone. Data sets which do not contain a pressure variable
% loaded along with data sets which contain a pressure variable on the same
% mooring, will have a depth variable calculated from the other pressure 
% information knowing distances between each others.
%
% This function uses the latitude from metadata. Without any latitude information,
% 1 dbar ~= 1 m.
%
% Inputs:
%   sample_data - cell array of data sets, ideally with pressure variables.
%   auto - logical, run pre-processing in batch mode
%
% Outputs:
%   sample_data - the same data sets, with depth variables added.
%
% Author:       Paul McCarthy <paul.mccarthy@csiro.au>
% Contributor:  Guillaume Galibert <guillaume.galibert@utas.edu.au>
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
error(nargchk(1, 2, nargin));

if ~iscell(sample_data), error('sample_data must be a cell array'); end
if isempty(sample_data), return;                                    end

% auto logical in input to enable running under batch processing
if nargin<2, auto=false; end

% read options from parameter file
depthFile       = ['Preprocessing' filesep 'depthPP.txt'];
same_family    = readProperty('same_family', depthFile, ',');
include         = readProperty('include', depthFile, ',');
exclude         = readProperty('exclude', depthFile, ',');

if strcmpi(same_family, 'yes')
    same_family = true;
else
    same_family = false;
end

if ~isempty(include)
    include = textscan(include, '%s');
    include = include{1};
end
if ~isempty(exclude)
    exclude = textscan(exclude, '%s');
    exclude = exclude{1};
end

% check wether height or target depth information is documented
isSensorHeight = false;
isSensorTargetDepth = false;

if isfield(sample_data{1}, 'instrument_nominal_height')
    if ~isempty(sample_data{1}.instrument_nominal_height)
        isSensorHeight = true;
    end
else
    
end

if isfield(sample_data{1}, 'instrument_nominal_depth')
    if ~isempty(sample_data{1}.instrument_nominal_depth)
        isSensorTargetDepth = true;
    end
else
    
end

% loop on every data sets
for k = 1:length(sample_data)
    % current data set
    curSam = sample_data{k};
    
    % if data set already contains depth data then next sample data
    if getVar(curSam.variables, 'DEPTH'), continue; end
    if getVar(curSam.dimensions, 'DEPTH'), continue; end
    
    presIdx     = getVar(curSam.variables, 'PRES');
    presRelIdx  = getVar(curSam.variables, 'PRES_REL');
    
    % if no pressure data, try to compute it from other sensors in the
    % mooring, otherwise go to next sample data
    if presIdx == 0 && presRelIdx == 0
        if isSensorHeight || isSensorTargetDepth
            % let's see if part of a mooring with pressure data from other
            % sensors
            m = 0;
            otherSam = [];
            % loop on every other data sets
            for l = 1:length(sample_data)
                sam = sample_data{l};
                
                presCurIdx      = getVar(sam.variables, 'PRES');
                presRelCurIdx   = getVar(sam.variables, 'PRES_REL');
                
                % samples without pressure information are excluded
                if (presCurIdx == 0 && presRelCurIdx == 0), continue; end
                
                if isSensorHeight
                    samSensorZ = sam.instrument_nominal_height;
                else
                    samSensorZ = sam.instrument_nominal_depth;
                end
                
                % current sample or samples without vertical nominal 
                % information are excluded
                if l == k || isempty(samSensorZ), continue; end
                
                % only samples that are from the same instrument
                % family/brand of the current sample are selected
                samSource = textscan(sam.instrument, '%s');
                samSource = samSource{1};
                p = 0;
                % is from the same family
                if same_family
                    % loop on every words composing the instrument global
                    % attribute of current other data set
                    for n = 1:length(samSource)
                        if ~isempty(strfind(curSam.instrument, samSource{n}))
                            p = 1;
                        end
                    end
                else
                    p = 1;
                end
                
                % loop on every words that would include current other data set
                for n = 1:length(include)
                    % is included
                    if ~isempty(strfind(sam.instrument, include{n}))
                        p = 1;
                    end
                end
                
                % loop on every words that would exclude current other data set
                for n = 1:length(exclude)
                    % is excluded
                    if ~isempty(strfind(sam.instrument, exclude{n}))
                        p = 0;
                    end
                end
                
                if p > 0
                    m = m+1;
                    otherSam{m} = sam;
                end
                clear sam;
            end
            
            if m == 0
                fprintf('%s\n', ['Warning : ' curSam.toolbox_input_file ...
                    ' there is no pressure sensor on this mooring from '...
                    'which an actual depth can be computed']);
                continue;
            else
                % find the nearests pressure data
                diffWithOthers = nan(m,1);
                iFirst  = [];
                iSecond = [];
                for l = 1:m
                    if isSensorHeight
                        diffWithOthers(l) = curSam.instrument_nominal_height - otherSam{l}.instrument_nominal_height;
                    else
                        diffWithOthers(l) = curSam.instrument_nominal_depth - otherSam{l}.instrument_nominal_depth;
                    end
                end
                
                iAbove = diffWithOthers(diffWithOthers >= 0);
                iBelow = diffWithOthers(diffWithOthers < 0);
                
                if ~isempty(iAbove)
                    iAbove = find(diffWithOthers == min(iAbove), 1);
                end
                
                if ~isempty(iBelow)
                    iBelow = find(diffWithOthers == max(iBelow), 1);
                end
                
                if isempty(iAbove) && ~isempty(iBelow)
                    iFirst = iBelow;
                    
                    % let's find the second nearest below
                    newDiffWithOthers = diffWithOthers;
                    newDiffWithOthers(iFirst) = NaN;
                    distance = 0;
                    
                    distMin = 10;
                    while distance < distMin && ~all(isnan(newDiffWithOthers))
                        iNextBelow = find(diffWithOthers == max(newDiffWithOthers(newDiffWithOthers < 0)), 1);
                        distance = abs(diffWithOthers(iBelow) - diffWithOthers(iBelow));
                        if distance >= distMin
                            iSecond = iNextBelow;
                            break;
                        end
                        newDiffWithOthers(iNextBelow) = NaN;
                    end
                elseif isempty(iBelow) && ~isempty(iAbove)
                    iFirst = iAbove;
                else
                    iFirst  = iAbove;
                    iSecond = iBelow;
                end
                
                if isempty(iSecond)
                    fprintf('%s\n', ['Warning : ' curSam.toolbox_input_file ...
                        ' computing actual depth from only one pressure sensor '...
                        'on mooring']);
                    % we found only one sensor (it is above)
                    otherSam = otherSam{iFirst};
                    presIdxOther = getVar(otherSam.variables, 'PRES');
                    presRelIdxOther = getVar(otherSam.variables, 'PRES_REL');
                    
                    if presRelIdxOther == 0
                        % update from an absolute pressure like SeaBird computes
                        % a relative pressure in its processed files, substracting a constant value
                        % 10.1325 dbar for nominal atmospheric pressure
                        relPresOther = otherSam.variables{presIdxOther}.data - gsw_P0/10^4;
                        presComment = ['absolute '...
                            'pressure measurements to which a nominal '...
                            'value for atmospheric pressure (10.1325 dbar) '...
                            'has been substracted'];
                    else
                        % update from a relative pressure measurement
                        relPresOther = otherSam.variables{presRelIdxOther}.data;
                        presComment = ['relative '...
                            'pressure measurements (calibration offset '...
                            'usually performed to balance current '...
                            'atmospheric pressure and acute sensor '...
                            'precision at a deployed depth)'];
                    end
                    
                    % compute pressure at current sensor assuming sensors
                    % repartition on a vertical line between current sensor
                    % and the nearest. This is the best we can do as we can't
                    % have any idea of the angle of the mooring with one
                    % pressure sensor (could consider the min pressure value
                    % in the future?).
                    %
                    % computedDepth  = depthOther  + distOtherCurSensor 
                    % computedHeight = heightOther - distOtherCurSensor 
                    %
                    % vertical axis is positive down when talking about
                    % depth
                    %
                    if isSensorHeight
                        distOtherCurSensor = otherSam.instrument_nominal_height - curSam.instrument_nominal_height;
                    else
                        distOtherCurSensor = curSam.instrument_nominal_depth - otherSam.instrument_nominal_depth;
                    end
                    
                    if ~isempty(curSam.geospatial_lat_min) && ~isempty(curSam.geospatial_lat_max)
                        % compute depth with Gibbs-SeaWater toolbox
                        % depth ~= - gsw_z_from_p(relative_pressure, latitude)
                        if curSam.geospatial_lat_min == curSam.geospatial_lat_max
                            zOther = - gsw_z_from_p(relPresOther, curSam.geospatial_lat_min);
                            clear relPresOther;
                            
                            computedDepthComment  = ['depthPP: Depth computed from '...
                                'the only pressure sensor available, using the '...
                                'Gibbs-SeaWater toolbox (TEOS-10) v3.02 from latitude and '...
                                presComment '.'];
                        else
                            meanLat = curSam.geospatial_lat_min + ...
                                (curSam.geospatial_lat_max - curSam.geospatial_lat_min)/2;
                            zOther = - gsw_z_from_p(relPresOther, meanLat);
                            clear relPresOther;
                            
                            computedDepthComment  = ['depthPP: Depth computed from '...
                                'the only pressure sensor available, using the '...
                                'Gibbs-SeaWater toolbox (TEOS-10) v3.02 from mean latitude and '...
                                presComment '.'];
                        end
                    else
                        % without latitude information, we assume 1dbar ~= 1m
                        zOther = relPresOther;
                        clear relPresOther;
                        
                        computedDepthComment  = ['depthPP: Depth computed from '...
                            'the only pressure sensor available with '...
                            presComment ', assuming 1dbar ~= 1m.'];
                    end
                    
                    tOther = otherSam.dimensions{getVar(otherSam.dimensions, 'TIME')}.data;
                    tCur = curSam.dimensions{getVar(curSam.dimensions, 'TIME')}.data;
                    clear otherSam;
                    
                    % let's interpolate the other data set depth values in time
                    % to fit with the current data set time values
                    zOther = interp1(tOther, zOther, tCur);
                    clear tOther tCur;
                    
                    computedDepth = zOther + distOtherCurSensor;
                    clear zOther;
                else
                    samFirst            = otherSam{iFirst};
                    presIdxFirst        = getVar(samFirst.variables, 'PRES');
                    presRelIdxFirst     = getVar(samFirst.variables, 'PRES_REL');
                    
                    samSecond           = otherSam{iSecond};
                    presIdxSecond       = getVar(samSecond.variables, 'PRES');
                    presRelIdxSecond    = getVar(samSecond.variables, 'PRES_REL');
                    clear otherSam;
                    
                    if presIdxFirst ~= 0 && presIdxSecond ~= 0
                        % update from an absolute pressure like SeaBird computes
                        % a relative pressure in its processed files, substracting a constant value
                        % 10.1325 dbar for nominal atmospheric pressure
                        relPresFirst    = samFirst.variables{presIdxFirst}.data - gsw_P0/10^4;
                        relPresSecond   = samSecond.variables{presIdxSecond}.data - gsw_P0/10^4;
                        presComment     = ['absolute '...
                            'pressure measurements to which a nominal '...
                            'value for atmospheric pressure (10.1325 dbar) '...
                            'has been substracted'];
                    elseif presIdxFirst ~= 0 && presIdxSecond == 0
                        relPresFirst    = samFirst.variables{presIdxFirst}.data - gsw_P0/10^4;
                        relPresSecond   = samSecond.variables{presRelIdxSecond}.data;
                        presComment     = ['relative and absolute '...
                            'pressure measurements to which a nominal '...
                            'value for atmospheric pressure (10.1325 dbar) '...
                            'has been substracted'];
                    elseif presIdxFirst == 0 && presIdxSecond ~= 0
                        relPresFirst    = samFirst.variables{presRelIdxFirst}.data;
                        relPresSecond   = samSecond.variables{presIdxSecond}.data - gsw_P0/10^4;
                        presComment     = ['relative and absolute '...
                            'pressure measurements to which a nominal '...
                            'value for atmospheric pressure (10.1325 dbar) '...
                            'has been substracted'];
                    else
                        % update from a relative measured pressure
                        relPresFirst    = samFirst.variables{presRelIdxFirst}.data;
                        relPresSecond   = samSecond.variables{presRelIdxSecond}.data;
                        presComment     = ['relative '...
                            'pressure measurements (calibration offset '...
                            'usually performed to balance current '...
                            'atmospheric pressure and acute sensor '...
                            'precision at a deployed depth)'];
                    end
                    
                    % compute pressure at current sensor using trigonometry and
                    % assuming sensors repartition on a line between the two
                    % nearest pressure sensors
                    if isSensorHeight
                        distFirstSecond     = samFirst.instrument_nominal_height - samSecond.instrument_nominal_height;
                        distFirstCurSensor  = samFirst.instrument_nominal_height - curSam.instrument_nominal_height;
                    else
                        distFirstSecond     = samFirst.instrument_nominal_depth - samSecond.instrument_nominal_depth;
                        distFirstCurSensor  = samFirst.instrument_nominal_depth - curSam.instrument_nominal_depth;
                    end
                    
                    % theta is the angle between the vertical and line
                    % formed by the sensors
                    %
                    % cos(theta) = depthFirstSecond/distFirstSecond
                    % and
                    % cos(theta) = depthFirstCurSensor/distFirstCurSensor
                    %
                    % computedDepth = (distFirstCurSensor/distFirstSecond) ...
                    %        * (zSecond - zFirst) + zFirst
                    %
                    % pressure = density*gravity*depth
                    %
                    if ~isempty(curSam.geospatial_lat_min) && ~isempty(curSam.geospatial_lat_max)
                        % compute depth with Gibbs-SeaWater toolbox
                        % depth ~= - gsw_z_from_p(relative_pressure, latitude)
                        if curSam.geospatial_lat_min == curSam.geospatial_lat_max
                            zFirst = - gsw_z_from_p(relPresFirst, curSam.geospatial_lat_min);
                            zSecond = - gsw_z_from_p(relPresSecond, curSam.geospatial_lat_min);
                            clear relPresFirst relPresSecond;
                            
                            computedDepthComment  = ['depthPP: Depth computed from '...
                                'the 2 nearest pressure sensors available, using the '...
                                'Gibbs-SeaWater toolbox (TEOS-10) v3.02 from latitude and '...
                                presComment '.'];
                        else
                            meanLat = curSam.geospatial_lat_min + ...
                                (curSam.geospatial_lat_max - curSam.geospatial_lat_min)/2;
                            
                            zFirst = - gsw_z_from_p(relPresFirst, meanLat);
                            zSecond = - gsw_z_from_p(relPresSecond, meanLat);
                            clear relPresFirst relPresSecond;
                            
                            computedDepthComment  = ['depthPP: Depth computed from '...
                                'the 2 nearest pressure sensors available, using the '...
                                'Gibbs-SeaWater toolbox (TEOS-10) v3.02 from mean latitude and '...
                                presComment '.'];
                        end
                    else
                        % without latitude information, we assume 1dbar ~= 1m
                        zFirst = relPresFirst;
                        zSecond = relPresSecond;
                        clear relPresFirst relPresSecond;
                        
                        computedDepthComment  = ['depthPP: Depth computed from '...
                            'the 2 nearest pressure sensors available with '...
                            presComment ', assuming 1dbar ~= 1m.'];
                    end
                    
                    tFirst = samFirst.dimensions{getVar(samFirst.dimensions, 'TIME')}.data;
                    tSecond = samSecond.dimensions{getVar(samSecond.dimensions, 'TIME')}.data;
                    tCur = curSam.dimensions{getVar(curSam.dimensions, 'TIME')}.data;
                    clear samFirst samSecond;
                    
                    % let's interpolate data so we have consistent period
                    % sample and time sample over the 3 data sets
                    zFirst = interp1(tFirst, zFirst, tCur);
                    zSecond = interp1(tSecond, zSecond, tCur);
                    clear tFirst tSecond tCur;
                    
                    computedDepth = (distFirstCurSensor/distFirstSecond) ...
                        * (zSecond - zFirst) + zFirst;
                    clear zFirst zSecond;
                end
            end
        else
            fprintf('%s\n', ['Warning : ' curSam.toolbox_input_file ...
                ' please document either instrument_nominal_height or instrument_nominal_depth '...
                'global attributes so that an actual depth can be '...
                'computed from other pressure sensors in the mooring']);
            continue;
        end
        
        % variable Depth will be a function of T, Y, and X
        timeIdx = getVar(curSam.dimensions, 'TIME');
        latitudeIdx = getVar(curSam.dimensions, 'LATITUDE');
        longitudeIdx = getVar(curSam.dimensions, 'LONGITUDE');
        dimensions = [timeIdx latitudeIdx longitudeIdx];
    else
        if presRelIdx == 0
            % update from a relative pressure like SeaBird computes
            % it in its processed files, substracting a constant value
            % 10.1325 dbar for nominal atmospheric pressure
            relPres = curSam.variables{presIdx}.data - gsw_P0/10^4;
            presComment = ['absolute '...
                'pressure measurements to which a nominal '...
                'value for atmospheric pressure (10.1325 dbar) '...
                'has been substracted'];
        else
            % update from a relative measured pressure
            relPres = curSam.variables{presRelIdx}.data;
            presComment = ['relative '...
                'pressure measurements (calibration offset '...
                'usually performed to balance current '...
                'atmospheric pressure and acute sensor '...
                'precision at a deployed depth)'];
        end
        
        if ~isempty(curSam.geospatial_lat_min) && ~isempty(curSam.geospatial_lat_max)
            % compute vertical min/max with Gibbs-SeaWater toolbox
            if curSam.geospatial_lat_min == curSam.geospatial_lat_max
                computedDepth         = - gsw_z_from_p(relPres, ...
                    curSam.geospatial_lat_min);
                clear relPres;
                computedDepthComment  = ['depthPP: Depth computed using the '...
                    'Gibbs-SeaWater toolbox (TEOS-10) v3.02 from latitude and '...
                    presComment '.'];
            else
                meanLat = curSam.geospatial_lat_min + ...
                    (curSam.geospatial_lat_max - curSam.geospatial_lat_min)/2;
                
                computedDepth         = - gsw_z_from_p(relPres, meanLat);
                clear relPres;
                computedDepthComment  = ['depthPP: Depth computed using the '...
                    'Gibbs-SeaWater toolbox (TEOS-10) v3.02 from mean latitude and '...
                    presComment '.'];
            end
        else
            % without latitude information, we assume 1dbar ~= 1m
            computedDepth         = relPres;
            clear relPres;
            computedDepthComment  = ['depthPP: Depth computed from '...
                presComment ', assuming 1dbar ~= 1m.'];
        end
        
        if presRelIdx == 0
            dimensions = curSam.variables{presIdx}.dimensions;
        else
            dimensions = curSam.variables{presRelIdx}.dimensions;
        end
    end
    
% This is a test not to add computed depth from bad pressure data in ADCPs    
%     computedMedianDepth   = round(median(computedDepth)*100)/100;
%     
%     idHeight = getVar(curSam.dimensions, 'HEIGHT_ABOVE_SENSOR');
%     if idHeight > 0
%         % ADCP
%         % Let's compare this computed depth from pressure
%         % with the maximum distance the ADCP can measure. Sometimes,
%         % PRES from ADCP pressure sensor is just wrong
%         maxDistance = round(max(curSam.dimensions{idHeight}.data)*100)/100;
%         diffPresDist = abs(maxDistance - computedMedianDepth)/max(maxDistance, computedMedianDepth);
%         
%         if diffPresDist < 30/100
%             % Depth from PRES Ok if diff < 30%
%             % add depth data as new variable in data set
%             sample_data{k} = addVar(...
%                 curSam, ...
%                 'DEPTH', ...
%                 computedDepth, ...
%                 dimensions, ...
%                 computedDepthComment);
%             clear computedDepth;
%         else
%             fprintf('%s\n', ['Warning : ' curSam.toolbox_input_file ' computed '...
%                 'depth won''t be added to dataset as it is too far from the '...
%                 'instrument nominal depth value']);
%         end
%     else
%         % add depth data as new variable in data set
%         sample_data{k} = addVar(...
%             curSam, ...
%             'DEPTH', ...
%             computedDepth, ...
%             dimensions, ...
%             computedDepthComment);
%         clear computedDepth;
%         
%         % update vertical min/max from new computed DEPTH
%         sample_data{k} = populateMetadata(sample_data{k});
%     end

    % add depth data as new variable in data set
    sample_data{k} = addVar(...
        curSam, ...
        'DEPTH', ...
        computedDepth, ...
        dimensions, ...
        computedDepthComment);
    clear computedDepth;
    
    history = sample_data{k}.history;
    if isempty(history)
        sample_data{k}.history = sprintf('%s - %s', datestr(now_utc, readProperty('exportNetCDF.dateFormat')), computedDepthComment);
    else
        sample_data{k}.history = sprintf('%s\n%s - %s', history, datestr(now_utc, readProperty('exportNetCDF.dateFormat')), computedDepthComment);
    end
    
    % update the keywords with variable DEPTH
    sample_data{k}.keywords = [sample_data{k}.keywords, ', DEPTH'];
    
    % get the toolbox execution mode. Values can be 'timeSeries' and 'profile'.
    % If no value is set then default mode is 'timeSeries'
    mode = lower(readProperty('toolbox.mode'));
    
    switch mode
        case 'profile'
            %let's redefine the coordinates for each variables
            nVars = length(sample_data{k}.variables);
            for i=1:nVars
                if all(~strcmpi({'TIME', 'DEPTH', 'LATITUDE', 'LONGITUDE', 'DIRECTION'}, sample_data{k}.variables{i}.name))
                  sample_data{k}.variables{i}.coordinates = 'TIME DEPTH LATITUDE LONGITUDE';
                end
            end
            
        otherwise
            
    end
    
    % update vertical min/max from new computed DEPTH
    sample_data{k} = populateMetadata(sample_data{k});
    clear curSam;
end
