function nonMappedHeightAboveSensorBeam = adcp_adjusted_distances_rdi4beam(roll, pitch, pitchSign, distAlongBeams, beamAngle, number_of_beams)
% function nonMappedHeightAboveSensorBeam = adcp_adjusted_distances_rdi4beam(roll, pitch, pitchSign, distAlongBeams, beamAngle, number_of_beams)
%
% Adjusts height above sensor for each beam in adcpBinMapping.m
%   Can read 4 beam RDI instruments.
%   Uses the beam angle and the roll/pitch of the instrument. 
%   No adjustement when tilt is zero, 
%   nonMappedHeightAboveSensorBeam will be the same than distAlongBeams.
%   Deals with up and down facing ADCPs
%
% Inputs:
%
%   roll            - 1D single precision array (Ntime), the internal roll angles in degrees 
%   pitch           - 1D single precision array (Ntime), the internal pitch angles in degrees
%   pitchSign       - integer (-1 or 1), pitch sign based on the ADCP's orientation
%   distAlongBeams  - 1D array (Nbins), the internal distance along beam for each bin
%   beamAngle       - scalar, beam angle from the instrument
%   number_of_beams - interger, number of beams on the ADCP
%
% Outputs:
%
%   nonMappedHeightAboveSensorBeam - 3D single precision array (Ntime, Nbins, Nbeams),
%                                    tilt adjusted height above sensor for
%                                    each of the 4 beams
% 
% Example: 
%
% %testing for up and down facing ADCPs - no change for beam 1 and 2 (roll)
% %changes only for beam 3 and 4 (pitch)
%
% roll_ini = [-180:10:180]';
% pitch_ini = [-180:10:180]';
% pitchSign_up = 1;
% pitchSign_down = -1;
% distAlongBeams = [20:20:600];
% beamAngle = 0.3;
% number_of_beams = 4;
%
% x_up = TeledyneADCP.adcp_adjusted_distances_rdi4beam(roll_ini,pitch_ini,pitchSign_up,distAlongBeams,beamAngle,number_of_beams);
% x_down = TeledyneADCP.adcp_adjusted_distances_rdi4beam(roll_ini,pitch_ini,pitchSign_down,distAlongBeams,beamAngle,number_of_beams);
%
% assert(isequal(x_up(:,:,1), x_down(:,:,1)));
% assert(isequal(x_up(:,:,2), x_down(:,:,2)));
% assert(~isequal(x_up(:,:,3), x_down(:,:,3)));
% assert(~isequal(x_up(:,:,4), x_down(:,:,4)));
%
% idx0 = find(roll_ini == 0);
% for i=1:number_of_beams; assert(isequal(x_up(idx0,:,i), distAlongBeams)); assert(isequal(x_down(idx0,:,i), distAlongBeams)); end
% for i=1:number_of_beams; assert(~isequal(x_up(~idx0,:,i), distAlongBeams)); assert(~isequal(x_down(~idx0,:,i), distAlongBeams)); end
%
%

narginchk(6,6)

nmh=1;
if pitchSign < 0
    % adjust nonMappedHeightAboveSensorBeam sign when downfacing
    nmh = -1;
    % adjust roll when downfacing
    roll = roll-pi;
end

CP = cos(pitchSign * pitch);
CR = cos(roll);

% set to single precision
nonMappedHeightAboveSensorBeam = nan(length(pitch), length(distAlongBeams), number_of_beams, 'single'); 

nonMappedHeightAboveSensorBeam(:,:,1) = nmh * (CP .* (cos(beamAngle + roll) / cos(beamAngle) .* distAlongBeams));
nonMappedHeightAboveSensorBeam(:,:,2) = nmh * (CP .* (cos(beamAngle - roll) / cos(beamAngle) .* distAlongBeams));
nonMappedHeightAboveSensorBeam(:,:,3) = nmh * (CR .* (cos(beamAngle - pitchSign * pitch) / cos(beamAngle) .* distAlongBeams));
nonMappedHeightAboveSensorBeam(:,:,4) = nmh * (CR .* (cos(beamAngle + pitchSign * pitch) / cos(beamAngle) .* distAlongBeams));

end

