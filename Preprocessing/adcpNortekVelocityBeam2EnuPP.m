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
    heightAboveSensorIdx = getVar(sample_data{k}.dimensions, 'HEIGHT_ABOVE_SENSOR');
    if ~distAlongBeamsIdx
        if ~heightAboveSensorIdx, continue; end
    end
    
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
    %if vel4Idx, continue; end
    
    % do not process if transformation matrix not known
    if isfield(sample_data{k}.meta, 'beam_to_xyz_transform')
        beam2xyz = sample_data{k}.meta.beam_to_xyz_transform;
    else
        continue;
    end
    
    vel1 = sample_data{k}.variables{vel1Idx}.data;
    vel2 = sample_data{k}.variables{vel2Idx}.data;
    vel3 = sample_data{k}.variables{vel3Idx}.data;
	if vel4Idx, vel4 = sample_data{k}.variables{vel4Idx}.data; end
    
    heading = sample_data{k}.variables{headingIdx}.data;
    pitch = sample_data{k}.variables{pitchIdx}.data;
    roll  = sample_data{k}.variables{rollIdx}.data;
    
    if distAlongBeamsIdx
        dist = sample_data{k}.dimensions{distAlongBeamsIdx}.data;
    end
    if any(sample_data{k}.variables{vel1Idx}.dimensions == heightAboveSensorIdx)
        dist = sample_data{k}.dimensions{heightAboveSensorIdx}.data;
    end
    
    % If instrument is pointing down dist is negative and
    % rows 2 and 3 must change sign
	%% only good for 3 beams ?? %%
    if all(sign(dist) == -1)
        beam2xyz(2,:) = -beam2xyz(2,:);
        beam2xyz(3,:) = -beam2xyz(3,:);
    end
    
    [nSample, nBin] = size(vel1);
	
	if ~vel4Idx
		% 3 beams
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
    else
        % debug
%             fname = ['beam' jStr '.mat'];
%             beam = sample_data{k}.variables{end}.data;
%             save(fname,'beam');
%             save('beam1a.mat','vel1');
%             save('beam2a.mat','vel2');
%             save('beam3a.mat','vel3');
%             save('beam4a.mat','vel4');
%             
		% 4 beam conversion
		velENU = NaN(4, nSample, nBin);
		
		% from Nortek script "Sig4beam_transform.m"		
		% Transform attitude data to radians
		hh = pi * (heading-90)/180;
		pp = pi * pitch/180;
		rr = pi * roll/180;
		
		
		[row,col] = size(vel1);
		Tmat = repmat(beam2xyz,[1 1 row]);

		clear beam2xyz;
		
		% Make heading/tilt matrices
		Hmat = zeros(3,3,row);
		Pmat = zeros(3,3,row);

		for i = 1:row
			Hmat(:,:,i) = [ cos(hh(i)) sin(hh(i))     0; ...
						   -sin(hh(i)) cos(hh(i))     0; ...
									 0          0     1];
			Pmat(:,:,i) = [cos(pp(i)) -sin(pp(i))*sin(rr(i)) -cos(rr(i))*sin(pp(i)); ...
							   0              cos(rr(i))            -sin(rr(i))    ; ...
						   sin(pp(i))  sin(rr(i))*cos(pp(i))  cos(pp(i))*cos(rr(i))];
		end

		clear heading pitch roll hh pp rr;
		
		% Add a fourth line in the matrix based on Transformation matrix by 
		% copying line 3, and set (3,4) and (4,3) to 0. B3 and B4 will contribute 
		% equally to the X and Y components, so (1,3) and (1,4) = (1,3)/2. The 
		% same goes for (2,3) and (2,4)
		% (1,1) (1,2) (1,3) (1,4)
		% (2,1) (2,2) (2,3) (2,4)
		% (3,1) (3,2) (3,3) (3,4)
		% (4,1) (4,2) (4,3) (4,4)

		% Make resulting transformation matrix
		R1mat = zeros(4,4,row);
		for i = 1:row
			R1mat(1:3,1:3,i) = Hmat(:,:,i)*Pmat(:,:,i);
			R1mat(4,1:4,i) = R1mat(3,1:4,i);
			R1mat(1:4,4,i) = R1mat(1:4,3,i);
		end

		R1mat(3,4,:) = 0; R1mat(4,3,:) = 0;
        % added to nortek code
        R1mat(1,4,:) = R1mat(1,3,:)/2.0; 
        R1mat(1,3,:) = R1mat(1,3,:)/2.0;
        R1mat(2,4,:) = R1mat(2,3,:)/2.0; 
        R1mat(2,3,:) = R1mat(2,3,:)/2.0;
        
		for i = 1:row
			Rmat(:,:,i) = R1mat(:,:,i)*Tmat(:,:,i);
		end

		clear Hmat Pmat R1mat;
		
    
		%% BEAM to ENU [E; N; U1; U2] = R * [B1; B2; B3; B4]
		ENU = zeros(row,col,4);
		for i = 1:row
			for j = 1:col
				ENU(i,j,:) = Rmat(:,:,i) * [vel1(i,j); vel2(i,j); vel3(i,j); vel4(i,j)];
			end
		end
		%E = ENU(:,:,1); N = ENU(:,:,2);
		%U1 = ENU(:,:,3); U2 = ENU(:,:,4);
		velENU(1, :, :) = ENU(:,:,1);
		velENU(2, :, :) = ENU(:,:,2);
		velENU(3, :, :) = ENU(:,:,3);
		velENU(4, :, :) = ENU(:,:,4);
		
		clear i j row col v1 v2 v3 v4 ENU Rmat Tmat
	end
	
    Beam2EnuComment = ['adcpNortekVelocityBeam2EnuPP.m: velocity data in Easting Northing Up (ENU) coordinates has been calculated from velocity data in Beams coordinates ' ...
        'using heading and tilt information and instrument coordinate transform matrix.'];
    
    % we update the velocity values in ENU coordinates
    if ~vel4Idx
		vars = {'UCUR', 'VCUR', 'WCUR'}; 
		if ~isMagCorrected
			varSuffix = {'_MAG', '_MAG', ''};
		else
			varSuffix = {'', '', ''};
		end
	else
		vars = {'UCUR', 'VCUR', 'WCUR', 'WCUR_2'}; 
		if ~isMagCorrected
			varSuffix = {'_MAG', '_MAG', '', ''};
		else
			varSuffix = {'', '', '', ''};
		end
	end
    
	
    for l=1:length(vars)
        varName = [vars{l} varSuffix{l}];
        curIdx = getVar(sample_data{k}.variables, varName);
        if curIdx
            % we update the velocity values in ENU coordinates
            sample_data{k}.variables{curIdx}.data = squeeze(velENU(l, :, :));
% debug            
%              fname = [varName '.mat'];
%              vel = sample_data{k}.variables{curIdx}.data;
%              save(fname,'vel');
                      
            % need to update the dimensions/coordinates in case velocity in Beam
            % coordinates would have been previously bin-mapped
            sample_data{k}.variables{curIdx}.dimensions = sample_data{k}.variables{vel1Idx}.dimensions;
            sample_data{k}.variables{curIdx}.coordinates = sample_data{k}.variables{vel1Idx}.coordinates;
            
            if ~isfield(sample_data{k}.variables{curIdx}, 'comment')
                sample_data{k}.variables{curIdx}.comment = Beam2EnuComment;
            else
                sample_data{k}.variables{curIdx}.comment = [sample_data{k}.variables{curIdx}.comment ' ' Beam2EnuComment];
            end
        else
            % we create a new variable for velocity values in ENU coordinates
            sample_data{k} = addVar(...
                sample_data{k}, ...
                varName, ...
                squeeze(velENU(l, :, :)), ...
                sample_data{k}.variables{vel1Idx}.dimensions, ...
                Beam2EnuComment, ...
                sample_data{k}.variables{vel1Idx}.coordinates);
        end
    end
    
    if distAlongBeamsIdx
        % let's look for remaining variables assigned to DIST_ALONG_BEAMS,
        % if none we can remove this dimension
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
            
            Beam2EnuComment = [Beam2EnuComment ' DIST_ALONG_BEAMS is not used by any variable left and has been removed.'];
        end
    end
    
    if ~isfield(sample_data{k}, 'history')
        sample_data{k}.history = sprintf('%s - %s', datestr(now_utc, readProperty('exportNetCDF.dateFormat')), Beam2EnuComment);
    else
        sample_data{k}.history = sprintf('%s\n%s - %s', sample_data{k}.history, datestr(now_utc, readProperty('exportNetCDF.dateFormat')), Beam2EnuComment);
    end
end
