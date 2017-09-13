function [h, labels] = graphXvYGeneric( ax, sample_data, vars, color )
%GRAPHXVYGENERIC Plots the given variable (x axis) against another 
% (y axis).
%
% Inputs:
%   ax          - Parent axis.
%   sample_data - The data set.
%   vars        - The variables to plot.
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
if ~isnumeric(vars),       error('var must be a numeric');        end

xdata = sample_data.variables{vars(1)}.data(:);
ydata = sample_data.variables{vars(2)}.data(:);

h = line(xdata, ydata, 'Color', color);
set(ax, 'Tag', 'axis1D');

% for global/regional range display
mWh = findobj('Tag', 'mainWindow');
climatologyRange = get(mWh, 'UserData');

iSample = find(arrayfun(@(x) strcmp(x.dataSet, sample_data.toolbox_input_file), climatologyRange));

if ~isempty(climatologyRange)
    if isfield(climatologyRange, ['rangeMin' sample_data.variables{vars(1)}.name])
        xLim = get(ax, 'XLim');
        line(climatologyRange(iSample).(['rangeMin' sample_data.variables{vars(1)}.name]), [sample_data.variables{vars(2)}.data(1); sample_data.variables{vars(2)}.data(end)], 'Parent', ax, 'Color', 'r');
        line(climatologyRange(iSample).(['rangeMax' sample_data.variables{vars(1)}.name]), [sample_data.variables{vars(2)}.data(1); sample_data.variables{vars(2)}.data(end)], 'Parent', ax, 'Color', 'r');
        set(ax, 'XLim', xLim);
    end
    if isfield(climatologyRange, ['rangeMin' sample_data.variables{vars(2)}.name])
        yLim = get(ax, 'YLim');
        line([sample_data.variables{vars(1)}.data(1); sample_data.variables{vars(1)}.data(end)], climatologyRange(iSample).(['rangeMin' sample_data.variables{vars(2)}.name]), 'Parent', ax, 'Color', 'r');
        line([sample_data.variables{vars(1)}.data(1); sample_data.variables{vars(1)}.data(end)], climatologyRange(iSample).(['rangeMax' sample_data.variables{vars(2)}.name]), 'Parent', ax, 'Color', 'r');
        set(ax, 'YLim', yLim);
    end
end

% set background to be grey
set(ax, 'Color', [0.85 0.85 0.85])

labels = {sample_data.variables{vars(1)}.name, sample_data.variables{vars(2)}.name};