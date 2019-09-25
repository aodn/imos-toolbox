function [cmap] = r_b(maplength)
%R_B generates a 3 colors colormap from blue to red with white in the
%centre.
%
% colormap m-file written by ColEdit
% version 1.1 on 13-Nov-2000
%
% input  :	[maplength]	[64]	- colormap length
%
% output :	cmap			- colormap RGB-value array
%
% Author: Brad Morris <bmorris@unsw.edu.au>
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
 
% set red points
r = [ [];...
    [0 0];...
    [0.375 0.5];...
    [0.48 0.97619];...
    [0.52 1];...
    [0.625 1];...
    [0.875 1];...
    [1 0.5];...
    [] ];
 
% set green points
g = [ [];...
    [0 0];...
    [0.125 0];...
    [0.375 1];...
    [0.45897 1];...
    [0.48 1];...
    [0.52 1];...
    [0.875 0];...
    [1 0];...
    [] ];
 
% set blue points
b = [ [];...
    [0 0.5];...
    [0.125 1];...
    [0.375 1];...
    [0.46923 0.90984];...
    [0.48 1];...
    [0.52 1];...
    [0.53333 0.85714];...
    [0.625 0];...
    [1 0];...
    [] ];
% ColEditInfoEnd
 
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
np = linspace(0,1,maplength);
rr = interp1(r(:,1),r(:,2),np,'linear');
gg = interp1(g(:,1),g(:,2),np,'linear');
bb = interp1(b(:,1),b(:,2),np,'linear');
 
% compose colormap
cmap = [rr(:),gg(:),bb(:)];
