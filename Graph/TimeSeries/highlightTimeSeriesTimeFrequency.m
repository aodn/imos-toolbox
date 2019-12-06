function highlight = highlightTimeSeriesTimeFrequency( ...
  region, data, variable, type )
%HIGHLIGHTTIMESERIESTIMEFREQUENCY Highlights the given region on the given
% time/frequency plot.
%
% Highlights the given region on a time/frequency plot. This function just 
% delegates to highlightTimeSeriesTimeDepth.
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
highlight = highlightTimeSeriesTimeDepth(region, data, variable, type);
