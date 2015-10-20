function sample_data = rdiBinMappingVelocityPP( sample_data, qcLevel, auto )
%RDIBINMAPPINGVELOCITYPP bin-maps any RDI variable expressed in 4 beams coordinates 
%and which is function of DIST_ALONG_BEAMS into a HEIGHT_ABOVE_SENSOR dimension.
%
% It is assumed that the beams are in such configuration such as when pitch
% is positive beam 3 is closer to the surface while beam 4 gets further
% away. When roll is positive beam 2 is closer to the surface while beam 1
% gets further away. For each beam, the data values at the nominal vertical
% bin heights are obtained by interpolation.
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

% auto logical in input to enable running under batch processing
if nargin<3, auto=false; end

if strcmpi(qcLevel, 'raw'), return; end

for k = 1:length(sample_data)
    % do not process if not RDI
    if ~strcmpi(sample_data{k}.meta.instrument_make, 'Teledyne RDI'), continue; end
    
    heightAboveSensorIdx = getVar(sample_data{k}.dimensions, 'HEIGHT_ABOVE_SENSOR');
    distAlongBeamsIdx = getVar(sample_data{k}.dimensions, 'DIST_ALONG_BEAMS');
    pitchIdx = getVar(sample_data{k}.variables, 'PITCH');
    rollIdx  = getVar(sample_data{k}.variables, 'ROLL');  
  
    % pitch, roll, and dist_along_beams not present in data set
    if ~(distAlongBeamsIdx && pitchIdx && rollIdx), continue; end
  
    distAlongBeams = sample_data{k}.dimensions{distAlongBeamsIdx}.data;
    pitch = sample_data{k}.variables{pitchIdx}.data*pi/180;
    roll  = sample_data{k}.variables{rollIdx}.data*pi/180;
    
    beamAngle = sample_data{k}.meta.beam_angle*pi/180;
    nBins = length(distAlongBeams);
    nonMappedHeightAboveSensorBeam4 = (cos(beamAngle + pitch)/cos(beamAngle))*distAlongBeams';
    nonMappedHeightAboveSensorBeam3 = (cos(beamAngle - pitch)/cos(beamAngle))*distAlongBeams';
    nonMappedHeightAboveSensorBeam1 = (cos(beamAngle + roll)/cos(beamAngle))*distAlongBeams';
    nonMappedHeightAboveSensorBeam2 = (cos(beamAngle - roll)/cos(beamAngle))*distAlongBeams';
    
    nSamples = length(pitch);
    mappedHeightAboveSensor = repmat(distAlongBeams', nSamples, 1);
  
    % now we can now interpolate mapped values per bin when needed for each
    % impacted parameter
    isBinMapApplied = false;
    for j=1:length(sample_data{k}.variables)
        beamNumber = sample_data{k}.variables{j}.name(end);
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
                % do not process if not in beam coordinates
                continue;
        end
        
        if any(sample_data{k}.variables{j}.dimensions == distAlongBeamsIdx)
            % only process variables that are function of DIST_ALONG_BEAMS
            isBinMapApplied = true;
            
            % let's now interpolate data values at nominal bin height for
            % each profile
            nonMappedData = sample_data{k}.variables{j}.data;
            mappedData = NaN(size(nonMappedData), 'single');
            for i=1:nSamples
                mappedData(i,:) = interp1(nonMappedHeightAboveSensor(i,:), nonMappedData(i,:), mappedHeightAboveSensor(i,:));
            end
            
            binMappingComment = 'rdiBinMappingVelocityPP.m: data originally referenced to DISTANCE_ALONG_BEAMS has been vertically bin-mapped to HEIGHT_ABOVE_SENSOR using tilt information.';
            if heightAboveSensorIdx
                % we re-assign the parameter to this dimension
                sample_data{k}.variables{j}.dimensions(sample_data{k}.variables{j}.dimensions == distAlongBeamsIdx) = heightAboveSensorIdx;
            else
                % we update the dimension information
                sample_data{k}.dimensions{distAlongBeamsIdx}.name = 'HEIGHT_ABOVE_SENSOR';
                sample_data{k}.dimensions{distAlongBeamsIdx}.long_name = 'height_above_sensor';
                sample_data{k}.dimensions{distAlongBeamsIdx}.axis = 'Z';
                sample_data{k}.dimensions{distAlongBeamsIdx}.positive = 'up';
                sample_data{k}.dimensions{distAlongBeamsIdx}.comment = 'Data has been vertically bin-mapped using tilt information so that the cells have consistant heights above sensor in time.';
            end
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
    
    % we need to remove DIST_ALONG_BEAMS if still exists
    if heightAboveSensorIdx && distAlongBeamsIdx
        sample_data{k}.dimensions(distAlongBeamsIdx) = [];
    end

    if isBinMapApplied
        history = sample_data{k}.history;
        if isempty(history)
            sample_data{k}.history = sprintf('%s - %s', datestr(now_utc, readProperty('exportNetCDF.dateFormat')), binMappingComment);
        else
            sample_data{k}.history = sprintf('%s\n%s - %s', history, datestr(now_utc, readProperty('exportNetCDF.dateFormat')), binMappingComment);
        end
    end
end
