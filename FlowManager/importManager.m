function [fieldTrip sample_data skipped] = importManager( deployments, dataDir )
%IMPORTMANAGER Manages the import of raw instrument data into the toolbox.
%
% Imports raw data. If no inputs are given, prompts the user to select a 
% field trip and a directory containing raw data, then matches up deployments 
% (retrieved from the DDB) with raw data files and imports and returns the 
% data.
%
% If a vector of deployments and a data directory are given, the user is
% not prompted for a field trip or directory.
%
% Deployments which do not specify a FileName field, or which have a 
% FileName fild that contains the (case insensitive) substring 'no data'
% are ignored.
%
% If something goes wrong, an error is raised. If the user cancels the 
% operation, empty arrays are returned.
%
% Inputs:
%   deployments - Optional. If provided, the user is not prompted for a
%                 field trip ID or data directory.
%
%   dataDir     - Optional. If provided, the user is not prompted for a
%                 field trip ID or data directory. If deployments is
%                 provided and dataDir is not provided, the import.dataDir
%                 toolbox property is used as a default.
%
% Outputs:
%   fieldTrip   - Struct containing information about the selected field
%                 trip.
%   sample_data - Cell array of sample_data structs, each containing sample
%                 data for one instrument. 
%
%   skipped     - Vector of deployment structs, containing the deployments
%                 for which data could not be imported (i.e. for which a
%                 parser could not be found or for which an error occured
%                 during the import).
%
% Author: Paul McCarthy <paul.mccarthy@csiro.au>
%

%
% Copyright (c) 2009, eMarine Information Infrastructure (eMII) and Integrated 
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
%     * Neither the name of the eMII/IMOS nor the names of its contributors 
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
  error(nargchk(0,2,nargin));
  
  fieldTrip   = [];
  sample_data = {};
  skipped     = [];

  if     nargin == 0, [fieldTrip deployments dataDir] = getDeployments();
  elseif nargin == 1, dataDir = readToolboxProperty('startDialog.dataDir');
  elseif nargin == 2, 
  end
  
  if ~isstruct(deployments) || isempty(deployments),
    error('deployments is either not a struct, or contains no elements');
  end
    
  % deps is easier to type
  deps = deployments;
  clear deployments;
  
  % if the user provided a set of deployments, 
  % we need to retrieve the related field trip
  if isempty(fieldTrip)
    fieldTrip = ...
      executeDDBQuery('FieldTrip', 'FieldTripID', deps(1).EndFieldTrip);
    
    if length(fieldTrip) ~= 1, error('invalid field trip ID'); end
  end
    
  % find physical files for each deployment
  files = cell(size(deps));
  for k = 1:length(deps)
    
    id   = deps(k).DeploymentId;
    file = deps(k).FileName;
    
    hits = fsearch(file, dataDir);
    files{k} = hits;
  end
  
  % display status dialog to highlight any discrepancies (file not found
  % for a deployment, more than one file found for a deployment)
  [deps files] = dataFileStatusDialog(deps, files);
  
  % user cancelled file dialog
  if isempty(deps), return; end
  
  % display progress dialog
  progress = waitbar(0, 'importing data');
  
  % parse file for each deployment, sample struct for each.
  % if a parser can't be found for a deployment, don't bail; 
  % just ignore it for the time being
  for k = 1:length(deps)
    
    try
      fileDisplay = '';
      if isempty(files{k}), error('no files to import'); end

      % update progress dialog
      for m = 1:length(files{k})
        [path name ext] = fileparts(files{k}{m});
        fileDisplay = [fileDisplay ', ' name ext];
      end
      fileDisplay = fileDisplay(3:end);
      waitbar(k / length(deps), progress, ['importing ' fileDisplay]);
      disp(['importing ' fileDisplay]);

      % import data
      sam = parse(deps(k), files{k});
      sam = finaliseData(sam, fieldTrip, deps(k));
      sample_data{end+1} = sam;
    
    % failure is not fatal
    catch e
      disp(['skipping ' fileDisplay '(' e.message ')']);
      skipped(end+1) = k;
    end
  end
  
  % close progress dialog
  close(progress);
  
  % return the deployments that were skipped
  skipped = deps(skipped);
end

function [fieldTrip deployments dataDir] = getDeployments()
%GETDEPLOYMENTS Prompts the user for a field trip ID and data directory.
% Retrieves and returns the field trip, all deployments from the DDB that 
% are related to the field trip, and the selected data directory.
%
% Outputs:
%   fieldTrip   - field trip struct - the field trip selected by the user.
%   deployments - vector of deployment structs related to the selected 
%                 field trip.
%   dataDir     - String containing data directory path selected by user.
%
  deployments = [];

  % prompt the user to select a field trip and 
  % directory which contains raw data files
  [fieldTrip dataDir] = startDialog();
    
  % user cancelled start dialog
  if isempty(fieldTrip) || isempty(dataDir), return; end
  
  fId = fieldTrip.FieldTripID;

  % query the ddb for all deployments related to this field trip
  deployments = executeDDBQuery('DeploymentData', 'StartFieldTrip', fId);
  endDeps     = executeDDBQuery('DeploymentData', 'EndFieldTrip',   fId);
  
  % merge end field trip deployments with start field 
  % trip deployments; ensure there are no duplicates
  for k = 1:length(endDeps)
    
    d = endDeps(k);
    if find(ismember({deployments.DeploymentId}, d.DeploymentId))
      continue; 
    end
    deployments(end+1) = d;
  end
  
  if isempty(deployments)
    error(['no deployments related to field trip ' num2str(fId)]); 
  end
end

function hits = fsearch(pattern, root)
%FSEARCH Recursive file/directory search.
%
% Performs a recursive search starting at the given root directory; returns
% the names of all files and directories below the root which contain the 
% given pattern as a substring with their name. The name comparison is case 
% insensitive for alphabetical characters.
%
% Inputs:
%
%   pattern - Pattern to match.
%
%   root    - Directory from which to start the search.
%
% Outputs:
% 
%   hits    - Cell array of strings containing the files/directories that
%             have a name which contains the pattern.

  hits = {};
  
  if ~isdir(root), return; end
  
  entries = dir(root);
  
  for k = 1:length(entries)
    
    d = entries(k);
    
    % ignore current/prev entries
    if strcmp(d.name, '.') || strcmp(d.name, '..'), continue; end
    
    % compare file and directory names against pattern
    if strfind(lower(d.name), lower(pattern))
      
      hits{end+1} = [root filesep d.name];
    end
    
    % recursively search subdirectories
    if d.isdir, 
      
      subhits = fsearch(pattern, [root filesep d.name]);
      hits = [hits subhits];
    end
  end
end

function sam = parse(deployment, files)
%PARSE Parses a raw data file, returns a sample_data struct.
%
% Inputs:
%   deployment - Struct containing deployment data.
%   files      - Cell array containing file names.
%
% Outputs:
%   sam        - Struct containing sample data.

  % get the appropriate parser function
  parser = getParserFunc(deployment);
  if isnumeric(parser)
    error(['no parser found for instrument ' deployment.InstrumentID]); 
  end

  % parse the data; let errors propagate
  sam = parser(files);

end

function parser = getParserFunc(deployment)
%GETPARSERFUNC Searches for a parser function which is able to parse data 
% for the given deployment.
%
% Inputs:
%   deployment - struct containing information about the deployment.
%
% Outputs:
%   parser     - Function handle to the parser function, or 0 if a parser
%                function wasn't found.
%
  instrument = executeDDBQuery(...
    'Instruments', 'InstrumentID', deployment.InstrumentID);
  
  % there should be exactly one instrument 
  if length(instrument) ~= 1
    error(['invalid number of instruments returned from DDB query: ' ...
           num2str(length(instrument))]); 
  end
  
  % get the parser name
  parser = getParserNameForInstrument(instrument.Make, instrument.Model);
  if parser == 0, return; end
  
  % get the parser function handle
  parser = getParser(parser);
end

function sam = finaliseData(sam, fieldTrip, deployment)
%FINALISEDATA Adds all required/relevant information from the given field
%trip and deployment structs to the given sample data.
%
  qc_set = str2double(readToolboxProperty('toolbox.qc_set'));
  
  % process level == raw
  sam.level                  = 0;
  
  sam.date_created           = now;

  sam.field_trip_id          = fieldTrip.FieldTripID;
  sam.field_trip_description = fieldTrip.FieldDescription;
  
  % should we use Time[First|Last]GoodData ?
  sam.time_coverage_start = str2double(deployment.TimeFirstInPos);
  sam.time_coverage_end   = str2double(deployment.TimeLastInPos);
  
  for k = 1:length(sam.variables)
    
    sam.variables{k}.deployment_id = deployment.DeploymentId;
    
    sam.variables{k}.flags = [];
    
    % we currently have no access to this information
    sam.variables{k}.valid_min = -99999.0;
    sam.variables{k}.valid_max =  99999.0;
  end
  
  % add IMOS-compliant parameters
  sam = makeNetCDFCompliant(sam);

end
