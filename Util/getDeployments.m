function [fieldTrip deployments sites dataDir] = getDeployments(auto, isCSV)
%GETDEPLOYMENTS Prompts the user for a field trip ID and data directory.
% Retrieves and returns the field trip, all deployments from the DDB that
% are related to the field trip, and the selected data directory.
%
% Inputs:
%   auto        - if true, the user is not prompted to select a field
%                 trip/directory; the values in toolboxProperties are
%                 used.
%   isCSV       - If true, look for csv files rather than using database.
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
narginchk(2,2);

deployments = struct;
sites       = struct;

if isCSV
    executeQueryFunc = @executeCSVQuery;
else
    executeQueryFunc = @executeDDBQuery;
end

% prompt the user to select a field trip and
% directory which contains raw data files
if ~auto
    [fieldTrip, dataDir] = startDialog('timeSeries', isCSV);
    % if automatic, just get the defaults from toolboxProperties.txt
else
    dataDir   = readProperty('startDialog.dataDir.timeSeries');
    fieldTrip = readProperty('startDialog.fieldTrip.timeSeries');
    
    if isempty(dataDir), error('startDialog.dataDir.timeSeries is not set');   end
    if isnan(fieldTrip), error('startDialog.fieldTrip.timeSeries is not set'); end
    
    fieldTrip = executeQueryFunc('FieldTrip', 'FieldTripID', fieldTrip);
end

% user cancelled start dialog
if isempty(fieldTrip) && isempty(dataDir), return; end

fId = fieldTrip.FieldTripID;

% query the ddb/csv file for all deployments related to this field trip
deployments = executeQueryFunc('DeploymentData', 'EndFieldTrip', fId);

% query the ddb for all sites related to these deployments
lenDep = length(deployments);
for i=1:lenDep
    if i==1
        sites = executeQueryFunc('Sites', 'Site', deployments(i).Site);
    else
        sites(i) = executeQueryFunc('Sites', 'Site', deployments(i).Site);
    end
end
