function [h, labels] = graphTransectGeneric( ax, sample_data, var )
%GRAPHTRANSECTGENERIC Plots the given variable as 2d transect data. Assumes
% that the sample data struct contains latitude and longitude variable data.
%
% Inputs:
%   ax          - Parent axis.
%   sample_data - The data set.
%   var         - The variable to plot.
%
% Outputs:
%   h           - Handle(s) to the patch(es) which was/were plotted.
%   labels      - Cell array containing x/y labels to use.
%
% Author: Paul McCarthy <paul.mccarthy@csiro.au>
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
narginchk(3,3);

if ~ishandle(ax),          error('ax must be a graphics handle'); end
if ~isstruct(sample_data), error('sample_data must be a struct'); end
if ~isnumeric(var),        error('var must be a numeric');        end

lat = getVar(sample_data.variables, 'LATITUDE');
lon = getVar(sample_data.variables, 'LONGITUDE');

lat = sample_data.variables{lat};
lon = sample_data.variables{lon};
var = sample_data.variables{var};

h = patch([lat.data' nan], [lon.data' nan], 0);

set(h, 'CData',     [var.data' nan]);
set(h, 'EdgeColor', 'flat');
set(h, 'FaceColor', 'none');

% thicker line looks nicer
set(h, 'LineWidth', 3);

cb = colorbar();

cbLabel = imosParameters(var.name, 'uom');
cbLabel = [var.name ' (' cbLabel ')'];
if length(cbLabel) > 20, cbLabel = [cbLabel(1:17) '...']; end
set(get(cb, 'YLabel'), 'String', cbLabel, 'Interpreter', 'none');

% set background to be grey
set(ax, 'Color', [0.85 0.85 0.85])

labels = {'LATITUDE', 'LONGITUDE'};
