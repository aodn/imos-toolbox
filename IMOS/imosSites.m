function site = imosSites(name)
%IMOSSITES Returns the name, longitude, latitude and different thresholds 
% to QC data with the Morello et Al. 2011 impossible location test. 
%
% IMOS sites longitude and latitude were taken from the IMOS portal 
% metadata.
%
% Inputs:
%   name - name of the required site details. 
%
% Outputs:
%   site - structure with the following fields for the requested site :
%               -name
%               -longitude
%               -latitude
%               -longitudePlusMinusThreshold
%               -latitudePlusMinusThreshold
%               -distanceKmPlusMinusThreshold (optional, 
%                       if documented overrules previous thresholds values)
%
% Author:  Guillaume Galibert <guillaume.galibert@utas.edu.au>
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
if ~ischar(name),    error('name must be a string'); end

site = [];

% get the location of this m-file, which is 
% also the location of imosSite.txt
path = '';
if ~isdeployed, [path, ~, ~] = fileparts(which('imosToolbox.m')); end
if isempty(path), path = pwd; end
path = fullfile(path, 'IMOS');

fid = -1;
params = [];
try
  fid = fopen([path filesep 'imosSites.txt'], 'rt');
  if fid == -1, return; end
  
  params = textscan(fid, '%s%12.8f%12.8f%f%f%f', 'delimiter', ',', 'commentStyle', '%');
  fclose(fid);
catch e
  if fid ~= -1, fclose(fid); end
  rethrow(e);
end

% look for a site name match
iName = strcmpi(name, params{1});

if any(iName)
    site = struct;
    
    site.name                           = params{1}{iName};
    site.longitude                      = params{2}(iName);
    site.latitude                       = params{3}(iName);
    site.longitudePlusMinusThreshold    = params{4}(iName);
    site.latitudePlusMinusThreshold     = params{5}(iName);
    site.distanceKmPlusMinusThreshold   = params{6}(iName);
else
    return;
end
