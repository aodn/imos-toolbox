function sample_data = adcpNortekVelocityEnu2BeamPP( sample_data, qcLevel, auto )
%ADCPNORTEKVELOCITYENU2BEAMPP transforms Nortek velocity data expressed in 
% Easting Northing Up (ENU) coordinates to Beam coordinates. Only applies
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
%   sample_data - the same data sets, with added velocity variables in Beam coordinates.
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
    
    
    % not preocessed if more than 3 beams but sig55 has 3 beams so catch it
    % here
    %if ~strcmpi(sample_data{k}.meta.instrument_model, 'Signature55'), continue; end
    
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
  
  
  
  
  
    % do not process if no velocity data in ENU coordinates
    varSuffix = '';
    if ~isMagCorrected, varSuffix = '_MAG'; end
    ucurIdx = getVar(sample_data{k}.variables, ['UCUR' varSuffix]);
    vcurIdx = getVar(sample_data{k}.variables, ['VCUR' varSuffix]);
    wcurIdx = getVar(sample_data{k}.variables, 'WCUR');
	wcur2Idx = getVar(sample_data{k}.variables, 'WCUR_2');
    if ~(ucurIdx && vcurIdx && wcurIdx), continue; end
    
    % do not process if more than 3 beams
    absic4Idx = getVar(sample_data{k}.variables, 'ABSIC4');
    %if absic4Idx, continue; end
    
    ucur = sample_data{k}.variables{ucurIdx}.data;
    vcur = sample_data{k}.variables{vcurIdx}.data;
    wcur = sample_data{k}.variables{wcurIdx}.data;
	if absic4Idx, wcur2 = sample_data{k}.variables{wcur2Idx}.data; end
    
    heading = sample_data{k}.variables{headingIdx}.data;
    pitch = sample_data{k}.variables{pitchIdx}.data;
    roll  = sample_data{k}.variables{rollIdx}.data;
    
    dist = sample_data{k}.dimensions{distAlongBeamsIdx}.data;
    heightAboveSensorIdx = getVar(sample_data{k}.dimensions, 'HEIGHT_ABOVE_SENSOR');
    if any(sample_data{k}.variables{ucurIdx}.dimensions == heightAboveSensorIdx)
        dist = sample_data{k}.dimensions{heightAboveSensorIdx}.data;
    end
    
	
	
	
    Enu2BeamComment = ['adcpNortekVelocityEnu2BeamPP.m: velocity data in Beams coordinates has been calculated from velocity data in Easting Northing Up (ENU) coordinates ' ...
        'using heading and tilt information and instrument coordinate transform matrix.'];
    
	
    beam2xyz = sample_data{k}.meta.beam_to_xyz_transform;
    
    % If instrument is pointing down dist is negative and
    % rows 2 and 3 must change sign
	%%% only good for 3 beams ??  %%%
    if all(sign(dist) == -1),
        beam2xyz(2,:) = -beam2xyz(2,:);
        beam2xyz(3,:) = -beam2xyz(3,:);
    end
    
	
    [nSample, nBin] = size(ucur);
    velBeam = NaN(3, nSample, nBin);
	if absic4Idx, velBeam = NaN(4, nSample, nBin); end
	
	if ~absic4Idx
		% 3 beam conversion
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
			
			% Given ENU velocities, beam coordinates are calculated as
			for j=1:nBin
				velENU = [ucur(i, j); vcur(i, j); wcur(i, j)];
				velBeam(:, i, j) = R\velENU; % cannot be vectorised, left division doesn't handle nD matrices with n>2
			end
		end
		
		for l=1:3
			jStr = num2str(l);
			varName = ['VEL' jStr];
			sample_data{k}.variables{end+1} = sample_data{k}.variables{ucurIdx};
			sample_data{k}.variables{end}.name = varName;
			sample_data{k}.variables{end}.standard_name = imosParameters(varName, 'standard_name');
			sample_data{k}.variables{end}.long_name = imosParameters(varName, 'long_name');
			sample_data{k}.variables{end}.unit = imosParameters(varName, 'uom');
			sample_data{k}.variables{end}.reference_datum = imosParameters(varName, 'reference_datum');
			sample_data{k}.variables{end}.positive = imosParameters(varName, 'positive');
			sample_data{k}.variables{end}.valid_min = imosParameters(varName, 'valid_min');
			sample_data{k}.variables{end}.valid_max = imosParameters(varName, 'valid_max');
			sample_data{k}.variables{end}.FillValue_ = imosParameters(varName, 'fill_value');
			sample_data{k}.variables{end}.data = squeeze(velBeam(l, :, :));
			
			if ~isfield(sample_data{k}.variables{end}, 'comment')
				sample_data{k}.variables{end}.comment = Enu2BeamComment;
			else
				sample_data{k}.variables{end}.comment = [sample_data{k}.variables{end}.comment ' ' Enu2BeamComment];
			end
		end
		
    else
		% 4 beam conversion
		% from Nortek script "Sig4beam_transform.m"
		
		% Transform attitude data to radians
		hh = pi * (heading-90)/180;
		pp = pi * pitch/180;
		rr = pi * roll/180;
		
		
		[row,col] = size(ucur);
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

		%% ENU to BEAM [B1; B2; B3; B4] = inv(R) * [E; N; U1; U2]    
		BEAM = zeros(row,col,4);
		for i = 1:row
			for j = 1:col
				BEAM(i,j,:) = inv(Rmat(:,:,i)) * [ucur(i,j); vcur(i,j); wcur(i,j); wcur2(i,j)];
			end
		end
		
		for l=1:4
			jStr = num2str(l);
			varName = ['VEL' jStr];
			sample_data{k}.variables{end+1} = sample_data{k}.variables{ucurIdx};
			sample_data{k}.variables{end}.name = varName;
			sample_data{k}.variables{end}.standard_name = imosParameters(varName, 'standard_name');
			sample_data{k}.variables{end}.long_name = imosParameters(varName, 'long_name');
			sample_data{k}.variables{end}.unit = imosParameters(varName, 'uom');
			sample_data{k}.variables{end}.reference_datum = imosParameters(varName, 'reference_datum');
			sample_data{k}.variables{end}.positive = imosParameters(varName, 'positive');
			sample_data{k}.variables{end}.valid_min = imosParameters(varName, 'valid_min');
			sample_data{k}.variables{end}.valid_max = imosParameters(varName, 'valid_max');
			sample_data{k}.variables{end}.FillValue_ = imosParameters(varName, 'fill_value');
			sample_data{k}.variables{end}.data = squeeze(BEAM(:, :, l));
			
%               fname = ['beam' jStr '.mat'];
%               beam = sample_data{k}.variables{end}.data;
%               save(fname,'beam');

            if ~isfield(sample_data{k}.variables{end}, 'comment')
				sample_data{k}.variables{end}.comment = Enu2BeamComment;
			else
				sample_data{k}.variables{end}.comment = [sample_data{k}.variables{end}.comment ' ' Enu2BeamComment];
			end
		end		
	end
	
	
    
    if ~isfield(sample_data{k}, 'history')
        sample_data{k}.history = sprintf('%s - %s', datestr(now_utc, readProperty('exportNetCDF.dateFormat')), Enu2BeamComment);
    else
        sample_data{k}.history = sprintf('%s\n%s - %s', sample_data{k}.history, datestr(now_utc, readProperty('exportNetCDF.dateFormat')), Enu2BeamComment);
    end
end
