function [ lat, lon ] = getLatLonForGSW( sam )
%GETLATLONFORGSW retrieves values of latitude and longitude for 
% use in the Gibbs-SeaWater toolbox (TEOS-10). 
%
% In priority will be considered in sam the following source of lat/lon 
% values:
%   1. geospatial_lat_min/max and geospatial_lon_min/max
%
% Inputs:
%   sam         - structure data set.
%
% Outputs:
%   lat    - the latitude data retrieved from sam for use in GSW.
%   lon    - the longitude data retrieved from sam for use in GSW.
%
% Author:       Guillaume Galibert <guillaume.galibert@utas.edu.au>
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
narginchk(1, 1);

if ~isstruct(sam),  error('sam must be a struct');  end
if isempty(sam),    return;                         end

lat = [];
lon = [];

if ~isempty(sam.geospatial_lat_min) && ~isempty(sam.geospatial_lat_max) && ...
        ~isempty(sam.geospatial_lon_min) && ~isempty(sam.geospatial_lon_max)
    if sam.geospatial_lat_min == sam.geospatial_lat_max
        lat = sam.geospatial_lat_min;
    else
        lat = sam.geospatial_lat_min + ...
            (sam.geospatial_lat_max - sam.geospatial_lat_min)/2;
    end
    if sam.geospatial_lon_min == sam.geospatial_lon_max
        lon = sam.geospatial_lon_min;
    else
        lon = sam.geospatial_lon_min + ...
            (sam.geospatial_lon_max - sam.geospatial_lon_min)/2;
    end
else
    disp(['Warning : no geospatial_lat_min/geospatial_lon_min documented for oxygenPP to be applied on ' sam.toolbox_input_file]);
    prompt = {'Latitude (South -ve)', 'Longitude (West -ve)'};
    dlg_title = 'Coords';
    num_lines = 1;
    defaultans = {'0', '0'};
    answer = inputdlg(prompt,dlg_title,num_lines,defaultans);
    
    if isempty(answer), return; end
    
    lat = str2double(answer(1));
    lon = str2double(answer(2));
end

end

