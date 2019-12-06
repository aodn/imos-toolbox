function dataIdx = getSelectedTransectGeneric( ...
  sample_data, var, ax, highlight, click )
%GETSELECTEDTRANSECTGENERIC Returns the indices of the currently selected 
% (highlighted) data on the given axis.
%
% This function is nearly identical to
% Graph/TimeSeries/getSelectedTimeSeriesGeneric.m.
%
% Inputs:
%   sample_data - Struct containing the data set.
%   var         - Variable in question (index into sample_data.variables).
%   ax          - Axis in question.
%   highlight   - Handle to the highlight object.
%   click       - Where the user clicked the mouse.
%   
%
% Outputs:
%   dataIdx     - Vector of indices into the data, defining the indices
%                 which are selected (and which were clicked on).
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
narginchk(5,5);

if ~isstruct(sample_data), error('sample_data must be a struct');        end
if ~isnumeric(var),        error('var must be numeric');                 end
if ~ishandle(ax),          error('ax must be a graphics handle');        end
if ~ishandle(highlight),   error('highlight must be a graphics handle'); end
if ~isnumeric(click),      error('click must be numeric');               end

dataIdx = [];

lat = getVar(sample_data.variables, 'LATITUDE');
lon = getVar(sample_data.variables, 'LONGITUDE');

lat = sample_data.variables{lat};
lon = sample_data.variables{lon};

highlightX = get(highlight, 'XData');
highlightY = get(highlight, 'YData');

% figure out if the click was anywhere near the highlight 
% (within 1% of the current visible range on x and y)
xError = get(ax, 'XLim');
xError = abs(xError(1) - xError(2));
yError = get(ax, 'YLim');
yError = abs(yError(1) - yError(2));

% was click near highlight?
if any(abs(click(1)-highlightX) <= xError*0.01)...
&& any(abs(click(2)-highlightY) <= yError*0.01)

  % find the indices of the selected points
  highlightX = find(ismember(lat.data, highlightX));
  highlightY = find(ismember(lon.data, highlightY));
  
  dataIdx = intersect(highlightX, highlightY);
  
end
