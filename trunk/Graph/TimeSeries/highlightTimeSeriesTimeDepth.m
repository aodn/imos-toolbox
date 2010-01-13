function highlight = highlightTimeSeriesTimeDepth( ...
  region, data, variable, type )
%HIGHLIGHTTIMESERIESTIMEDEPTH Highlights the given region on the given
% time/depth plot.
%
% Highlights the given region on a time/depth plot.
%
% Inputs:
%   region    - a vector of length 4, containing the selected data region. 
%               Must be in the format: [lx ly hx hy]
%   data      - A handle, or vector of handles, to the graphics object(s) 
%               displaying the data (e.g. line, scatter). 
%   variable  - The variable displayed on the axes.
%   type      - The highlight type.
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
error(nargchk(4,4,nargin));

if ~isnumeric(region) || ~isvector(region) || length(region) ~= 4
  error('region must be a numeric vector of length 4');
end

if ~ishandle(data),     error('data must be a graphics handle'); end
if ~isstruct(variable), error('variable must be a struct');      end
if ~ischar(type),       error('type must be a string');          end
  
xdata = get(data, 'XData');
ydata = get(data, 'YData');

% figure out indices of all data points within the range
x = find((xdata >= region(1)) & (xdata <= region(3)));
y = find((ydata >= region(2)) & (ydata <= region(4)));

% on right click, only highlight unflagged points
if strcmp(type, 'alt')
  
  % see if any points in the region have been flagged
  flags = variable.flags(x, y);
  flags = flags == 0;
  if ~any(flags), return; end
  
  % find the indices of those flagged points
  xidx = mod( find(flags) , length(x));
  yidx = ceil(find(flags) / length(x));
  
  xidx(xidx == 0) = length(x);
  
  xidx = xidx + x(1) - 1;
  yidx = yidx + y(1) - 1;
  
else

  % create points for every point in the region
  k = 1:(length(x)*length(y));

  xidx = mod(k, length(x));
  xidx(xidx == 0) = length(x);
  yidx = mod(ceil(k / length(x)), length(y));
  yidx(yidx == 0) = length(y);
  xidx = x(xidx);
  
  yidx = y(yidx);
  
end

if isempty(x) || isempty(y), highlight = [];
  
else

  highlight = line(xdata(xidx),ydata(yidx),...
    'Parent',          gca,...
    'LineStyle',       'none',...
    'Marker',          'o',...
    'MarkerEdgeColor', 'white', ...
    'MarkerFaceColor', 'white',...
    'MarkerSize',      3);
end
