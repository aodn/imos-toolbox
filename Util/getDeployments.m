function [fieldTrip deployments sites dataDir] = getDeployments(auto)
%GETDEPLOYMENTS Prompts the user for a field trip ID and data directory.
% Retrieves and returns the field trip, all deployments from the DDB that
% are related to the field trip, and the selected data directory.
%
% Inputs:
%   auto        - if true, the user is not prompted to select a field
%                 trip/directory; the values in toolboxProperties are
%                 used.
%
% Outputs:
%   fieldTrip   - field trip struct - the field trip selected by the user.
%   deployments - vector of deployment structs related to the selected
%                 field trip.
%   sites       - vector of site structs related to the selected
%                 field trip.
%   dataDir     - String containing data directory path selected by user.
%
% Author:       Paul McCarthy <paul.mccarthy@csiro.au>
% Contributor:	Guillaume Galibert <guillaume.galibert@utas.edu.au>
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
narginchk(1,1);

deployments = struct;
sites       = struct;

% prompt the user to select a field trip and
% directory which contains raw data files
if ~auto
    [fieldTrip, dataDir] = startDialog('timeSeries');
    % if automatic, just get the defaults from toolboxProperties.txt
else
    dataDir   = readProperty('startDialog.dataDir.timeSeries');
    fieldTrip = readProperty('startDialog.fieldTrip.timeSeries');
    
    if isempty(dataDir), error('startDialog.dataDir.timeSeries is not set');   end
    if isnan(fieldTrip), error('startDialog.fieldTrip.timeSeries is not set'); end
    
    fieldTrip = executeQuery('FieldTrip', 'FieldTripID', fieldTrip);
end

% user cancelled start dialog
if isempty(fieldTrip) && isempty(dataDir), return; end

fId = fieldTrip.FieldTripID;

% query the ddb/csv file for all deployments related to this field trip
deployments = executeQuery('DeploymentData', 'EndFieldTrip', fId);

% query the ddb for all sites related to these deployments
lenDep = length(deployments);
for i=1:lenDep
    if i==1
        sites = executeQuery('Sites', 'Site', deployments(i).Site);
    else
        sites(i) = executeQuery('Sites', 'Site', deployments(i).Site);
    end
end
