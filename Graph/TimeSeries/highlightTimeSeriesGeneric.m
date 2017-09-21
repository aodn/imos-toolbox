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
narginchk(4, 4);

if ~isnumeric(region) || ~isvector(region) || length(region) ~= 4
  error('region must be a numeric vector of length 4');
end

if ~ishandle(data),     error('data must be a graphics handle'); end
if ~isstruct(variable), error('variable must be a struct');      end
if ~ischar(type),       error('type must be a string');          end

xdata = get(data(1), 'XData'); % data(1) retrieves the current graphic handles only, in case extra sample is selected
ydata = get(data(1), 'YData');

if iscell(xdata)
   xdata = cell2mat(xdata)'; 
   ydata = cell2mat(ydata)';
end

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
