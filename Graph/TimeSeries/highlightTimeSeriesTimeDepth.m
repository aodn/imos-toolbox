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

if any(size(variable.data) == 1)
    % we actually deal with a single point in depth instrument (ex.:
    % current metre)
    highlight = highlightTimeSeriesGeneric(region, data, variable, type);
    return;
end
  
xdata = get(data(1), 'XData'); % data(1) retrieves the current graphic handles only, in case extra sample is selected
ydata = get(data(1), 'YData');

Xdata = repmat(xdata, [1, size(ydata)]);
Ydata = repmat(ydata', [size(xdata), 1]);
clear xdata ydata;

if strcmp(type, 'alt') % right click
    % figure out indices of all data points within the X range but outside the Y range
    X = (Xdata >= region(1)) & (Xdata <= region(3));
    Y = (Ydata <  region(2)) | (Ydata >  region(4));
else
    % figure out indices of all data points within the X and Y range
    X = (Xdata >= region(1)) & (Xdata <= region(3));
    Y = (Ydata >= region(2)) & (Ydata <= region(4));
end
idx = X & Y;
clear X Y;

if ~any(any(idx))
    highlight = [];
else
    highlight = line(Xdata(idx), Ydata(idx), ...
        'UserData',        idx, ...
        'Parent',          gca, ...
        'LineStyle',       'none', ...
        'Marker',          'o', ...
        'MarkerEdgeColor', 'white', ...
        'MarkerFaceColor', 'white', ...
        'MarkerSize',      3);
end
