function highlight = highlightXvYGeneric( ...
  region, data, variable, type )
%HIGHLIGHTXVYGENERIC Highlights the given region on the given data 
% axes, using a line overlaid on the points in the region.
%
% This function delegates to Graph/TimeSeries/highlightTimeSeriesGeneric.m.
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
highlight = highlightTimeSeriesGeneric(region, data, variable, type);
