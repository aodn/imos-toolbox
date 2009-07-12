function highlight = highlightTimeSeriesGeneric( region, data )
%HIGHLIGHTTIMESERIESGENERIC Highlights the given region on the given data 
% axes, using a line overlaid on the on the points in the region.
% 
% Inputs:
%   region    - a vector of length 4, containing the selected data region. 
%               Must be in the format: [lx ly hx hy]
%   data      - A handle, or vector of handles, to the graphics object(s) 
%               displaying the data (e.g. line, scatter). Must contain 
%               'XData' and 'YData' properties.
%
% Outputs:
%   highlight - Handle to a line object which overlays the highlighted
%               data. If no data points lie within the highlight region, an
%               empty matrix is returned.
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

% these will throw errors if the handle doesn't have XData/YData properties
xdata = get(data, 'XData');
ydata = get(data, 'YData');

% if multiple handles were passed in, merge the data sets by combining x
% and y into a Nx2 matrix, and using union to merge/sort the rows
if iscell(xdata)
  
  % u stands for union
  u = [xdata{1}' ydata{1}'];
  for k = 2:length(xdata)
    
    u = union(u, [xdata{k}' ydata{k}'], 'rows'); 
  end
  
  xdata = u(:,1);
  ydata = u(:,2);
end

% figure out indices of all data points within the range
xidx  = find(xdata >= region(1) & xdata <= region(3));
yidx  = find(ydata >= region(2) & ydata <= region(4));

% figure out indices of all the points to be highlighted
idx = intersect(xidx,yidx);

% return nothing if no points to plot
if isempty(idx), highlight = [];
  
% create the highlight
else

  highlight = line(xdata(idx),ydata(idx),...
    'Parent',          gca,...
    'LineStyle',       'none',...
    'Marker',          'o',...
    'MarkerEdgeColor', 'white', ...
    'MarkerFaceColor', 'white');
end
