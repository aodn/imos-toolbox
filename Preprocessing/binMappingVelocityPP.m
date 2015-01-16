function sample_data = binMappingVelocityPP( sample_data, qcLevel, auto )
%BINMAPPINGVELOCITYPP bin-maps any variable that is function of DIST_ALONG_BEAMS
%into a HEIGHT_ABOVE_SENSOR dimension.
%
% The tilt is infered from pitch and roll measurement and used to map bins
% along the beams towards vertical bins (case when tilt is 0). When more
% than one bin is mapped to the same bin then the mean is computed.
%
% Inputs:
%   sample_data - cell array of data sets, ideally with DIST_ALONG_BEAMS dimension.
%   qcLevel     - string, 'raw' or 'qc'. Some pp not applied when 'raw'.
%   auto        - logical, run pre-processing in batch mode.
%
% Outputs:
%   sample_data - the same data sets, with any variable originally function 
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
    pitch = sample_data{k}.variables{pitchIdx}.data;
    roll  = sample_data{k}.variables{rollIdx}.data;
    
    tilt = acos(sqrt(1 - sin(roll*pi/180).^2 - sin(pitch*pi/180).^2));
    
    binSize = sample_data{k}.meta.binSize;
    nBins = length(distAlongBeams);
    heightAboveSensorUp   = distAlongBeams + binSize/2;
    heightAboveSensorDown = distAlongBeams - binSize/2;
    nonMappedHeightAboveSensor = cos(tilt)*distAlongBeams';
    
    % bin-mapping one bin at a time
    mappedHeightAboveSensor = NaN(size(nonMappedHeightAboveSensor));
    for i=1:nBins
        iNonMappedCurrentBin = (nonMappedHeightAboveSensor >= heightAboveSensorDown(i)) & (nonMappedHeightAboveSensor < heightAboveSensorUp(i));
        mappedHeightAboveSensor(iNonMappedCurrentBin) = i;
    end
  
    % now we can average mapped values per bin when needed for each
    % impacted parameter
    isBinMapApplied = false;
    for j=1:length(sample_data{k}.variables)
        if any(sample_data{k}.variables{j}.dimensions == distAlongBeamsIdx)
            isBinMapApplied = true;
            nonMappedData = sample_data{k}.variables{j}.data;
            mappedData = NaN(size(nonMappedData));
            for i=1:nBins
                iMappedCurrentBin = mappedHeightAboveSensor == i*ones(size(mappedHeightAboveSensor));
                tmpNonMappedData = nonMappedData;
                tmpNonMappedData(~iMappedCurrentBin) = NaN;
                mappedData(:, i) = nanmean(tmpNonMappedData, 2);
            end
            
            binMappingComment = 'binMappingVelocityPP.m: data originally referenced to DISTANCE_ALONG_BEAMS has been vertically bin-mapped to HEIGHT_ABOVE_SENSOR using tilt information.';
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
