function [h labels] = graphTimeSeriesTimeFrequency( ax, sample_data, var, color, xTickProp )
%GRAPHTIMESERIESTIMEFREQUENCY Plots the given data using pcolor.
%
% This function is used for plotting time/frequency data. The pcolor function 
% is  used to display a 2-D color plot, with time on the X axis and frequency 
% on the Y axis, and the data indicated indicated by the colour.
%
% Inputs:
%   ax          - Parent axis.
%   sample_data - The data set.
%   var         - The variable to plot.
%   color       - Not used here.
%   xTickProp   - XTick and XTickLabel properties.
%
% Outputs:
%   h           - Handle to the surface which was plotted.
%   labels      - Cell array containing x/y labels to use.
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
narginchk(5, 5);

if ~ishandle(ax),          error('ax must be a graphics handle'); end
if ~isstruct(sample_data), error('sample_data must be a struct'); end
if ~isnumeric(var),        error('var must be a numeric');        end

iTimeDim = getVar(sample_data.dimensions, 'TIME');
freq = sample_data.variables{var}.dimensions(2);

time = sample_data.dimensions{iTimeDim};
freq = sample_data.dimensions{freq};
var  = sample_data.variables {var};

xPcolor = time.data;
yPcolor = freq.data;

% we actually want each square of the surface plot to be centred on its
% coordinates
% xPcolor = [time.data(1:end-1) - diff(time.data)/2; time.data(end) - (time.data(end)-time.data(end-1))/2];
% yPcolor = [freq.data(1:end-1) - diff(freq.data)/2; freq.data(end) - (freq.data(end)-freq.data(end-1))/2];

posWithoutCb = get(ax, 'Position');

h = pcolor(ax, double(xPcolor), double(yPcolor), double(var.data'));
set(h, 'FaceColor', 'flat', 'EdgeColor', 'none');
cb = colorbar('peer', ax);

% reset position to what it was without the colorbar so that it aligns with
% 1D datasets
set(ax, 'Position', posWithoutCb);

% Attach the context menu to colorbar
hMenu = setTimeSerieColorbarContextMenu(var);
set(cb,'uicontextmenu',hMenu);

% Let's redefine properties after pcolor to make sure grid lines appear
% above color data and XTick and XTickLabel haven't changed
set(ax, 'XTick',        xTickProp.ticks, ...
        'XTickLabel',   xTickProp.labels, ...
        'XGrid',        'on', ...
        'YGrid',        'on', ...
        'Layer',        'top', ...
        'Tag',          'axis2D');

cbLabel = imosParameters(var.name, 'uom');
cbLabel = [var.name ' (' cbLabel ')'];
if length(cbLabel) > 20, cbLabel = [cbLabel(1:17) '...']; end
set(get(cb, 'YLabel'), 'String', cbLabel, 'Interpreter', 'none');

% set background to be light grey (colorbar can include white color)
set(ax, 'Color', [0.85 0.85 0.85])

labels = {time.name, freq.name};

end