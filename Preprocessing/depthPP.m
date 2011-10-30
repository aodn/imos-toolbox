function sample_data = depthPP( sample_data, auto )
%DEPTHPP Adds a depth variable to the given data sets, if they contain a
% pressure variable.
%
% This function uses the CSIRO Matlab Seawater Library to derive depth data
% from pressure. It adds the depth data as a new variable in the data sets.
% Data sets which do not contain a pressure variable are left unmodified.
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

% check wether height or target depth information is documented
isSensorHeight = false;
isSensorTargetDepth = false;

if isfield(sample_data{1}, 'sensor_height')
    if ~isempty(sample_data{1}.sensor_height)
        isSensorHeight = true;
    end
else
    
end

if isfield(sample_data{1}, 'target_depth')
    if ~isempty(sample_data{1}.target_depth)
        isSensorTargetDepth = true;
    end
else
    
end

for k = 1:length(sample_data)
    
    sam = sample_data{k};
    
    % if data set already contains depth data then next sample data
    if getVar(sam.variables, 'DEPTH'), continue; end
    if getVar(sam.dimensions, 'DEPTH'), continue; end
    
    presIdx     = getVar(sam.variables, 'PRES');
    presRelIdx  = getVar(sam.variables, 'PRES_REL');
    
    % if no pressure data, try to compute it from other sensors in the
    % mooring, otherwise go to next sample data
    if presIdx == 0 && presRelIdx == 0
        if isSensorHeight || isSensorTargetDepth
            % let's see if part of a mooring with pressure data from other
            % sensors
            m = 0;
            otherSam = [];
            for l = 1:length(sample_data)
                curSam = sample_data{l};
                
                if isSensorHeight
                    curSensorZ = curSam.sensor_height;
                else
                    curSensorZ = curSam.target_depth;
                end
                
                if l == k || isempty(curSensorZ), continue; end
                curSource = textscan(curSam.instrument, '%s');
                curSource = curSource{1};
                presCurIdx      = getVar(curSam.variables, 'PRES');
                presRelCurIdx   = getVar(curSam.variables, 'PRES_REL');
                
                p=0;
                for n = 1:length(curSource)
                    if ~isempty(strfind(sam.instrument, curSource{n}))
                        p = p+1;
                    end
                end
                
                if (presCurIdx > 0 || presRelCurIdx > 0) && p > 1
                    m = m+1;
                    otherSam{m} = curSam;
                end
            end
            
            % re-compute a pressure from nearest pressure sensors
            if m > 1
                % find the 2 nearest pressure data
                diffWithOthers = nan(m,1);
                for l = 1:m
                    if isSensorHeight
                    	diffWithOthers(l) = abs(sam.sensor_height - otherSam{l}.sensor_height);
                    else
                        diffWithOthers(l) = abs(sam.target_depth - otherSam{l}.target_depth);
                    end
                end
                
                iFirst              = diffWithOthers == min(diffWithOthers);
                samFirst            = otherSam{iFirst};
                presIdxFirst        = getVar(samFirst.variables, 'PRES');
                presRelIdxFirst     = getVar(samFirst.variables, 'PRES_REL');
                
                iSecond             = diffWithOthers == min(diffWithOthers(~iFirst));
                samSecond           = otherSam{iSecond};
                presIdxSecond       = getVar(samSecond.variables, 'PRES');
                presRelIdxSecond    = getVar(samSecond.variables, 'PRES_REL');
                
                if presRelIdxFirst == 0 || presRelIdxSecond == 0
                    % update from a relative pressure like SeaBird computes
                    % it in its processed files, substracting a constant value
                    % 10.1325 dbar for nominal atmospheric pressure
                    relPresFirst    = samFirst.variables{presIdxFirst}.data - 10.1325;
                    relPresSecond   = samSecond.variables{presIdxSecond}.data - 10.1325;
                    presComment     = ['absolute '...
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
                    distFirstSecond     = samFirst.sensor_height - samSecond.sensor_height;
                    distFirstCurSensor  = samFirst.sensor_height - sam.sensor_height;
                else
                    distFirstSecond     = samFirst.target_depth - samSecond.target_depth;
                    distFirstCurSensor  = samFirst.target_depth - sam.target_depth;
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
                if ~isempty(sam.geospatial_lat_min) && ~isempty(sam.geospatial_lat_max)
                    % compute depth with SeaWater toolbox
                    % depth ~= sw_dpth(pressure, latitude)
                    if sam.geospatial_lat_min == sam.geospatial_lat_max
                        zFirst = sw_dpth(relPresFirst, sam.geospatial_lat_min);
                        zSecond = sw_dpth(relPresSecond, sam.geospatial_lat_min);
                        
                        computedDepthComment  = ['depthPP: Depth computed from '...
                            'the 2 nearest pressure sensors available, using the '...
                            'SeaWater toolbox from latitude and '...
                            presComment '.'];
                    else
                        meanLat = sam.geospatial_lat_min + ...
                            (sam.geospatial_lat_max - sam.geospatial_lat_min)/2;
                        
                        zFirst = sw_dpth(relPresFirst, meanLat);
                        zSecond = sw_dpth(relPresSecond, meanLat);    
                        
                        computedDepthComment  = ['depthPP: Depth computed from '...
                            'the 2 nearest pressure sensors available, using the '...
                            'SeaWater toolbox from mean latitude and '...
                            presComment '.'];
                    end
                else
                    % without latitude information, we assume 1dbar ~= 1m
                    zFirst = relPresFirst;
                    zSecond = relPresSecond;
                    
                    computedDepthComment  = ['depthPP: Depth computed from '...
                        'the 2 nearest pressure sensors available with '...
                        presComment ', assuming 1dbar ~= 1m.'];
                end
                
                tFirst = samFirst.dimensions{getVar(samFirst.dimensions, 'TIME')}.data;
                tSecond = samSecond.dimensions{getVar(samSecond.dimensions, 'TIME')}.data;
                
                % let's find which data are overlapping in time
                [~, iOverlapFirst, iOverlapSecond] = intersect(tFirst, tSecond);
                zFirst = zFirst(iOverlapFirst);
                tFirst = tFirst(iOverlapFirst);
                zSecond = zSecond(iOverlapSecond);
                tSecond = tSecond(iOverlapSecond);
                
                tCur = sam.dimensions{getVar(sam.dimensions, 'TIME')}.data;
                computedDepth = nan(size(tCur));
                
                [~, iOverlapCur, iOverlapOthers] = intersect(tCur, tFirst);
                
                computedDepth(iOverlapCur) = (distFirstCurSensor/distFirstSecond) ...
                    * (zSecond(iOverlapOthers) - zFirst(iOverlapOthers)) + zFirst(iOverlapOthers);
            
            elseif m == 1
                warning('Computing actual depth from only one pressure sensor on mooring');
                % we found only one sensor
                otherSam = otherSam{1};
                presIdxOther = getVar(otherSam.variables, 'PRES');
                presRelIdxOther = getVar(otherSam.variables, 'PRES_REL');
                
                if presRelIdxOther == 0
                    % update from a relative pressure like SeaBird computes
                    % it in its processed files, substracting a constant value
                    % 10.1325 dbar for nominal atmospheric pressure
                    relPresOther = otherSam.variables{presIdxOther}.data - 10.1325;
                    presComment = ['absolute '...
                        'pressure measurements to which a nominal '...
                        'value for atmospheric pressure (10.1325 dbar) '...
                        'has been substracted'];
                else
                    % update from a relative measured pressure
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
                % computedDepth = zOther - distOtherCurSensor
                %
                if isSensorHeight
                    distOtherCurSensor = otherSam.sensor_height - sam.sensor_height;
                else
                    distOtherCurSensor = otherSam.target_depth - sam.target_depth;
                end
                
                if ~isempty(sam.geospatial_lat_min) && ~isempty(sam.geospatial_lat_max)
                    % compute depth with SeaWater toolbox
                    % depth ~= sw_dpth(pressure, latitude)
                    if sam.geospatial_lat_min == sam.geospatial_lat_max
                        zOther = sw_dpth(relPresOther, sam.geospatial_lat_min);
                        
                        computedDepthComment  = ['depthPP: Depth computed from '...
                            'the only pressure sensor available, using the '...
                            'SeaWater toolbox from latitude and '...
                            presComment '.'];
                    else
                        meanLat = sam.geospatial_lat_min + ...
                            (sam.geospatial_lat_max - sam.geospatial_lat_min)/2;
                        zOther = sw_dpth(relPresOther, meanLat);
                        
                        computedDepthComment  = ['depthPP: Depth computed from '...
                            'the only pressure sensor available, using the '...
                            'SeaWater toolbox from mean latitude and '...
                            presComment '.'];
                    end
                else
                    % without latitude information, we assume 1dbar ~= 1m
                    zOther = relPresOther;
                    
                    computedDepthComment  = ['depthPP: Depth computed from '...
                        'the only pressure sensor available with '...
                        presComment ', assuming 1dbar ~= 1m.'];
                end
                
                tOther = otherSam.dimensions{getVar(otherSam.dimensions, 'TIME')}.data;
                
                tCur = sam.dimensions{getVar(sam.dimensions, 'TIME')}.data;
                computedDepth = nan(size(tCur));
                
                % let's find which data are overlapping in time
                [~, iOverlapCur, iOverlapOther] = intersect(tCur, tOther);
                
                computedDepth(iOverlapCur) = zOther(iOverlapOther) + distOtherCurSensor;
            else
                warning(['There is no pressure sensor on this mooring from '...
                    'which an actual depth can be computed']);
                continue;
            end
        else
            warning(['Please document either sensor_height or target_depth '...
                'global attributes so that an actual depth can be '...
                'computed from other pressure sensors in the mooring']);
            continue;
        end
        
        % looking for dimensions to give to variable Depth
        idx = getVar(sam.variables, 'TEMP');
        dimensions = sam.variables{idx}.dimensions;
    else
        if presRelIdx == 0
            % update from a relative pressure like SeaBird computes
            % it in its processed files, substracting a constant value
            % 10.1325 dbar for nominal atmospheric pressure
            relPres = sam.variables{presIdx}.data - 10.1325;
            presComment = ['absolute '...
                'pressure measurements to which a nominal '...
                'value for atmospheric pressure (10.1325 dbar) '...
                'has been substracted'];
        else
            % update from a relative measured pressure
            relPres = sam.variables{presRelIdx}.data;
            presComment = ['relative '...
                'pressure measurements (calibration offset '...
                'usually performed to balance current '...
                'atmospheric pressure and acute sensor '...
                'precision at a deployed depth)'];
        end
        
        if ~isempty(sam.geospatial_lat_min) && ~isempty(sam.geospatial_lat_max)
            % compute vertical min/max with SeaWater toolbox
            if sam.geospatial_lat_min == sam.geospatial_lat_max
                computedDepth         = sw_dpth(relPres, ...
                    sam.geospatial_lat_min);
                computedDepthComment  = ['depthPP: Depth computed using the '...
                    'SeaWater toolbox from latitude and '...
                    presComment '.'];
            else
                meanLat = sam.geospatial_lat_min + ...
                    (sam.geospatial_lat_max - sam.geospatial_lat_min)/2;
                
                computedDepth         = sw_dpth(relPres, meanLat);
                computedDepthComment  = ['depthPP: Depth computed using the '...
                    'SeaWater toolbox from mean latitude and '...
                    presComment '.'];
            end
        else
            % without latitude information, we assume 1dbar ~= 1m
            computedDepth         = relPres;
            computedDepthComment  = ['depthPP: Depth computed from '...
                presComment ', assuming 1dbar ~= 1m.'];
        end
        
        if presRelIdx == 0
            dimensions = sam.variables{presIdx}.dimensions;
        else
            dimensions = sam.variables{presRelIdx}.dimensions;
        end
    end
    
    computedMedianDepth   = round(median(computedDepth)*100)/100;
    
    idHeight = getVar(sam.dimensions, 'HEIGHT_ABOVE_SENSOR');
    if idHeight > 0
        % ADCP
        % Let's compare this computed depth from pressure
        % with the maximum distance the ADCP can measure. Sometimes,
        % PRES from ADCP pressure sensor is just wrong
        maxDistance = round(max(sam.dimensions{idHeight}.data)*100)/100;
        diffPresDist = abs(maxDistance - computedMedianDepth)/max(maxDistance, computedMedianDepth);
        
        if diffPresDist < 30/100
            % Depth from PRES Ok if diff < 30%
            % add depth data as new variable in data set
            sample_data{k} = addVar(...
                sam, ...
                'DEPTH', ...
                computedDepth, ...
                dimensions, ...
                computedDepthComment);
        end
    else
        % add depth data as new variable in data set
        sample_data{k} = addVar(...
            sam, ...
            'DEPTH', ...
            computedDepth, ...
            dimensions, ...
            computedDepthComment);
        
        % update vertical min/max from new computed DEPTH
        sample_data{k} = populateMetadata(sample_data{k});
    end
end