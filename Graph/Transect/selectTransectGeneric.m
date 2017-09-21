function selectTransectGeneric( selectCallback, clickCallback )
%SELECTTRANSECTGENERIC Adds callbacks to the current figure, allowing the 
% user to interact with data in the current transect axis using the mouse.
%
% This function delegates to Graph/TimeSeries/selectTimeSeriesGeneric.m.
%
% Inputs:
%   selectCallback - function handle which is called when the user selects
%                    a region.
%
%   clickCallback  - function handle which is called when the user clicks
%                    on a point. 
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
selectTimeSeriesGeneric( selectCallback, clickCallback );
