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
% Copyright (c) 2016, Australian Ocean Data Network (AODN) and Integrated 
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
%     * Neither the name of the AODN/IMOS nor the names of its contributors 
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
