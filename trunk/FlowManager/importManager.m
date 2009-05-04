function [sample_data cal_data skipped] = importManager()
%IMPORTMANAGER Manages the import of raw instrument data into the toolbox.
%
% Imports raw data. Prompts the user to select a field trip and a directory
% containing raw data, then matches up deployments (retrieved from the DDB)
% with raw data files and imports and returns the data.
%
% Deployments which do not specify a FileName field, or which have a 
% FileName fild that contains the (case insensitive) substring 'no data'
% are ignored.
%
% If something goes wrong, an error is raised. If the user cancels the 
% operation, empty arrays are returned.
%
% Outputs:
%   sample_data - Cell array of sample_data structs, each containing sample
%                 data for one instrument. 
%
%   cal_data    - Cell array of cal_data structs the sample length as the
%                 sample_data vector, each containing calibration/metadata
%                 for one instrument.
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

  dataDir = pwd;
  fieldTrip = 1;
  
  sample_data = {};
  cal_data    = {};

  % if default values exist for data dir and field trip, use them
  try 
    dataDir   =            readToolboxProperty('dataDir'); 
    fieldTrip = str2double(readToolboxProperty('fieldTrip'));
  catch
  end

  % prompt the user to select a field trip and 
  % directory which contains raw data files
  [fieldTrip dataDir] = startDialog(dataDir, fieldTrip);
  
  % user cancelled start dialog
  if isempty(fieldTrip) || isempty(dataDir), return; end

  % persist the user's directory and field trip selection
  writeToolboxProperty('dataDir',   dataDir);
  writeToolboxProperty('fieldTrip', num2str(fieldTrip));

  % query the ddb for all deployments related to this field trip
  deps    = executeDDBQuery('DeploymentData', 'StartFieldTrip', fieldTrip);
  endDeps = executeDDBQuery('DeploymentData', 'EndFieldTrip',   fieldTrip);
  
  % merge end field trip deployments with start field 
  % trip deployments; ensure there are no duplicates
  for k = 1:length(endDeps)
    
    d = endDeps(k);
    if find(ismember({deps.DeploymentId}, d.DeploymentId)), continue; end
    deps(end+1) = d;
  end
  
  clear endDeps;
  
  % remove invalid deployments
  deps = removeBadDeployments(deps);

  if isempty(deps)
    error(['no deployments related to field trip ' num2str(fieldTrip)]); 
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

  % parse file for each deployment, sample/cal pair for each.
  % if a parser can't be found for a deployment, don't bail; 
  % just ignore it for the time being
  skipped = [];
  for k = 1:length(deps)
    
    try      [sample_data{end+1} cal_data{end+1}] = parse(deps(k), files{k});
    catch e, skipped(end+1) = k;
    end
  end
  
  % return the deployments that were skipped
  skipped = deps(skipped);
end

function deployments = removeBadDeployments(deployments)
%REMOVEBADDEPLOYMENTS Removes deployments which do not have a valid 
% FileName field.
%
% Inputs:
%   deployments - vector of deployment structs.
%
% Outputs:
%   deployments - same as input, with bad deployments removed.
% 

  % find deployments with an empty FileName field, or 
  % which contain the (case insensitive string) 'No data'
  toRemove = [];
  for k = 1:length(deployments)
    
    d = deployments(k);
    f = d.FileName;
    
    if isempty(f) || ~isempty(strfind(lower(f), 'no data'))
      toRemove(end+1) = k; 
    end
  end
  
  % remove said deployments
  deployments(toRemove) = [];
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

function [sam cal] = parse(deployment, files)
%PARSE Parses a raw data file, returns sample_data/cal_data structs.
%
% Inputs:
%   deployment - Struct containing deployment data.
%   files      - Cell array containing file names.
%
% Outputs:
%   sam        - Struct containing sample data.
%   cal        - Struct containing calibration/metadata.
  sam = 0;
  cal = 0;

  % get the appropriate parser function
  parser = getParserFunc(deployment);
  if isnumeric(parser)
    error(['no parser found for instrument ' deployment.InstrumentID]); 
  end

  % parse the data; let errors propagate
  [sam cal] = parser(files);

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
