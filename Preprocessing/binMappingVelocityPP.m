function sample_data = binMappingVelocityPP( sample_data, qcLevel, auto )
%BINMAPPINGVELOCITYPP bin-maps any variable not expressed in beams coordinates
%that is function of DIST_ALONG_BEAMS into a HEIGHT_ABOVE_SENSOR dimension.
%
% The tilt is infered from pitch and roll measurement and used to map bins
% along the beams towards vertical bins (case when tilt is 0). Data values
% at nominal vertical bin heights are obtained by interpolation.
% 
% !!!WARNING!!! This function provides OK results for small tilt angles. When
% tilt is important enough for same cells of distinct beams not being in the same
% vertical plane, it is recommended to perform specific bin mapping with data expressed 
% in beam coordinates.
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
  
    heightAboveSensorIdx = getVar(sample_data{k}.dimensions, 'HEIGHT_ABOVE_SENSOR');
    distAlongBeamsIdx = getVar(sample_data{k}.dimensions, 'DIST_ALONG_BEAMS');
    pitchIdx = getVar(sample_data{k}.variables, 'PITCH');
    rollIdx  = getVar(sample_data{k}.variables, 'ROLL');  
  
    % pitch, roll, and dist_along_beams not present in data set
    if ~(distAlongBeamsIdx && pitchIdx && rollIdx), continue; end
  
    distAlongBeams = sample_data{k}.dimensions{distAlongBeamsIdx}.data;
    pitch = sample_data{k}.variables{pitchIdx}.data*pi/180;
    roll  = sample_data{k}.variables{rollIdx}.data*pi/180;
    
    tilt = acos(abs(sqrt(1 - sin(roll).^2 - sin(pitch).^2)));
    
    nonMappedHeightAboveSensor = cos(tilt)*distAlongBeams';
    
    nSamples = length(tilt);
    mappedHeightAboveSensor = repmat(distAlongBeams', nSamples, 1);
  
    % now we can interpolate mapped values per bin when needed for each
    % impacted parameter
    isBinMapApplied = false;
    for j=1:length(sample_data{k}.variables)
        isBeamCoordinates = any(strcmpi(sample_data{k}.variables{j}.name(end), {'1', '2', '3', '4'}));
        if any(sample_data{k}.variables{j}.dimensions == distAlongBeamsIdx & ~isBeamCoordinates)
            % only process variables that are function of DIST_ALONG_BEAMS
            % and not expressed in beams coordinates
            isBinMapApplied = true;
            
            % let's now interpolate data values at nominal bin height for
            % each profile
            nonMappedData = sample_data{k}.variables{j}.data;
            mappedData = NaN(size(nonMappedData), 'single');
            for i=1:nSamples
                mappedData(i,:) = interp1(nonMappedHeightAboveSensor(i,:), nonMappedData(i,:), mappedHeightAboveSensor(i,:));
            end
            
            binMappingComment = 'binMappingVelocityPP.m: data originally referenced to DISTANCE_ALONG_BEAMS has been vertically bin-mapped to HEIGHT_ABOVE_SENSOR using tilt information.';
            if ~heightAboveSensorIdx
                % we create the necessary dimension
                sample_data{k}.dimensions{end+1} = sample_data{k}.dimensions{distAlongBeamsIdx};
                sample_data{k}.dimensions{end}.name = 'HEIGHT_ABOVE_SENSOR';
                sample_data{k}.dimensions{end}.long_name = 'height_above_sensor';
                sample_data{k}.dimensions{end}.axis = 'Z';
                sample_data{k}.dimensions{end}.positive = 'up';
                sample_data{k}.dimensions{end}.comment = 'Data has been vertically bin-mapped using tilt information so that the cells have consistant heights above sensor in time.';
                
                heightAboveSensorIdx = getVar(sample_data{k}.dimensions, 'HEIGHT_ABOVE_SENSOR');
            end
            % we re-assign the parameter to HEIGHT_ABOVE_SENSOR dimension
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
        history = sample_data{k}.history;
        if isempty(history)
            sample_data{k}.history = sprintf('%s - %s', datestr(now_utc, readProperty('exportNetCDF.dateFormat')), binMappingComment);
        else
            sample_data{k}.history = sprintf('%s\n%s - %s', history, datestr(now_utc, readProperty('exportNetCDF.dateFormat')), binMappingComment);
        end
    end
end
