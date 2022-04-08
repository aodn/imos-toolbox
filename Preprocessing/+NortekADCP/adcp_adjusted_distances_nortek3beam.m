function nonMappedHeightAboveSensorBeam = adcp_adjusted_distances_nortek3beam(roll, pitch, distAlongBeams, beamAngle, number_of_beams)
% function nonMappedHeightAboveSensorBeam = adcp_adjusted_distances_nortek3beam(roll, pitch, distAlongBeams, beamAngle, number_of_beams)
%
% Adjusts height above sensor for each beam in adcpBinMapping.m
%   Can read 3 beam Nortek instruments.
%   Uses the beam angle and the roll/pitch of the instrument. 
%   No adjustement when tilt is zero, 
%   nonMappedHeightAboveSensorBeam will be the same than distAlongBeams.
%
% Inputs:
%
%   roll            - 1D single precision array (Ntime), the internal roll angles in degrees 
%   pitch           - 1D single precision array (Ntime), the internal pitch angles in degrees
%   distAlongBeams  - 1D array (Nbins), the internal distance along beam for each bin
%   beamAngle       - scalar, beam angle from the instrument
%   number_of_beams - interger, number of beams on the ADCP
%
% Outputs:
%
%   nonMappedHeightAboveSensorBeam - 3D single precision array (Ntime, Nbins, Nbeams),
%                                    tilt adjusted height above sensor for
%                                    each of the 3 beams
%
% Example: 
% 
% roll_ini = [-180:10:180]';
% pitch_ini = [-180:10:180]';
% distAlongBeams = [20:20:600];
% beamAngle = 0.3;
% number_of_beams = 3;
%
% x = NortekADCP.adcp_adjusted_distances_nortek3beam(roll_ini,pitch_ini,distAlongBeams,beamAngle,number_of_beams);
%
% idx0 = find(roll_ini == 0);
% for i=1:number_of_beams; assert(isequal(x(idx0,:,i), distAlongBeams)); assert(~isequal(x(~idx0,:,i), distAlongBeams)); end
%
%

narginchk(5,5)

number_of_beams = 3;
nBins = length(distAlongBeams);

% set to single precision
nonMappedHeightAboveSensorBeam = nan(length(pitch), length(distAlongBeams), number_of_beams, 'single');

nonMappedHeightAboveSensorBeam(:,:,1) = (cos(beamAngle - pitch) / cos(beamAngle)) * distAlongBeams;
nonMappedHeightAboveSensorBeam(:,:,1) = repmat(cos(roll), 1, nBins) .* nonMappedHeightAboveSensorBeam(:,:,1);

beamAngleX = atan(tan(beamAngle) * cos(60 * pi / 180)); % beams 2 and 3 angle projected on the X axis
beamAngleY = atan(tan(beamAngle) * cos(30 * pi / 180)); % beams 2 and 3 angle projected on the Y axis

nonMappedHeightAboveSensorBeam(:,:,2) = (cos(beamAngleX + pitch) / cos(beamAngleX)) * distAlongBeams;
nonMappedHeightAboveSensorBeam(:,:,2) = repmat(cos(beamAngleY + roll) / cos(beamAngleY), 1, nBins) .* nonMappedHeightAboveSensorBeam(:,:,2);

nonMappedHeightAboveSensorBeam(:,:,3) = (cos(beamAngleX + pitch) / cos(beamAngleX)) * distAlongBeams;
nonMappedHeightAboveSensorBeam(:,:,3) = repmat(cos(beamAngleY - roll) / cos(beamAngleY), 1, nBins) .* nonMappedHeightAboveSensorBeam(:,:,3);

end

