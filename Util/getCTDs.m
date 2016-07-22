function [fieldTrip ctds sites dataDir] = getCTDs(auto, isCSV)
%GETCTDS Prompts the user for a field trip ID and data directory.
% Retrieves and returns the field trip, all ctds from the DDB that
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
%   ctds        - vector of ctd structs related to the selected
%                 field trip.
%   sites       - vector of site structs related to the selected
%                 field trip.
%   dataDir     - String containing data directory path selected by user.
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
ctds  = struct;
sites = struct;

if isCSV
    executeQueryFunc = @executeCSVQuery;
else
    executeQueryFunc = @executeDDBQuery;
end
    
% prompt the user to select a field trip and
% directory which contains raw data files
if ~auto
    [fieldTrip dataDir] = startDialog('profile', isCSV);
    % if automatic, just get the defaults from toolboxProperties.txt
else
    dataDir   = readProperty('startDialog.dataDir.profile');
    fieldTrip = readProperty('startDialog.fieldTrip.profile');
    
    if isempty(dataDir), error('startDialog.dataDir.profile is not set');   end
    if isnan(fieldTrip), error('startDialog.fieldTrip.profile is not set'); end
    
    fieldTrip = executeQueryFunc('FieldTrip', 'FieldTripID', fieldTrip);
end

% user cancelled start dialog
if isempty(fieldTrip) || isempty(dataDir), return; end

fId = fieldTrip.FieldTripID;

% query the ddb for all ctds related to this field trip
ctds = executeQueryFunc('CTDData', 'FieldTrip', fId);

% query the ddb for all sites related to these ctds
lenDep = length(ctds);
for i=1:lenDep
    if i==1
        tempVal = executeQueryFunc('Sites', 'Site', ctds(i).Site);
        % A CTDData doesn't necessarily has an associated site, 
        % CTDData already contains some site information
        if ~isempty(tempVal), sites = tempVal; end
    else
        tempVal = executeQueryFunc('Sites', 'Site', ctds(i).Site);
        if ~isempty(tempVal), sites(i) = tempVal; end
    end
end