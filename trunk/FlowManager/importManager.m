function sample_data = importManager(toolboxVersion, auto, iMooring)
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
% Inputs:
%   toolboxVersion  - version of the current toolbox, used to fill NetCDF
%                   files metadata
%
%   auto            - Optional boolean. If true, the import process runs
%                   automatically with no user interaction. A DDB must be 
%                   present for this to work.
%
%   iMooring        - Optional logical(comes with auto == true). Contains
%                   the logical indices to extract only the deployments 
%                   from one mooring set of deployments.
%
% Outputs:
%   sample_data - Cell array of sample_data structs, each containing sample
%                 data for one instrument. 
%
% Author:       Paul McCarthy <paul.mccarthy@csiro.au>
% Contributor:  Gordon Keith <gordon.keith@csiro.au>
%   -bug fixes
%               Guillaume Galibert <guillaume.galibert@utas.edu.au>
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
  error(nargchk(1,3,nargin));

  if nargin == 1
      auto = false;
      iMooring = [];
  end

  % If the toolbox.ddb property has been set, assume that we have a
  % deployment database. Otherwise perform a manual import
  ddb = readProperty('toolbox.ddb');
  
  driver = readProperty('toolbox.ddb.driver');
  connection = readProperty('toolbox.ddb.connection');
  
  sample_data = {};
  rawFiles    = {};
  
  if ~isempty(ddb) || (~isempty(driver) && ~isempty(connection))
      [structs rawFiles] = ddbImport(auto, iMooring);
  else
    if auto, error('manual import cannot be automated without deployment database'); end
    [structs rawFiles] = manualImport();
  end
  
  % user cancelled
  if isempty(structs), return; end
  
  dateFmt = readProperty('exportNetCDF.dateFormat');
  qcSet   = str2double(readProperty('toolbox.qc_set'));
  rawFlag = imosQCFlag('raw', qcSet, 'flag');
  
  % make data sets compliant
  for k = 1:length(structs)
    
    % one data set may have generated more than one sample_data struct
    if iscell(structs{k})
      
      for m = 1:length(structs{k})
        sample_data{end+1} = ...
          finaliseData(structs{k}{m}, rawFiles{k}, rawFlag, toolboxVersion);
      end
      
    % more likely, only one struct generated for one raw data file
    else
      
      sample_data{end+1} = ...
        finaliseData(structs{k}, rawFiles{k}, rawFlag, toolboxVersion);
    end
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
  
  manualDir = readProperty('importManager.manualDir');
  if isempty(manualDir), manualDir = pwd; end
  
  % get the toolbox execution mode. Values can be 'timeSeries' and 'profile'. 
  % If no value is set then default mode is 'timeSeries'
  mode = lower(readProperty('toolbox.mode'));
  
  while true

    % prompt the user to select a data file
    [rawFile path] = uigetfile('*', 'Select Data File', manualDir);

    if rawFile == 0, return; end;

    writeProperty('importManager.manualDir', path);

    % prompt the user to select a parser with which to import the file
    parsers = listParsers();
    parser = optionDialog('Select a parser',...
      'Select a parser with which to import the data', parsers, 1);

    % user cancelled dialog
    if isempty(parser), continue; end
    
    parser = getParser(parser);

    % display progress dialog
    progress = waitbar(0, ['importing ' rawFile], ...
      'Name',                  'Importing',...
      'DefaultTextInterpreter','none');

    % import the data
    try 
      rawFile     = [path rawFile];
      sample_data = {parser({rawFile}, mode)};
      rawFile     = {{rawFile}};
      close(progress);
      
    catch e
      
      close(progress);
      
      errorString = getErrorString(e);
      fprintf('%s\n',   ['Error says : ' errorString]);
      
      % make sure sprintf doesn't interpret windows 
      % file separators as escape characters
      rawFile = strrep(rawFile, '\', '\\');
      srcFile = strrep(e.stack(1).file, '\', '\\');
      errmsg = sprintf(['Could not import ' rawFile ...
                ' with ' func2str(parser)  ...
                '. Did you select the correct parser?' ...
                '\n\n  ' srcFile ':' num2str(e.stack(1).line) ...
                  '\n  ' e.message]);
      e = errordlg(errmsg, 'Import error');
      uiwait(e);
      continue;
    end

    break;
  end
end

function [sample_data rawFiles] = ddbImport(auto, iMooring)
%DDBIMPORT Imports data sets using metadata retrieved from a deployment
% database.
%
% Inputs:
%   auto        - if true, the import process is automated, with no user
%                 interaction.
%
% Outputs:
%   sample_data - cell array containig the imported data sets, or empty 
%                 cell array if the user cancelled.
%   rawFile     - cell array containing the names of the raw files for each
%                 data set.
%
  sample_data = {};
  rawFiles    = {};
  allFiles    = {};
  
  % get the toolbox execution mode. Values can be 'timeSeries' and 'profile'. 
  % If no value is set then default mode is 'timeSeries'
  mode = lower(readProperty('toolbox.mode'));
  
  while true
      switch mode
          case 'profile'
              [fieldTrip deps sits dataDir] = getCTDs(auto);
          otherwise
              [fieldTrip deps sits dataDir] = getDeployments(auto);
      end
      
      if isempty(fieldTrip), return; end
      
      if ~isempty(iMooring)
          deps = deps(iMooring);
          sits = sits(iMooring);
      end

    if isempty(deps)
        fprintf('%s\n', ['Warning : ' 'No entry found in ' mode ' table.']);
        return;
    end

    % find physical files for each deployment
    allFiles = cell(size(deps));
    for k = 1:length(deps)

        switch mode
            case 'profile'
                id   = deps(k).FieldTrip;
            otherwise
                id   = deps(k).DeploymentId;
        end
        
      rawFile = deps(k).FileName;

      hits = fsearch(rawFile, dataDir, 'files');

      allFiles{k} = hits;
    end
    
    % display status dialog to highlight any discrepancies (file not found
    % for a deployment, more than one file found for a deployment)
    if ~auto
      [deps allFiles] = dataFileStatusDialog(deps, allFiles);

      % user cancelled file dialog
      if isempty(deps), continue; end

      % display progress dialog
      progress = waitbar(0, 'importing data', ...
        'Name',                  'Importing',...
        'DefaultTextInterpreter','none');
    end
    
    break;
  end
    
  parsers = listParsers();
  noParserPrompt = eval(readProperty('importManager.noParserPrompt'));
  
  if auto, noParserPrompt = false; end
  
  % parse file for each deployment, sample struct for each.
  % if a parser can't be found for a deployment, don't bail; 
  % just ignore it for the time being
  for k = 1:length(deps)
    
    try
      if isempty(allFiles{k}), error('no files to import'); end

      fileDisplay = '';
      % update progress dialog
      if ~auto
          for m = 1:length(allFiles{k})
              [~, name, ext] = fileparts(allFiles{k}{m});
              fileDisplay = [fileDisplay ', ' name ext];
          end
          fileDisplay = fileDisplay(3:end);
          waitbar(k / length(deps), progress, ['importing ' fileDisplay]);
      end
      
      % import data
      sample_data{end+1} = parse(deps(k), allFiles{k}, parsers, noParserPrompt, mode);
      rawFiles{   end+1} = allFiles{k};
      
      if iscell(sample_data{end})
        
        for m = 1:length(sample_data{end})
            switch mode
                case 'profile'
                    sample_data{end}{m}.meta.profile = deps(k);
                otherwise
                    sample_data{end}{m}.meta.deployment = deps(k);
            end
          
            sample_data{end}{m}.meta.site = sits(k);
        end
        
      else
          switch mode
              case 'profile'
                  sample_data{end}.meta.profile = deps(k);
              otherwise
                  sample_data{end}.meta.deployment = deps(k);
          end
        
          sample_data{end}.meta.site = sits(k);
      end
    
      if auto
          fprintf('%s\n', ['	-' deps(k).FileName]);
      end
      
    % failure is not fatal
    catch e
        switch mode
            case 'profile'
                fprintf('%s\n',   ['Warning : skipping ' deps(k).FileName]);
                fprintf('\t%s\n', ['FieldTrip = ' deps(k).FieldTrip]);
                fprintf('\t%s\n', ['SiteName = ' sits(k).SiteName]);
                fprintf('\t%s\n', ['Site = ' deps(k).Site]);
                fprintf('\t%s\n', ['Station = ' deps(k).Station]);
                fprintf('\t%s\n', ['InstrumentID = ' deps(k).InstrumentID]);
                errorString = getErrorString(e);
                fprintf('%s\n',   ['Error says : ' errorString]);
            otherwise
                fprintf('%s\n',   ['Warning : skipping ' deps(k).FileName]);
                fprintf('\t%s\n', ['EndFieldTrip = ' deps(k).EndFieldTrip]);
                fprintf('\t%s\n', ['SiteName = ' sits(k).SiteName]);
                fprintf('\t%s\n', ['Site = ' deps(k).Site]);
                fprintf('\t%s\n', ['Station = ' deps(k).Station]);
                fprintf('\t%s\n', ['DeploymentType = ' deps(k).DeploymentType]);
                fprintf('\t%s\n', ['InstrumentID = ' deps(k).InstrumentID]);
                errorString = getErrorString(e);
                fprintf('%s\n',   ['Error says : ' errorString]);
        end
    end
  end
  
  % close progress dialog
  if ~auto, close(progress); end

  function sam = parse(deployment, files, parsers, noParserPrompt, mode)
  %PARSE Parses a raw data file, returns a sample_data struct.
  %
  % Inputs:
  %   deployment     - Struct containing deployment data.
  %   files          - Cell array containing file names.
  %   parsers        - Cell array of strings containing all available parsers.
  %   noParserPrompt - Whether to prompt the user if a parser cannot be found.
  %   mode           - Toolbox data type mode ('profile' or 'timeSeries').
  %
  % Outputs:
  %   sam        - Struct containing sample data.

    % get the appropriate parser function
    parser = getParserFunc(deployment, parsers, noParserPrompt);
    if isnumeric(parser)
      error(['no parser found for instrument ' deployment.InstrumentID]); 
    end

    % parse the data; let errors propagate
    sam = parser(files, mode);
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