function sample_data = depthPP( sample_data, auto )
%DEPTHPP Adds a depth variable to the given data sets, if they contain a
% pressure variable.
%
% This function uses the CSIRO Matlab Seawater Library to derive depth data
% from pressure. It adds the depth data as a new variable in the data sets.
% Data sets which do not contain a pressure variable are left unmodified.
%
% This function uses a latitude of -30.0 degrees. A future easy enhancement
% would be to prompt the user to enter a latitude, but different latitude
% values don't make much of a difference to the result (a variation of around
% 6 metres for depths of ~ 1000 metres).
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

for k = 1:length(sample_data)
    
    sam = sample_data{k};
    
    % if data set already contains depth data then next sample data
    if getVar(sam.variables, 'DEPTH'), continue; end
    if getVar(sam.dimensions, 'DEPTH'), continue; end
    
    presIdx = getVar(sam.variables, 'PRES');
    
    % if no pressure data, try to compute it from other sensors in the
    % mooring, otherwise go to next sample data
    if ~presIdx
        if ~isempty(sam.sensor_height)
            % let's see if part of a mooring with pressure data from other
            % sensors
            m = 0;
            otherSam = [];
            for l = 1:length(sample_data)
                curSam = sample_data{l};
                if l == k || isempty(curSam.sensor_height), continue; end
                curSource = textscan(curSam.source, '%s');
                curSource = curSource{1};
                presCurIdx = getVar(curSam.variables, 'PRES');
                
                p=0;
                for n = 1:length(curSource)
                    if ~isempty(strfind(sam.source, curSource{n}))
                        p = p+1;
                    end
                end
                
                if presCurIdx > 0 && p > 1
                    m = m+1;
                    otherSam{m} = curSam;
                end
            end
            
            % re-compute a pressure from nearest pressure sensors
            if m > 0
                % find the 2 nearest pressure data
                diff = nan(m,1);
                for l = 1:m
                    diff(l) = sam.sensor_height - otherSam{l}.sensor_height;
                end
                iAllSamAbove = diff < 0;
                iAllSamBelow = diff > 0;
                
                if any(iAllSamAbove) && any(iAllSamBelow)
                    % we found 2 sensors, one above and another below
                    diffAbove = min(diff(iAllSamAbove));
                    samAbove = otherSam{diff == diffAbove};
                    presIdxAbove = getVar(samAbove.variables, 'PRES');
                    
                    diffBelow = min(diff(iAllSamBelow));
                    samBelow = otherSam{diff == diffBelow};
                    presIdxBelow = getVar(samBelow.variables, 'PRES');
                    
                    % update from a relative pressure like SeaBird computes
                    % it in its processed files, substracting a constant value
                    % 14.7*0.689476 dBar for nominal atmospheric pressure
                    relPresAbove = samAbove.variables{presIdxAbove}.data - 14.7*0.689476;
                    relPresBelow = samBelow.variables{presIdxBelow}.data - 14.7*0.689476;
                    
                    % compute pressure at current sensor using trigonometry and
                    % assuming sensors repartition on a line between the two
                    % nearest pressure sensors
                    distAboveBelow = samAbove.sensor_height - samBelow.sensor_height;
                    distAboveCurSensor = samAbove.sensor_height - sam.sensor_height;
                    
                    % theta is the angle between the vertical and line
                    % formed by the sensors
                    %
                    % cos(theta) = depthAboveBelow/distAboveBelow
                    % and
                    % cos(theta) = depthAboveCurSensor/distAboveCurSensor
                    %
                    % computedDepth = (distAboveCurSensor/distAboveBelow) ...
                    %        * (zBelow - zAbove) + zAbove
                    %
                    % pressure = density*gravity*depth
                    %
                    if ~isempty(sam.geospatial_lat_min) && ~isempty(sam.geospatial_lat_max)
                        % compute depth with SeaWater toolbox
                        % depth ~= sw_dpth(pressure, latitude)
                        if sam.geospatial_lat_min == sam.geospatial_lat_max
                            zAbove = sw_dpth(relPresAbove, sam.geospatial_lat_min);
                            tAbove = samAbove.dimensions{getVar(samAbove.dimensions, 'TIME')}.data;
                            
                            zBelow = sw_dpth(relPresBelow, sam.geospatial_lat_min);
                            tBelow = samBelow.dimensions{getVar(samBelow.dimensions, 'TIME')}.data;
                            
                            % let's find which data are overlapping in time
                            [~, iOverlapAbove, iOverlapBelow] = intersect(tAbove, tBelow);
                            zAbove = zAbove(iOverlapAbove);
                            tAbove = tAbove(iOverlapAbove);
                            zBelow = zBelow(iOverlapBelow);
                            tBelow = tBelow(iOverlapBelow);
                            
                            tCur = sam.dimensions{getVar(sam.dimensions, 'TIME')}.data;
                            computedDepth = nan(size(tCur));
                            
                            [~, iOverlapCur, iOverlapOthers] = intersect(tCur, tAbove);
                            
                            computedDepth(iOverlapCur) = (distAboveCurSensor/distAboveBelow) ...
                                * (zBelow(iOverlapOthers) - zAbove(iOverlapOthers)) + zAbove(iOverlapOthers);
                            computedDepthComment  = ['depthPP: Depth computed from '...
                                'nearest pressure sensors available, using the '...
                                'SeaWater toolbox from latitude and absolute '...
                                'pressure measurements to which a nominal '...
                                'value for atmospheric pressure (14.7*0689476 dBar) '...
                                'has been substracted.'];
                        else
                            meanLat = sam.geospatial_lat_min + ...
                                (sam.geospatial_lat_max - sam.geospatial_lat_min)/2;
                            
                            zAbove = sw_dpth(relPresAbove, meanLat);
                            tAbove = samAbove.dimensions{getVar(samAbove.dimensions, 'TIME')}.data;
                            
                            zBelow = sw_dpth(relPresBelow, meanLat);
                            tBelow = samBelow.dimensions{getVar(samBelow.dimensions, 'TIME')}.data;
                            
                            % let's find which data are overlapping in time
                            [~, iOverlapAbove, iOverlapBelow] = intersect(tAbove, tBelow);
                            zAbove = zAbove(iOverlapAbove);
                            tAbove = tAbove(iOverlapAbove);
                            zBelow = zBelow(iOverlapBelow);
                            tBelow = tBelow(iOverlapBelow);
                            
                            tCur = sam.dimensions{getVar(sam.dimensions, 'TIME')}.data;
                            computedDepth = nan(size(tCur));
                            
                            [~, iOverlapCur, iOverlapOthers] = intersect(tCur, tAbove);
                            
                            computedDepth(iOverlapCur) = (distAboveCurSensor/distAboveBelow) ...
                                * (zBelow(iOverlapOthers) - zAbove(iOverlapOthers)) + zAbove(iOverlapOthers);
                            computedDepthComment  = ['depthPP: Depth computed from '...
                                'nearest pressure sensors available, using the '...
                                'SeaWater toolbox from mean latitude and absolute '...
                                'pressure measurements to which a nominal '...
                                'value for atmospheric pressure (14.7*0689476 dBar) '...
                                'has been substracted.'];
                        end
                    else
                        % without latitude information, we assume 1dBar ~= 1m
                        tAbove = samAbove.dimensions{getVar(samAbove.dimensions, 'TIME')}.data;
                        tBelow = samBelow.dimensions{getVar(samBelow.dimensions, 'TIME')}.data;
                        
                        % let's find which data are overlapping in time
                        [~, iOverlapAbove, iOverlapBelow] = intersect(tAbove, tBelow);
                        relPresAbove = relPresAbove(iOverlapAbove);
                        tAbove = tAbove(iOverlapAbove);
                        relPresBelow = relPresBelow(iOverlapBelow);
                        tBelow = tBelow(iOverlapBelow);
                        
                        tCur = sam.dimensions{getVar(sam.dimensions, 'TIME')}.data;
                        computedDepth = nan(size(tCur));
                        
                        [~, iOverlapCur, iOverlapOthers] = intersect(tCur, tAbove);
                        
                        computedDepth(iOverlapCur) = (distAboveCurSensor/distAboveBelow) ...
                            * (relPresBelow(iOverlapOthers) - relPresAbove(iOverlapOthers)) + relPresAbove(iOverlapOthers);
                        computedDepthComment  = ['depthPP: Depth computed from '...
                            'nearest pressure sensors available with absolute '...
                            'pressure measurements to which a nominal '...
                            'value for atmospheric pressure (14.7*0689476 dBar) '...
                            'has been substracted, assuming 1dBar ~= 1m.'];
                    end
                    
                elseif (any(iAllSamAbove) && ~any(iAllSamBelow)) || (~any(iAllSamAbove) && any(iAllSamBelow))
                    % we found only one sensor above/below
                    if any(iAllSamAbove)
                        diff = min(diff(iAllSamAbove));
                    else
                        diff = min(diff(iAllSamBelow));
                    end
                    otherSam = otherSam{diff == diff};
                    presIdxOther = getVar(otherSam.variables, 'PRES');
                    
                    % update from a relative pressure like SeaBird computes
                    % it in its processed files, substracting a constant value
                    % 14.7*0.689476 dBar for nominal atmospheric pressure
                    relPresOther = otherSam.variables{presIdxOther}.data - 14.7*0.689476;
                    
                    % compute pressure at current sensor assuming sensors 
                    % repartition on a vertical line between current sensor
                    % and the nearest
                    %
                    % computedDepth = zOther - distOtherCurSensor
                    %
                    distOtherCurSensor = otherSam.sensor_height - sam.sensor_height;
                    
                    if ~isempty(sam.geospatial_lat_min) && ~isempty(sam.geospatial_lat_max)
                        % compute depth with SeaWater toolbox
                        % depth ~= sw_dpth(pressure, latitude)
                        if sam.geospatial_lat_min == sam.geospatial_lat_max
                            % let's find which data are overlapping in time
                            zOther = sw_dpth(relPresOther, sam.geospatial_lat_min);
                            tOther = otherSam.dimensions{getVar(otherSam.dimensions, 'TIME')}.data;
                            
                            tCur = sam.dimensions{getVar(sam.dimensions, 'TIME')}.data;
                            computedDepth = nan(size(tCur));
                            
                            [~, iOverlapCur, iOverlapOther] = intersect(tCur, tOther);
                            
                            computedDepth(iOverlapCur) = zOther(iOverlapOther) + distOtherCurSensor;
                            computedDepthComment  = ['depthPP: Depth computed from '...
                                'the nearest pressure sensor available, using the '...
                                'SeaWater toolbox from latitude and absolute '...
                                'pressure measurements to which a nominal '...
                                'value for atmospheric pressure (14.7*0689476 dBar) '...
                                'has been substracted.'];
                        else
                            meanLat = sam.geospatial_lat_min + ...
                                (sam.geospatial_lat_max - sam.geospatial_lat_min)/2;
                            
                            % let's find which data are overlapping in time
                            zOther = sw_dpth(relPresOther, meanLat);
                            tOther = otherSam.dimensions{getVar(otherSam.dimensions, 'TIME')}.data;
                            
                            tCur = sam.dimensions{getVar(sam.dimensions, 'TIME')}.data;
                            computedDepth = nan(size(tCur));
                            
                            [~, iOverlapCur, iOverlapOther] = intersect(tCur, tOther);
                            
                            computedDepth(iOverlapCur) = zOther(iOverlapOther) - distOtherCurSensor;
                            computedDepthComment  = ['depthPP: Depth computed from '...
                                'the nearest pressure sensor available, using the '...
                                'SeaWater toolbox from mean latitude and absolute '...
                                'pressure measurements to which a nominal '...
                                'value for atmospheric pressure (14.7*0689476 dBar) '...
                                'has been substracted.'];
                        end
                    else
                        % without latitude information, we assume 1dBar ~= 1m
                        tOther = otherSam.dimensions{getVar(otherSam.dimensions, 'TIME')}.data;
                        
                        tCur = sam.dimensions{getVar(sam.dimensions, 'TIME')}.data;
                        computedDepth = nan(size(tCur));
                        
                        [~, iOverlapCur, iOverlapOther] = intersect(tCur, tOther);
                        
                        computedDepth(iOverlapCur) = relPresOther(iOverlapOther) - distOtherCurSensor;
                        computedDepthComment  = ['depthPP: Depth computed from '...
                            'the nearest pressure sensor available with absolute '...
                            'pressure measurements to which a nominal '...
                            'value for atmospheric pressure (14.7*0689476 dBar) '...
                            'has been substracted, assuming 1dBar ~= 1m.'];
                    end
                end
            else
                continue;
            end
        else
            continue;
        end
        
        % looking for dimensions to give to variable Depth
        idx = getVar(sam.variables, 'TEMP');
        dimensions = sam.variables{idx}.dimensions;
    else
        % update from a relative pressure like SeaBird computes
        % it in its processed files, substracting a constant value
        % 14.7*0.689476 dBar for nominal atmospheric pressure
        relPres = sam.variables{presIdx}.data - 14.7*0.689476;
        
        if ~isempty(sam.geospatial_lat_min) && ~isempty(sam.geospatial_lat_max)
            % compute vertical min/max with SeaWater toolbox
            if sam.geospatial_lat_min == sam.geospatial_lat_max
                computedDepth         = sw_dpth(relPres, ...
                    sam.geospatial_lat_min);
                computedDepthComment  = ['depthPP: Depth computed using the '...
                    'SeaWater toolbox from latitude and absolute '...
                    'pressure measurements to which a nominal '...
                    'value for atmospheric pressure (14.7*0689476 dBar) '...
                    'has been substracted.'];
            else
                meanLat = sam.geospatial_lat_min + ...
                    (sam.geospatial_lat_max - sam.geospatial_lat_min)/2;
                
                computedDepth         = sw_dpth(relPres, meanLat);
                computedDepthComment  = ['depthPP: Depth computed using the '...
                    'SeaWater toolbox from mean latitude and absolute '...
                    'pressure measurements to which a nominal '...
                    'value for atmospheric pressure (14.7*0689476 dBar) '...
                    'has been substracted.'];
            end
        else
            % without latitude information, we assume 1dBar ~= 1m
            computedDepth         = relPres;
            computedDepthComment  = ['depthPP: Depth computed from absolute '...
                'pressure measurements to which a nominal '...
                'value for atmospheric pressure (14.7*0689476 dBar) '...
                'has been substracted, assuming 1dBar ~= 1m.'];
        end
        
        dimensions = sam.variables{presIdx}.dimensions;
    end
    
    computedDepth         = round(computedDepth*100)/100;
    computedMedianDepth   = round(median(computedDepth)*100)/100;
    
    idHeight = getVar(sam.dimensions, 'HEIGHT_ABOVE_SENSOR');
    if idHeight > 0
        % ADCP
        % Let's compare this computed depth from pressure
        % with the maximum distance the ADCP can measure. Sometimes,
        % PRES from ADCP pressure sensor is just wrong
        maxDistance = round(max(sam.dimensions{idHeight}.data)*100)/100;
        diff = abs(maxDistance - computedMedianDepth)/max(maxDistance, computedMedianDepth);
        
        if diff < 10/100
            % Depth from PRES Ok if diff < 10%
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
end