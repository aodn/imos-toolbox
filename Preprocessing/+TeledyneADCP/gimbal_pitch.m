function gpitch = gimbal_pitch(pitch, roll, tilt_bit)
%function adjustpitch(pitch, roll, tilt_bit)
%
% Compute the Gimbal Pitch from internal pitch
% and roll sensors in a RDI ADCP.
%
% Inputs:
%
% pitch - The internal pitch angles in degrees.
% roll - The internal roll angles in degrees.
% tilt_bit - The internal tilt sensor switch.
%
% Outputs:
%
% gpitch - The adjusted pitch in degrees, as a gimbal.
%
% Example:
% rolls = [5:5:360];
% h = 0;
% x = TeledyneADCP.gimbal_pitch(0,rolls,true);
% y = TeledyneADCP.gimbal_pitch(180,rolls,true);
% assert(isequal(x,y))
% x = TeledyneADCP.gimbal_pitch(270,rolls,true);
% assert(isnan(x(rolls==90)))
% assert(isnan(x(rolls==270)))
% 
% %bounded
% x = TeledyneADCP.gimbal_pitch(rolls,0,true);
% assert(isequal([-90,90],[min(x),max(x)]))
%
% %invariant 
% x = TeledyneADCP.gimbal_pitch(45,-45,1);
% y = TeledyneADCP.gimbal_pitch(45,45,1);
% assert(x==y)
%
%
narginchk(3, 3)

if ~tilt_bit
    %Page 18, 4th paragraph.
    warnmsg('Tilt bit is not set. Adjusted pitch is now zero.')
    gpitch = zeros(size(pitch));
    return
end

gpitch = atand(tand(pitch) .* cosd(roll));
end
