function [h, labels] = graphDepthProfileGeneric( ax, sample_data, var, color )
%GRAPHDEPTHPROFILEGENERIC Plots the given variable (x axis) against depth 
% (y axis).
%
% Inputs:
%   ax          - Parent axis.
%   sample_data - The data set.
%   var         - The variable to plot.
%   color       - The color to be used to plot the variable.
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
narginchk(4,4);

if ~ishandle(ax),          error('ax must be a graphics handle'); end
if ~isstruct(sample_data), error('sample_data must be a struct'); end
if ~isnumeric(var),        error('var must be a numeric');        end

% get the toolbox execution mode
mode = readProperty('toolbox.mode');

% look for a depth variable
iDepthVar = getVar(sample_data.variables, 'DEPTH');
if iDepthVar ~= 0
    depth = sample_data.variables{iDepthVar};
else
    % look for a depth dimension
    iDepthDim = getVar(sample_data.dimensions, 'DEPTH');
    if iDepthDim ~= 0
        depth = sample_data.dimensions{iDepthDim};
    else
        error('dataset contains no depth data');
    end
end

var  = sample_data.variables{var};

switch mode
    case 'profile'
        h            = line(var.data(:, 1), depth.data(:, 1), 'Parent', ax, 'LineStyle', '-', 'Color', color); % downcast
        if size(var.data, 2) > 1
            h(end+1) = line(var.data(:, 2), depth.data(:, 2), 'Parent', ax, 'LineStyle', '--', 'Color', color); % upcast
        end
        
    case 'timeSeries'
        if size(var.data, 2) > 1
            % ADCP data, we look for vertical dimension
            iVertDim = var.dimensions(2);
            depthAdcpData = repmat(depth.data, 1, length(sample_data.dimensions{iVertDim}.data)) - ...
                repmat(sample_data.dimensions{iVertDim}.data', length(depth.data), 1);
            h        = line(var.data(:), depthAdcpData(:), 'Parent', ax, 'LineStyle', '-', 'Color', color);
        else
            h        = line(var.data, depth.data, 'Parent', ax, 'LineStyle', '-', 'Color', color);
        end
        
end
set(ax, 'Tag', 'axis1D');

% for global/regional range display
mWh = findobj('Tag', 'mainWindow');
climatologyRange = get(mWh, 'UserData');

iSample = find(arrayfun(@(x) strcmp(x.dataSet, sample_data.toolbox_input_file), climatologyRange));

if ~isempty(climatologyRange)
    if isfield(climatologyRange, ['rangeMin' var.name])
        xLim = get(ax, 'XLim');
        line(climatologyRange(iSample).(['rangeMin' var.name]), [depth.data(1); depth.data(end)], 'Parent', ax, 'Color', 'r');
        line(climatologyRange(iSample).(['rangeMax' var.name]), [depth.data(1); depth.data(end)], 'Parent', ax, 'Color', 'r');
        set(ax, 'XLim', xLim);
    end
end

% set background to be transparent (same as figure background)
set(ax, 'Color', 'none')

labels = {var.name, 'DEPTH'};

% assume that the depth data is ascending - we want to display 
% it descending though, so reverse the axis orientation
set(ax, 'YDir', 'reverse');
