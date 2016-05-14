function sample_data = adcpNortekVelocityBeam2EnuPP( sample_data, qcLevel, auto )
%ADCPNORTEKVELOCITYBEAM2ENUPP transforms Nortek velocity data expressed in 
% Beam coordinates to Easting Northing Up (ENU) coordinates. Only applies
% on FV01 dataset.
%
% We apply the provided Beam to XYZ matrix transformation to which we add
% the ADCP attitude information (upward/downward looking, heading, pitch
% and roll) following http://www.nortek-as.com/lib/forum-attachments/coordinate-transformation/view.
%
% Inputs:
%   sample_data - cell array of data sets.
%   qcLevel     - string, 'raw' or 'qc'. Some pp not applied when 'raw'.
%   auto        - logical, run pre-processing in batch mode.
%
% Outputs:
%   sample_data - the same data sets, with updated velocity variables in ENU coordinates.
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
narginchk(2, 3);

if ~iscell(sample_data), error('sample_data must be a cell array'); end
if isempty(sample_data), return;                                    end

% auto logical in input to enable running under batch processing
if nargin<3, auto=false; end

% no modification of data is performed on the raw FV00 dataset except
% local time to UTC conversion
if strcmpi(qcLevel, 'raw'), return; end

for k = 1:length(sample_data)
    % do not process if not Nortek
    if ~strcmpi(sample_data{k}.meta.instrument_make, 'Nortek'), continue; end
  
    % do not process if not current profiler ADCP
    distAlongBeamsIdx = getVar(sample_data{k}.dimensions, 'DIST_ALONG_BEAMS');
    if ~distAlongBeamsIdx, continue; end
    
    % do not process if heading, pitch and roll not present in data set
    isMagCorrected = true;
    headingIdx = getVar(sample_data{k}.variables, 'HEADING');
    if ~headingIdx
        isMagCorrected = false;
        headingIdx  = getVar(sample_data{k}.variables, 'HEADING_MAG');
    end
    pitchIdx   = getVar(sample_data{k}.variables, 'PITCH');
    rollIdx    = getVar(sample_data{k}.variables, 'ROLL');
    if ~(headingIdx && pitchIdx && rollIdx), continue; end
  
    % do not process if no velocity data in beam coordinates
    vel1Idx  = getVar(sample_data{k}.variables, 'VEL1');
    vel2Idx  = getVar(sample_data{k}.variables, 'VEL2');
    vel3Idx  = getVar(sample_data{k}.variables, 'VEL3');
    if ~(vel1Idx && vel2Idx && vel3Idx), continue; end
    
    % do not process if more than 3 beams
    vel4Idx  = getVar(sample_data{k}.variables, 'VEL4');
    if vel4Idx, continue; end
    
    % do not process if transformation matrix not known
    if isfield(sample_data{k}.meta, 'beam_to_xyz_transform')
        beam2xyz = sample_data{k}.meta.beam_to_xyz_transform;
    else
        continue;
    end
    
    vel1 = sample_data{k}.variables{vel1Idx}.data;
    vel2 = sample_data{k}.variables{vel2Idx}.data;
    vel3 = sample_data{k}.variables{vel3Idx}.data;
    
    heading = sample_data{k}.variables{headingIdx}.data;
    pitch = sample_data{k}.variables{pitchIdx}.data;
    roll  = sample_data{k}.variables{rollIdx}.data;
    
    dist = sample_data{k}.dimensions{distAlongBeamsIdx}.data;
    heightAboveSensorIdx = getVar(sample_data{k}.dimensions, 'HEIGHT_ABOVE_SENSOR');
    if any(sample_data{k}.variables{vel1Idx}.dimensions == heightAboveSensorIdx)
        dist = sample_data{k}.dimensions{heightAboveSensorIdx}.data;
    end
    
    % If instrument is pointing down dist is negative and
    % rows 2 and 3 must change sign
    if all(sign(dist) == -1),
        beam2xyz(2,:) = -beam2xyz(2,:);
        beam2xyz(3,:) = -beam2xyz(3,:);
    end
    
    [nSample, nBin] = size(vel1);
    velENU = NaN(3, nSample, nBin);
    for i=1:nSample
        % heading, pitch and roll are the angles output in the data in degrees
        hh = (heading(i) - 90) * pi/180;
        pp = pitch(i) * pi/180;
        rr = roll(i) * pi/180;
        
        % heading matrix
        H = [cos(hh) sin(hh) 0; ...
            -sin(hh) cos(hh) 0; ...
             0       0       1];
        
        % tilt matrix
        P = [cos(pp) -sin(pp)*sin(rr) -cos(rr)*sin(pp); ...
             0       cos(rr)          -sin(rr); ...
             sin(pp) sin(rr)*cos(pp)  cos(pp)*cos(rr)];
        
        % resulting transformation matrix
        R = H*P*beam2xyz;
        
        % Given Beam velocities, ENU coordinates are calculated as
        for j=1:nBin
            velBeam = [vel1(i, j); vel2(i, j); vel3(i, j)];
            velENU(:, i, j) = R*velBeam;
        end
    end
    
    Beam2EnuComment = ['adcpNortekVelocityBeam2EnuPP.m: velocity data in Easting Northing Up (ENU) coordinates has been calculated from velocity data in Beams coordinates ' ...
        'using heading and tilt information and instrument coordinate transform matrix.'];
    
    % we update the velocity values in ENU coordinates
    vars = {'UCUR', 'VCUR', 'WCUR'};
    varSuffix = '';
    if ~isMagCorrected, varSuffix = '_MAG'; end
    for l=1:length(vars)
        if strcmpi(vars{l}, 'WCUR')
            curIdx  = getVar(sample_data{k}.variables, vars{l});
        else
            curIdx  = getVar(sample_data{k}.variables, [vars{l} varSuffix]);
        end
        sample_data{k}.variables{curIdx}.data = squeeze(velENU(l, :, :));
        
        % need to update the dimensions/coordinates in case velocity in Beam
        % coordinates would have been previously bin-mapped
        sample_data{k}.variables{curIdx}.dimensions = sample_data{k}.variables{vel1Idx}.dimensions;
        sample_data{k}.variables{curIdx}.coordinates = sample_data{k}.variables{vel1Idx}.coordinates;
        
        if ~isfield(sample_data{k}.variables{curIdx}, 'comment')
            sample_data{k}.variables{curIdx}.comment = Beam2EnuComment;
        else
            sample_data{k}.variables{curIdx}.comment = [sample_data{k}.variables{curIdx}.comment ' ' Beam2EnuComment];
        end
    end
    
    if ~isfield(sample_data{k}, 'history')
        sample_data{k}.history = sprintf('%s - %s', datestr(now_utc, readProperty('exportNetCDF.dateFormat')), Beam2EnuComment);
    else
        sample_data{k}.history = sprintf('%s\n%s - %s', sample_data{k}.history, datestr(now_utc, readProperty('exportNetCDF.dateFormat')), Beam2EnuComment);
    end
end
