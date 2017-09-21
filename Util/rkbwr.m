function [cmap] = rkbwr(maplength)
%RKBWR generates a 4 colors colormap from red to black to blue to white to red.
%
%
% input  :	[maplength]	[64]	- colormap length
%
% output :	cmap			- colormap RGB-value array
%
% Author: Guillaume Galibert <guillaume.galibert@utas.edu.au>
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
 
% orders of colors are
%  r  k  b  w  r
%
% set red points
r=[1; 0; 0; 1; 1];
 
% set green points
g=[0; 0; 0; 1; 0];
 
% set blue points
b=[0; 0; 1; 1; 0];
 
% get colormap length
if nargin==1 
  if length(maplength)==1
    if maplength<1
      maplength = 64;
    elseif maplength>256
      maplength = 256;
    elseif isinf(maplength)
      maplength = 64;
    elseif isnan(maplength)
      maplength = 64;
    end
  end
else
  maplength = 64;
end

% interpolate colormap
np = linspace(0, 1, maplength)';
i = linspace(0, 1, length(r))';

i(end) = (maplength + 1)/maplength; % we want to loop over the colormap so that maplength+1 has the same color as 1

% compose colormap
cmap = [interp1(i, r, np), interp1(i, g, np), interp1(i, b, np)];
