function [coordinates, dimensions, variables] = loadTimeSeriesSampleTemplate(timev, latd, lond, depthd)
% function [coordinates, dimensions, variables] = loadTimeSeriesSampleTemplate(timev, latd, lond, depthd)
%
% Load the default timeseries coordinates string and dimensions/variables structures
%
% Inputs:
%
% timev - the time values
%
% latd - the latitude dimension index list
%        default: []
% lond - the longitude dimension index list
%        default: []
% depthd - the depth dimension index list
%        default: []
%
% Outputs:
%
% coordinates - a string with all coordinates names
% dimensions - a structure with all dimensions prefilled
% variables - a structure with all variables prefilled
%
% Example:
% [coords,dims,vars] = loadTimeSeriesSampleTemplate([1,2,3]);
% % check coordinates
% assert(strcmpi(coords,'TIME LATITUDE LONGITUDE NOMINAL_DEPTH'))
% % check dimensions
% assert(length(dims)==1)
% assert(isequal(dims{1}.name,'TIME'))
% assert(isequal(dims{1}.typeCastFunc,@double))
% assert(isequal(dims{1}.data,[1,2,3]))
% % check variables
% assert(length(vars)==4)
% assert(isequal(vars{1}.name,'TIMESERIES'))
% assert(isequal(vars{2}.name,'LATITUDE'))
% assert(isequal(vars{3}.name,'LONGITUDE'))
% assert(isequal(vars{4}.name,'NOMINAL_DEPTH'))
%
%
% author: hugo.oliveira@utas.edu.au
%

% Copyright (C) 2019, Australian Ocean Data Network (AODN) and Integrated
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
%
% You should have received a copy of the GNU General Public License
% along with this program.
% If not, see <https://www.gnu.org/licenses/gpl-3.0.en.html>.
%

narginchk(1, 4);

if nargin < 2
    latd = [];
    lond = [];
    depthd = [];
elseif nargin < 3
    lond = [];
    depthd = [];
elseif nargn < 4
    depthd = [];
end

coordinates = 'TIME LATITUDE LONGITUDE NOMINAL_DEPTH';
dimensions = {};
variables = {};

dimensions{1}.name = 'TIME';
dimensions{1}.typeCastFunc = getIMOSType(dimensions{1}.name);
dimensions{1}.data = timev;

variables{end + 1}.name = 'TIMESERIES';
variables{end}.typeCastFunc = getIMOSType(variables{end}.name);
variables{end}.data = variables{end}.typeCastFunc(1);
variables{end}.dimensions = [];

variables{end + 1}.name = 'LATITUDE';
variables{end}.typeCastFunc = getIMOSType(variables{end}.name);
variables{end}.data = variables{end}.typeCastFunc(NaN);
variables{end}.dimensions = latd;

variables{end + 1}.name = 'LONGITUDE';
variables{end}.typeCastFunc = getIMOSType(variables{end}.name);
variables{end}.data = variables{end}.typeCastFunc(NaN);
variables{end}.dimensions = lond;

variables{end + 1}.name = 'NOMINAL_DEPTH';
variables{end}.typeCastFunc = getIMOSType(variables{end}.name);
variables{end}.data = variables{end}.typeCastFunc(NaN);
variables{end}.dimensions = depthd;

end
