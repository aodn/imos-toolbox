function sample_data = adcpBinMappingPP( sample_data, qcLevel, auto )
%ADCPBINMAPPINGPP bin-maps any RDI or Nortek adcp variable expressed in beams coordinates 
%and which is function of DIST_ALONG_BEAMS into a HEIGHT_ABOVE_SENSOR dimension
%if the velocity data found in this dataset is already a function of 
%HEIGHT_ABOVE_SENSOR.
%
% For every beam, each bin has its vertical height above sensor inferred from 
% the tilt information. Data values are then interpolated at the nominal 
% vertical bin heights (when tilt is 0).
%
% Inputs:
%   sample_data - cell array of data sets, ideally with DIST_ALONG_BEAMS dimension.
%   qcLevel     - string, 'raw' or 'qc'. Some pp not applied when 'raw'.
%   auto        - logical, run pre-processing in batch mode.
%
% Outputs:
%   sample_data - the same data sets, with relevant processed variable originally function 
%                 of DIST_ALONG_BEAMS now function of HEIGHT_ABOVE_SENSOR.
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
narginchk(2, 3);

if ~iscell(sample_data), error('sample_data must be a cell array'); end
if isempty(sample_data), return;                                    end

% auto logical in input to enable running under batch processing
if nargin<3, auto=false; end

% no modification of data is performed on the raw FV00 dataset except
% local time to UTC conversion
if strcmpi(qcLevel, 'raw'), return; end

for k = 1:length(sample_data)
    % do not process if not RDI nor Nortek
    isRDI = false;
    isNortek = false;
    if strcmpi(sample_data{k}.meta.instrument_make, 'Teledyne RDI'), isRDI = true; end
    if strcmpi(sample_data{k}.meta.instrument_make, 'Nortek'), isNortek = true; end
    if ~isRDI && ~isNortek, continue; end
    
    % do not process if Nortek with more than 3 beams
    absic4Idx = getVar(sample_data{k}.variables, 'ABSIC4');
    if absic4Idx && isNortek, continue; end
    
    heightAboveSensorIdx = getVar(sample_data{k}.dimensions, 'HEIGHT_ABOVE_SENSOR');
    distAlongBeamsIdx = getVar(sample_data{k}.dimensions, 'DIST_ALONG_BEAMS');
    pitchIdx = getVar(sample_data{k}.variables, 'PITCH');
    rollIdx  = getVar(sample_data{k}.variables, 'ROLL');
  
    % do not process if pitch, roll, and dist_along_beams not present in data set
    if ~(distAlongBeamsIdx && pitchIdx && rollIdx), continue; end
  
    % do not process if velocity data not vertically bin-mapped and there 
    % is no velocity data in beam coordinates (useless)
    ucurIdx  = getVar(sample_data{k}.variables, 'UCUR');
    if ~ucurIdx, ucurIdx  = getVar(sample_data{k}.variables, 'UCUR_MAG'); end
    vel1Idx  = getVar(sample_data{k}.variables, 'VEL1');
    if any(sample_data{k}.variables{ucurIdx}.dimensions == distAlongBeamsIdx) && ~vel1Idx, continue; end
    
    % We apply tilt corrections to project DIST_ALONG_BEAMS onto the vertical
    % axis HEIGHT_ABOVE_SENSOR.
    %
    % RDI 4 beams ADCPs:
    % It is assumed that the beams are in a convex configuration such as beam 1
    % and 2 (respectively 3 and 4) are aligned on the pitch (respectively roll)
    % axis. When pitch is positive beam 3 is closer to the surface while beam 4
    % gets further away. When roll is positive beam 2 is closer to the surface
    % while beam 1 gets further away.
    %
    % Nortek 3 beams ADCPs:
    % It is assumed that the beams are in a convex configuration such as beam 1
    % and the centre of the ADCP are aligned on the roll axis. Beams 2 and 3
    % are symetrical against the roll axis. Each beam is 120deg apart from
    % each other. When pitch is positive beam 1 is closer to the surface
    % while beams 2 and 3 get further away. When roll is positive beam 3 is
    % closer to the surface while beam 2 gets further away.
    %
    distAlongBeams = sample_data{k}.dimensions{distAlongBeamsIdx}.data;
    pitch = sample_data{k}.variables{pitchIdx}.data*pi/180;
    roll  = sample_data{k}.variables{rollIdx}.data*pi/180;
    
    beamAngle = sample_data{k}.meta.beam_angle*pi/180;
    nBins = length(distAlongBeams);
    
    if isRDI
        % RDI 4 beams
        nonMappedHeightAboveSensorBeam1 = (cos(beamAngle + roll)/cos(beamAngle)) * distAlongBeams';
        nonMappedHeightAboveSensorBeam1 = repmat(cos(pitch), 1, nBins) .* nonMappedHeightAboveSensorBeam1;
        
        nonMappedHeightAboveSensorBeam2 = (cos(beamAngle - roll)/cos(beamAngle)) * distAlongBeams';
        nonMappedHeightAboveSensorBeam2 = repmat(cos(pitch), 1, nBins) .* nonMappedHeightAboveSensorBeam2;
        
        nonMappedHeightAboveSensorBeam3 = (cos(beamAngle - pitch)/cos(beamAngle)) * distAlongBeams';
        nonMappedHeightAboveSensorBeam3 = repmat(cos(roll), 1, nBins) .* nonMappedHeightAboveSensorBeam3;
        
        nonMappedHeightAboveSensorBeam4 = (cos(beamAngle + pitch)/cos(beamAngle)) * distAlongBeams';
        nonMappedHeightAboveSensorBeam4 = repmat(cos(roll), 1, nBins) .* nonMappedHeightAboveSensorBeam4;
    else
        % Nortek 3 beams
        nonMappedHeightAboveSensorBeam1 = (cos(beamAngle - pitch)/cos(beamAngle)) * distAlongBeams';
        nonMappedHeightAboveSensorBeam1 = repmat(cos(roll), 1, nBins) .* nonMappedHeightAboveSensorBeam1;
        
        beamAngleX = atan(tan(beamAngle) * cos(60*pi/180)); % beams 2 and 3 angle projected on the X axis
        beamAngleY = atan(tan(beamAngle) * cos(30*pi/180)); % beams 2 and 3 angle projected on the Y axis
        
        nonMappedHeightAboveSensorBeam2 = (cos(beamAngleX + pitch)/cos(beamAngleX)) * distAlongBeams';
        nonMappedHeightAboveSensorBeam2 = repmat(cos(beamAngleY + roll)/cos(beamAngleY), 1, nBins) .* nonMappedHeightAboveSensorBeam2;
        
        nonMappedHeightAboveSensorBeam3 = (cos(beamAngleX + pitch)/cos(beamAngleX)) * distAlongBeams';
        nonMappedHeightAboveSensorBeam3 = repmat(cos(beamAngleY - roll)/cos(beamAngleY), 1, nBins) .* nonMappedHeightAboveSensorBeam3;
    end
    
    nSamples = length(pitch);
    mappedHeightAboveSensor = repmat(distAlongBeams', nSamples, 1);
  
    % we can now interpolate mapped values per bin when needed for each
    % impacted parameter
    isBinMapApplied = false;
    for j=1:length(sample_data{k}.variables)
        if any(sample_data{k}.variables{j}.dimensions == distAlongBeamsIdx) % only process variables that are function of DIST_ALONG_BEAMS
            
            % only process variables that are in beam coordinates
            beamNumber = sample_data{k}.variables{j}.long_name(end);
            switch beamNumber
                case '1'
                    nonMappedHeightAboveSensor = nonMappedHeightAboveSensorBeam1;
                case '2'
                    nonMappedHeightAboveSensor = nonMappedHeightAboveSensorBeam2;
                case '3'
                    nonMappedHeightAboveSensor = nonMappedHeightAboveSensorBeam3;
                case '4'
                    nonMappedHeightAboveSensor = nonMappedHeightAboveSensorBeam4;
                otherwise
                    % do not process this variable if not in beam coordinates
                    continue;
            end
        
            isBinMapApplied = true;
            
            % let's now interpolate data values at nominal bin height for
            % each profile
            nonMappedData = sample_data{k}.variables{j}.data;
            mappedData = NaN(size(nonMappedData), 'single');
            for i=1:nSamples
                mappedData(i,:) = interp1(nonMappedHeightAboveSensor(i,:), nonMappedData(i,:), mappedHeightAboveSensor(i,:));
                % there is a risk of ending up with a NaN for the first bin
                % while the difference between its nominal and tilted
                % position is negligeable so we can arbitrarily set it to 
                % its value when tilted (RDI practice).
                mappedData(i,1) = nonMappedData(i,1);
                % there is also a risk of ending with a NaN for the last
                % good bin (one beam has this bin slightly below its
                % bin-mapped nominal position and that's a shame we miss 
                % it). For this bin, using extrapolation methods like 
                % spline could still be ok.
%                 iLastGoodBin = find(isnan(mappedData(i,:)), 1, 'first');
%                 mappedData(i,iLastGoodBin) = interp1(nonMappedHeightAboveSensor(i,:), nonMappedData(i,:), mappedHeightAboveSensor(i,iLastGoodBin), 'spline');
            end
            
            binMappingComment = ['adcpBinMappingPP.m: data in beam coordinates originally referenced to DIST_ALONG_BEAMS ' ...
                'has been vertically bin-mapped to HEIGHT_ABOVE_SENSOR using tilt information.'];
            
            if ~heightAboveSensorIdx
                % we create the HEIGHT_ABOVE_SENSOR dimension if needed
                sample_data{k}.dimensions{end+1}             = sample_data{k}.dimensions{distAlongBeamsIdx};
                
                % attributes units, reference_datum, valid_min/max and _FillValue are the same as with DIST_ALONG_BEAMS, the rest differs
                sample_data{k}.dimensions{end}.name            = 'HEIGHT_ABOVE_SENSOR';
                sample_data{k}.dimensions{end}.long_name       = 'height_above_sensor';
                sample_data{k}.dimensions{end}.standard_name   = imosParameters('HEIGHT_ABOVE_SENSOR', 'standard_name');
                sample_data{k}.dimensions{end}.axis            = 'Z';
                sample_data{k}.dimensions{end}.positive        = imosParameters('HEIGHT_ABOVE_SENSOR', 'positive');
                sample_data{k}.dimensions{end}.comment         = ['Data has been vertically bin-mapped using tilt information so that the cells ' ...
                    'have consistant heights above sensor in time.'];
                
                heightAboveSensorIdx = getVar(sample_data{k}.dimensions, 'HEIGHT_ABOVE_SENSOR');
            end
            
            % we re-assign the parameter to the HEIGHT_ABOVE_SENSOR dimension
            sample_data{k}.variables{j}.dimensions(sample_data{k}.variables{j}.dimensions == distAlongBeamsIdx) = heightAboveSensorIdx;
                
            sample_data{k}.variables{j}.data = mappedData;
            
            comment = sample_data{k}.variables{j}.comment;
            if isempty(comment)
                sample_data{k}.variables{j}.comment = binMappingComment;
            else
                sample_data{k}.variables{j}.comment = [comment ' ' binMappingComment];
            end
            
            sample_data{k}.variables{j}.coordinates = 'TIME LATITUDE LONGITUDE HEIGHT_ABOVE_SENSOR';
        end
    end
    
    if isBinMapApplied
        % let's look for remaining variables assigned to DIST_ALONG_BEAMS,
        % if none we can remove this dimension (RDI for example)
        isDistAlongBeamsUsed = false;
        for j=1:length(sample_data{k}.variables)
            if any(sample_data{k}.variables{j}.dimensions == distAlongBeamsIdx)
                isDistAlongBeamsUsed = true;
                break;
            end
        end
        if ~isDistAlongBeamsUsed
            if length(sample_data{k}.dimensions) > distAlongBeamsIdx
                for j=1:length(sample_data{k}.variables)
                    dimToUpdate = sample_data{k}.variables{j}.dimensions > distAlongBeamsIdx;
                    if any(dimToUpdate)
                        sample_data{k}.variables{j}.dimensions(dimToUpdate) = sample_data{k}.variables{j}.dimensions(dimToUpdate) - 1;
                    end
                end
            end
            sample_data{k}.dimensions(distAlongBeamsIdx) = [];
            
            binMappingComment = [binMappingComment ' DIST_ALONG_BEAMS is not used by any variable left and has been removed.'];
        end
        
        history = sample_data{k}.history;
        if isempty(history)
            sample_data{k}.history = sprintf('%s - %s', datestr(now_utc, readProperty('exportNetCDF.dateFormat')), binMappingComment);
        else
            sample_data{k}.history = sprintf('%s\n%s - %s', history, datestr(now_utc, readProperty('exportNetCDF.dateFormat')), binMappingComment);
        end
    end
end
