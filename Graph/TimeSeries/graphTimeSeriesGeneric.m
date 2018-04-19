function [h, labels] = graphTimeSeriesGeneric( ax, sample_data, var, color, xTickProp )
%GRAPHTIMESERIESGENERIC Plots the given variable as normal, single dimensional, 
% time series data. If the data are multi-dimensional, multiple lines will be
% plotted and returned.
%
% Inputs:
%   ax          - Parent axis.
%   sample_data - The data set.
%   var         - The variable to plot.
%   color       - The color to be used to plot the variable.
%   xTickProp   - Not used here.
%
% Outputs:
%   h           - Handle(s) to the line(s)  which was/were plotted.
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
if ~isvector(color),       error('color must be a vector');       end

iTimeDim = getVar(sample_data.dimensions, 'TIME');

time = sample_data.dimensions{iTimeDim};
var  = sample_data.variables {var};

if ischar(var.data), var.data = str2num(var.data); end % we assume data is an array of one single character

h    = line(time.data, var.data, 'Parent', ax, 'Color', color);
set(ax, 'Tag', 'axis1D');

% for global/regional range and in/out water display
mWh = findobj('Tag', 'mainWindow');
qcParam = get(mWh, 'UserData');

iSample = find(arrayfun(@(x) strcmp(x.dataSet, sample_data.toolbox_input_file), qcParam));

if ~isempty(qcParam)
    if isfield(qcParam, ['rangeMin' var.name])
        hold(ax, 'on');
        if (length(qcParam(iSample).(['rangeMin' var.name])) == 2)
            timeToPlot = [time.data(1); time.data(end)];
        else
            timeToPlot = time.data;
        end
        
        if isfield(qcParam, ['range' var.name])
            line(timeToPlot, qcParam(iSample).(['range' var.name]), 'Parent', ax, 'Color', 'k');
        end
        line([timeToPlot; NaN; timeToPlot], ...
            [qcParam(iSample).(['rangeMin' var.name]); NaN; qcParam(iSample).(['rangeMax' var.name])], ...
            'Parent', ax, 'Color', 'r');
    end
    
    if isfield(qcParam, 'inWater')
        hold(ax, 'on');
        yLim = get(ax, 'YLim');
        line([qcParam(iSample).inWater, qcParam(iSample).inWater, NaN, qcParam(iSample).outWater, qcParam(iSample).outWater], ...
            [yLim, NaN, yLim], ...
            'Parent', ax, 'Color', 'r');
    end
end

% set background to be transparent (same as background color)
set(ax, 'Color', 'none')

if strncmp(var.name, 'DEPTH', 4) || strncmp(var.name, 'PRES', 4) || strncmp(var.name, 'PRES_REL', 8)
    set(ax, 'YDir', 'reverse');
end

labels = {time.name, var.name};
