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
% Copyright (c) 2016, Australian Ocean Data Network (AODN) and Integrated 
% Marine Observing System (IMOS).
% All rights reserved.
% 
% Redistribution and use in source and binary forms, with or without 
% modification, are permitted provided that the following conditions are met:
% 
%     * Redistributions of source code must retain the above copyright notice, 
%       this list of conditions and the following disclaimer.
%     * Redistributions in binary form must reproduce the above copyright 
%       notice, this list of conditions and the following disclaimer in the 
%       documentation and/or other materials provided with the distribution.
%     * Neither the name of the AODN/IMOS nor the names of its contributors 
%       may be used to endorse or promote products derived from this software 
%       without specific prior written permission.
% 
% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
% AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
% IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
% ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE 
% LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
% CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
% SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
% INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
% CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
% ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
% POSSIBILITY OF SUCH DAMAGE.
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

