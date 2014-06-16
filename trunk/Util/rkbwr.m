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
% Copyright (c) 2009, eMarine Information Infrastructure (eMII) and Integrated 
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
%     * Neither the name of the eMII/IMOS nor the names of its contributors 
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
