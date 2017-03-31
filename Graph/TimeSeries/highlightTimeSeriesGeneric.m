function highlight = highlightTimeSeriesGeneric( region, data, variable, type )
%HIGHLIGHTTIMESERIESGENERIC Highlights the given region on the given data 
% axes, using a line overlaid on the on the points in the region.
% 
% Inputs:
%   region    - a vector of length 4, containing the selected data region. 
%               Must be in the format: [lx ly hx hy]
%   data      - A handle, or vector of handles, to the graphics object(s) 
%               displaying the data (e.g. line, scatter). Must contain 
%               'XData' and 'YData' properties.
%   variable  - The variable displayed on the axes.
%   type      - The highlight type.
%
% Outputs:
%   highlight - Handle to a line object which overlays the highlighted
%               data. If no data points lie within the highlight region, 
%               an empty matrix is returned.
%
% Author:       Paul McCarthy <paul.mccarthy@csiro.au>
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
%
narginchk(4, 4);

if ~isnumeric(region) || ~isvector(region) || length(region) ~= 4
  error('region must be a numeric vector of length 4');
end

if ~ishandle(data),     error('data must be a graphics handle'); end
if ~isstruct(variable), error('variable must be a struct');      end
if ~ischar(type),       error('type must be a string');          end

xdata = get(data, 'XData');
ydata = get(data, 'YData');

% on right click highlight, only highlight 
% unflagged data points in the region
if strcmp(type, 'alt')
  
  f = variable.flags;
  f = f == 0;
  
  xdata = xdata(f);
  ydata = ydata(f);
end

% figure out indices of all data points within the range
xidx  = (xdata >= region(1) & xdata <= region(3));
yidx  = (ydata >= region(2) & ydata <= region(4));

% figure out indices of all the points to be highlighted
idx = xidx & yidx;

if ~any(idx)
    % return nothing if no points to plot
    highlight = [];
else
    % create the highlight
    highlight = line(xdata(idx),ydata(idx), ...
        'UserData',        idx, ...
        'Parent',          gca, ...
        'LineStyle',       'none', ...
        'Marker',          'o', ...
        'MarkerEdgeColor', 'white', ...
        'MarkerFaceColor', 'white');
end
