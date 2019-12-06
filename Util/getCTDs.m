function [fieldTrip ctds sites dataDir] = getCTDs(auto)
%GETCTDS Prompts the user for a field trip ID and data directory.
% Retrieves and returns the field trip, all ctds from the DDB that
% are related to the field trip, and the selected data directory.
%
% Inputs:
%   auto        - if true, the user is not prompted to select a field
%                 trip/directory; the values in toolboxProperties are
%                 used.
%
% Outputs:
%   fieldTrip   - field trip struct - the field trip selected by the user.
%   ctds        - vector of ctd structs related to the selected
%                 field trip.
%   sites       - vector of site structs related to the selected
%                 field trip.
%   dataDir     - String containing data directory path selected by user.
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
ctds  = struct;
sites = struct;

% prompt the user to select a field trip and
% directory which contains raw data files
if ~auto
    [fieldTrip dataDir] = startDialog('profile');
    % if automatic, just get the defaults from toolboxProperties.txt
else
    dataDir   = readProperty('startDialog.dataDir.profile');
    fieldTrip = readProperty('startDialog.fieldTrip.profile');
    
    if isempty(dataDir), error('startDialog.dataDir.profile is not set');   end
    if isnan(fieldTrip), error('startDialog.fieldTrip.profile is not set'); end
    
    fieldTrip = executeQuery('FieldTrip', 'FieldTripID', fieldTrip);
end

% user cancelled start dialog
if isempty(fieldTrip) || isempty(dataDir), return; end

fId = fieldTrip.FieldTripID;

% query the ddb for all ctds related to this field trip
ctds = executeQuery('CTDData', 'FieldTrip', fId);

% query the ddb for all sites related to these ctds
lenDep = length(ctds);
for i=1:lenDep
    if i==1
        tempVal = executeQuery('Sites', 'Site', ctds(i).Site);
        % A CTDData doesn't necessarily has an associated site, 
        % CTDData already contains some site information
        if ~isempty(tempVal), sites = tempVal; end
    else
        tempVal = executeQuery('Sites', 'Site', ctds(i).Site);
        if ~isempty(tempVal), sites(i) = tempVal; end
    end
end