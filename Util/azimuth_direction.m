function dir = azimuth_direction(u,v)
%function dir = azimuth_direction(u,v)
%
% Compute Azimuth direction in degrees,
% i.e. , clockwise from North [0,360[.
%
%
% Inputs:
%
% u - the eastward component of velocity.
% v - the northward component of velocity.
%
% Outputs:
%
% dir - the direction in degrees.
%
% Examples:
%
% cart_angles =   [ 0,30,45,80,90,110,135,170,180,190,225,260,270,280,315,350,360,  0];
% azimuths =      [90,60,45,10, 0,340,315,280,270,260,225,190,180,170,135,100, 90, 90];
% [u,v] = pol2cart(deg2rad(cart_angles),cart_angles*0+1);
% result = azimuth_direction(u,v);
% assert(all(result==azimuths));
%
dir=wrapTo360(360+90-atan2d(v,u));
dir(dir==360)=0;
end
