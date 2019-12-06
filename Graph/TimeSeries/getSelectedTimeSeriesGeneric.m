function dataIdx = getSelectedTimeSeriesGeneric( sample_data, var, ax, highlight )
%GETSELECTEDTIMESERIESGENERIC Returns the indices of the currently selected 
% (highlighted) data on the given axis.
%
% Inputs:
%   sample_data - Struct containing the data set.
%   var         - Variable in question (index into sample_data.variables).
%   ax          - Axis in question.
%   highlight   - Handle to the highlight object.
%   
%
% Outputs:
%   dataIdx     - Vector of indices into the data, defining the indices
%                 which are selected (and which were clicked on).
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

if ~isstruct(sample_data), error('sample_data must be a struct');        end
if ~isnumeric(var),        error('var must be numeric');                 end
if ~ishandle(ax),          error('ax must be a graphics handle');        end
if ~ishandle(highlight),   error('highlight must be a graphics handle'); end

dataIdx = get(highlight, 'UserData');