function sample_data = importManager()
%IMPORTMANAGER Manages the import of raw instrument data into the toolbox.
%
% Imports raw data. If a deployment database exists, prompts the user to 
% select a field trip and a directory containing raw data, then matches up 
% deployments (retrieved from the DDB) with raw data files and imports and 
% returns the data.
%
% If a deployment database does not exist, prompts the user to select a
% file and a parser, then imports and returns a single sample_data struct
% within a cell array.
%
% If something goes wrong, an error is raised. If the user cancels the 
% operation, empty arrays are returned.
%
% Outputs:
%   sample_data - Cell array of sample_data structs, each containing sample
%                 data for one instrument. 
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

  % If the toolbox.ddb property has been set, assume that we have a
  % deployment database. Otherwise perform a manual import
  ddb = readToolboxProperty('toolbox.ddb');
  
  sample_data = {};
  rawFiles    = {};
  
  if ~isempty(ddb), [sample_data rawFiles] = ddbImport();
  else              [sample_data rawFiles] = manualImport();
  end
  
  % user cancelled
  if isempty(sample_data), return; end
  
  dateFmt = readToolboxProperty('exportNetCDF.dateFormat');
  qcSet   = str2double(readToolboxProperty('toolbox.qc_set'));
  rawFlag = imosQCFlag('raw', qcSet, 'flag');
  
  % make data sets compliant
  for k = 1:length(sample_data)
    sample_data{k} = ...
      finaliseData(sample_data{k}, rawFiles{k}, dateFmt, rawFlag);
  end
end

function [sample_data rawFile]= manualImport()
%MANUALIMPORT Imports a data set by manually prompting the user to select a 
% raw file, and a parser with which to import it.
%
% Outputs:
%   sample_data - cell array containig a single imported data set, or empty 
%                 cell array if the user cancelled.
%   rawFile     - cell array containing the name of the raw file that the
%                 user selected.
%
  sample_data = {};
  rawFile     = {};
  
  manualDir = readToolboxProperty('importManager.manualDir');

  % prompt the user to select a data file
  [rawFile path] = uigetfile('*', 'Select Data File', manualDir);
  
  writeToolboxProperty('importManager.manualDir', path);
  
  if rawFile == 0, return; end;
  
  % prompt the user to select a parser with which to import the file
  parsers = listParsers();
  parser = optionDialog('Select a parser',...
    'Select a parser with which to import the data', parsers, 1);

  % user cancelled dialog
  if isempty(parser)
    parser = 0;
    return;
  end
  
  parser = getParser(parser);
  
  
  % display progress dialog
  progress = waitbar(0, ['importing ' rawFile], ...
    'Name',                  'Importing',...
    'DefaultTextInterpreter','none');
  
  % import the data
  rawFile     = [path rawFile];
  sample_data = {parser({rawFile})};
  rawFile     = {{rawFile}};
  
  close(progress);
end

function [sample_data rawFiles] = ddbImport()
%DDBIMPORT Imports data sets using metadata retrieved from a deployment
% database.
%
% Outputs:
%   sample_data - cell array containig the imported data sets, or empty 
%                 cell array if the user cancelled.
%   rawFile     - cell array containing the names of the raw files for each
%                 data set.
%
  sample_data = {};
  rawFiles    = {};

  [fieldTrip deps dataDir] = getDeployments();
  
  if isempty(deps), return; end
    
  % find physical files for each deployment
  rawFiles = cell(size(deps));
  for k = 1:length(deps)
    
    id   = deps(k).DeploymentId;
    rawFile = deps(k).FileName;
    
    hits = fsearch(rawFile, dataDir);
    rawFiles{k} = hits;
  end
  
  % display status dialog to highlight any discrepancies (file not found
  % for a deployment, more than one file found for a deployment)
  [deps rawFiles] = dataFileStatusDialog(deps, rawFiles);
  
  % user cancelled file dialog
  if isempty(deps), return; end
  
  % display progress dialog
  progress = waitbar(0, 'importing data', ...
    'Name',                  'Importing',...
    'DefaultTextInterpreter','none');
    
  parsers = listParsers();
  noParserPrompt = eval(readToolboxProperty('importManager.noParserPrompt'));
  
  % parse file for each deployment, sample struct for each.
  % if a parser can't be found for a deployment, don't bail; 
  % just ignore it for the time being
  for k = 1:length(deps)
    
    try
      fileDisplay = '';
      if isempty(rawFiles{k}), error('no files to import'); end

      % update progress dialog
      for m = 1:length(rawFiles{k})
        [path name ext] = fileparts(rawFiles{k}{m});
        fileDisplay = [fileDisplay ', ' name ext];
      end
      fileDisplay = fileDisplay(3:end);
      waitbar(k / length(deps), progress, ['importing ' fileDisplay]);

      % import data
      sample_data{k} = parse(deps(k), rawFiles{k}, parsers, noParserPrompt);
      sample_data{k}.meta.deployment = deps(k);
    
    % failure is not fatal
    catch e
      disp(['skipping ' fileDisplay '(' e.message ')']);
      for m = 1:length(e.stack)
        disp([e.stack(m).file ':' ...
        num2str(e.stack(m).line) ':' e.stack(m).name]);
      end
    end
  end
  
  % close progress dialog
  close(progress);
  
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
  end

  function sam = parse(deployment, files, parsers, noParserPrompt)
  %PARSE Parses a raw data file, returns a sample_data struct.
  %
  % Inputs:
  %   deployment     - Struct containing deployment data.
  %   files          - Cell array containing file names.
  %   parsers        - Cell array of strings containing all available parsers.
  %   noParserPrompt - Whether to prompt the user if a parser cannot be found.
  %
  % Outputs:
  %   sam        - Struct containing sample data.

    % get the appropriate parser function
    parser = getParserFunc(deployment, parsers, noParserPrompt);
    if isnumeric(parser)
      error(['no parser found for instrument ' deployment.InstrumentID]); 
    end

    % parse the data; let errors propagate
    sam = parser(files);

  end

  function parser = getParserFunc(deployment, parsers, noParserPrompt)
  %GETPARSERFUNC Searches for a parser function which is able to parse data 
  % for the given deployment.
  %
  % Inputs:
  %   deployment     - struct containing information about the deployment.
  %   parsers        - Cell array of strings containing all available parsers.
  %   noParserPrompt - Whether to prompt the user if a parser cannot be found.
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

    % if there is no parser for the instrument, prompt the user to choose one
    if parser == 0
      if ~noParserPrompt, return; end

      parser = optionDialog(...
        'Select a parser',...
        ['A parser could not be found for the ' ...
         instrument.Make ' ' instrument.Model ...
         '. Please select one from the list.'],...
        parsers, 1);

      % user cancelled dialog
      if isempty(parser)
        parser = 0;
        return;
      end

      % persist the instrument<->parser mapping for next time
      setParserNameForInstrument(instrument.Make, instrument.Model, parser);

    end

    % get the parser function handle
    parser = getParser(parser);
  end
end

function sam = finaliseData(sam, rawFiles, dateFmt, flagVal)
%FINALISEDATA Adds all required/relevant information from the given field
%trip and deployment structs to the given sample data.
%

  % add IMOS file version info
  sam.file_version                 = imosFileVersion(0, 'name');
  sam.file_version_quality_control = imosFileVersion(0, 'desc');
  sam.date_created                 = now;

  % turn raw data files a into semicolon separated string
  rawFiles = cellfun(@(x)([x ';']), rawFiles, 'UniformOutput', false);
  
  sam.meta.level         = 0;
  sam.meta.log           = {};
  sam.meta.raw_data_file = [rawFiles{:}];
  
  if isfield(sam.meta, 'deployment')
    sam.meta.site_name     = sam.meta.deployment.Site;
    sam.meta.depth         = sam.meta.deployment.InstrumentDepth;
    sam.meta.timezone      = sam.meta.deployment.TimeZone;
  else
    sam.meta.site_name     = 'NONAME';
    sam.meta.depth         = nan;
    sam.meta.timezone      = 'UTC';
  end
  
  % add empty QC flags for all variables
  for k = 1:length(sam.variables)
    
    sam.variables{k}.flags(1:numel(sam.variables{k}.data)) = flagVal;
    sam.variables{k}.flags = reshape(...
    sam.variables{k}.flags, size(sam.variables{k}.data));
  end
  
  % and for all dimensions
  for k = 1:length(sam.dimensions)
    
    sam.dimensions{k}.flags(1:numel(sam.dimensions{k}.data)) = flagVal;
    sam.dimensions{k}.flags = reshape(...
    sam.dimensions{k}.flags, size(sam.dimensions{k}.data));
  end
  
  % add IMOS parameters
  sam = makeNetCDFCompliant(sam);
  
  % set the time coverage period - use the best field available
  if isfield(sam.meta, 'deployment')
    
    if ~isempty(sam.meta.deployment.TimeFirstGoodData)
      sam.time_coverage_start = sam.meta.deployment.TimeFirstGoodData;
    elseif ~isempty(sam.meta.deployment.TimeFirstInPos)
      sam.time_coverage_start = sam.meta.deployment.TimeFirstInPos;
    elseif ~isempty(sam.meta.deployment.TimeFirstWet)
      sam.time_coverage_start = sam.meta.deployment.TimeFirstWet;
    elseif ~isempty(sam.meta.deployment.TimeSwitchOn)
      sam.time_coverage_start = sam.meta.deployment.TimeSwitchOn;
    end

    if ~isempty(sam.meta.deployment.TimeLastGoodData)
      sam.time_coverage_end = sam.meta.deployment.TimeLastGoodData;
    elseif ~isempty(sam.meta.deployment.TimeLastInPos)
      sam.time_coverage_end = sam.meta.deployment.TimeLastInPos;
    elseif ~isempty(sam.meta.deployment.TimeOnDeck)
      sam.time_coverage_end = sam.meta.deployment.TimeOnDeck;
    elseif ~isempty(sam.meta.deployment.TimeSwitchOff)
      sam.time_coverage_end = sam.meta.deployment.TimeSwitchOff;
    end
  else
    
    time = getVar(sam.dimensions, 'TIME');
    
    if time ~= 0
      sam.time_coverage_start = sam.dimensions{time}.data(1);
      sam.time_coverage_end   = sam.dimensions{time}.data(end);
    else
      sam.time_coverage_start = 0;
      sam.time_coverage_end   = 0;
    end
  end
end