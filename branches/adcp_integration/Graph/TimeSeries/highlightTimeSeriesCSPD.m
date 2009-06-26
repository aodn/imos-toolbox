function highlight = highlightTimeSeriesCSPD( region, data )
%HIGHLIGHTTIMESERIESCSPD Highlights the given region on the given CSPD (sea
% water speed) plot.
%
% Highlights the given region on a CPSD plot, using a transparent patch.
%
% Inputs:
%   region    - a vector of length 4, containing the selected data region. 
%               Must be in the format: [lx ly hx hy]
%   data      - A handle, or vector of handles, to the graphics object(s) 
%               displaying the data (e.g. line, scatter). 
%
% Outputs:
%   highlight - handle to the patch highlight.
%
% Author: Paul McCarthy <paul.mccarthy@csiro.au>
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
error(nargchk(2,2,nargin));

if ~isnumeric(region) || ~isvector(region) || length(region) ~= 4
  error('region must be a numeric vector of length 4');
end

if ~ishandle(data), error('data must be a graphics handle'); end
  
% get the vertices of the rectangular region
x = [region(1) region(1) region(3) region(3)];
y = [region(2) region(4) region(4) region(2)];

% create the patch
highlight = patch(x, y, 'white', 'Parent',gca, 'FaceAlpha', 0.6);
