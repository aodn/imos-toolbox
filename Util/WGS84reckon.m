function [newlat, newlon] = WGS84reckon(lat, lon, rng, az)
%WGS84RECKON Computes coordinates on a circle for a given azimuth and
%distance.
%
% Reference
% ---------
% J. P. Snyder, "Map Projections - A Working Manual,"  US Geological Survey
% Professional Paper 1395, US Government Printing Office, Washington, DC,
% 1987, pp. 29-32.
%
% Inputs:
%   lat,lon         - original coordinates in radians.
%   az              - azimuth in radian.
%   rng             - distance in metre.
%
% Outputs:
%   newlat,newlon   - computed coordinates in radians.
%
% Author:       Arnaud Gaillot <arnaud.gaillot@ifremer.fr> (based on reckon.m)
% Contributor:  Guillaume Galibert <guillaume.galibert@utas.edu.au>
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

% WGS84 semi major axis in metre :
a = 6378137;

% Convertion distance to angle on a sphere (in radians).
rng = rng / a;

epsm = 1.7453*10^(-8); % angular precision
% We check azimuths are correct at the poles.
epsilon = 10*epsm;               % tolerance
az(lat >= pi/2-epsilon) = pi;    % North pole
az(lat <= epsilon-pi/2) = 0;     % South pole

if size(rng, 2) > 1 % Column vector
    rng = rng';
end

if size(az, 1) > 1 % Row vector
    az = az';
end

newlat = asin( cos(rng)*(sin(lat)*ones(1, length(az))) +...
    sin(rng)*(cos(az).*cos(lat)) );

newlon = lon + atan2( sin(rng)*sin(az),...
    cos(rng)*(cos(lat)*ones(1, length(az))) ...
    - sin(rng)*(cos(az)*sin(lat)) );
