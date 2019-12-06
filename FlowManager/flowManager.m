function flowManager(toolboxVersion)
%FLOWMANAGER Manages the overall flow of IMOS toolbox execution and acts as 
% the custodian for all data sets.
%
% Inputs:
%   toolboxVersion      - string containing the current version of the toolbox.
%
% Author:       Paul McCarthy <paul.mccarthy@csiro.au>
% Contributor:  Guillaume Galibert <guillaume.galibert@utas.edu.au>
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

  rawData      = {};
  autoQCData   = {};
  
  lastAutoQCSetIdx = 0;
  
  % get the toolbox execution mode
  mode = readProperty('toolbox.mode');
  
  % import data
  nonUTCRawData = importManager(toolboxVersion);
  
  if isempty(nonUTCRawData), return; end
  
  % add an index field to each data struct
  for k = 1:length(nonUTCRawData), nonUTCRawData{k}.meta.index = k; end
  
  % preprocess data
  [autoQCData, cancel] = preprocessManager(nonUTCRawData, 'qc', mode, false);
  if cancel
      rawData = nonUTCRawData;
  else
      rawData = preprocessManager(nonUTCRawData, 'raw',  mode, true);  % only apply TIME to UTC conversion pre-processing routines, auto is true so that GUI only appears once
  end
  clear nonUTCRawData;
  
  % display data
  callbacks.importRequestCallback       = @importRequestCallback;
  callbacks.metadataUpdateCallback      = @metadataUpdateCallback;
  callbacks.metadataRepCallback         = @metadataRepCallback;
  callbacks.rawDataRequestCallback      = @rawDataRequestCallback;
  callbacks.autoQCRequestCallback       = @autoQCRequestCallback;
  callbacks.manualQCRequestCallback     = @manualQCRequestCallback;
  callbacks.exportNetCDFRequestCallback = @exportNetCDFRequestCallback;
  callbacks.exportRawRequestCallback    = @exportRawRequestCallback;
  
  displayManager(['imos-toolbox v' toolboxVersion], rawData, callbacks);
  
  function importRequestCallback()
  %IMPORTREQUESTCALLBACK Called when the user wishes to import more data.
  % Prompts the user to import more data, then adds the new data to the
  % data sets. Forces a run of the PP and QC routines over the new data if
  % necessary.
  %
  
    % prompt user to import more data
    importedNonUTCRawData = importManager(toolboxVersion);
    
    if isempty(importedNonUTCRawData), return; end
    
    % check for and remove duplicates
    remove = [];
    for i = 1:length(importedNonUTCRawData)
      for m = 1:length(rawData)
        if strcmp(     rawData{m}.meta.raw_data_file,...
                  importedNonUTCRawData{i}.meta.raw_data_file)
          remove(end+1) = i;
        end
      end
    end
    
    if ~isempty(remove)
      uiwait(msgbox('Duplicate data sets were removed during the import', ...
             'Duplicate data sets removed', 'non-modal'));
      importedNonUTCRawData(remove) = [];
    end
    
    
    % add index to the newly imported data
    for i = 1:length(importedNonUTCRawData)
      importedNonUTCRawData{i}.meta.index = i + length(rawData);
    end
    
    % preprocess new data
    [importedAutoQCData, importedCancel] = preprocessManager(importedNonUTCRawData, 'qc', mode, false);
    if importedCancel
        importedRawData = importedNonUTCRawData;
    else
        importedRawData = preprocessManager(importedNonUTCRawData, 'raw',  mode, true);  % only apply TIME to UTC conversion pre-processing routines, auto is true so that GUI only appears once
    end
    clear importedNonUTCRawData;
    
    % insert the new data into the rawData array, and run QC if necessary
    startIdx = length(rawData) + 1;
    endIdx   = startIdx + length(importedRawData) - 1;
    rawData     = [rawData importedRawData];
    autoQCData  = [autoQCData importedAutoQCData];
    clear importedAutoQCData;
    
    if autoQCData{startIdx - 1}.meta.level == 1 % previously imported datasets have been QC'd already
      autoQCRequestCallback(startIdx:endIdx, 0); 
      
      % if user cancelled auto QC process, the autoQCData and rawData arrays
      % will be out of sync; this is bad, so the following is a dirty hack
      % which ensures that the arrays will stay synced.
      if length(autoQCData) ~= length(rawData)
        
        autoQCData(startIdx:endIdx) = importedRawData;
        
        for i = startIdx:endIdx
          autoQCData{i}.meta.level = 1; 
          autoQCData{i}.file_version = imosFileVersion(1, 'name');
          autoQCData{i}.file_version_quality_control = ...
            imosFileVersion(1, 'desc');
        end
      end
    end
    clear importedRawData;
  end
              
  function metadataUpdateCallback(sample_data)
  %METADATAUPDATECALLBACK Called whenever a data set's metadata is updated.
  % Synchronizes the change with the local copies of the data sets.
  %
    idx = sample_data.meta.index;
    
    sample_data = populateMetadata(sample_data);
    rawData{idx} = sync(sample_data, rawData{idx});
    
    if ~isempty(autoQCData)
      autoQCData{idx} = sync(sample_data, autoQCData{idx}); 
    end
    clear sample_data;
    
    function updatedTarget = sync(source, target)

      updatedTarget = source;
      % all information from source is copied to target
      % except for :
      % -file_version
      % -file_version_quality_control
      % -meta.level
      % -meta.log
      % -variables.data
      % -variables.dimensions
      % -variables.flags
%       % -dimensions.data      these fields can be updated by metadata
      % -dimensions.flags

      updatedTarget.file_version                   = target.file_version;
      updatedTarget.file_version_quality_control   = target.file_version_quality_control;
      
      % meta
      updatedTarget.meta.level                          = target.meta.level;
      updatedTarget.meta.log                            = target.meta.log;
      
      % variables
      nVar = length(target.variables);
      for k = 1:nVar
        updatedTarget.variables{k}.data       = target.variables{k}.data;
        updatedTarget.variables{k}.dimensions = target.variables{k}.dimensions;
        updatedTarget.variables{k}.flags      = target.variables{k}.flags;
      end
      
      % dimensions
      nDim = length(target.dimensions);
      for k = 1:nDim
%         updatedTarget.dimensions{k}.data  = target.dimensions{k}.data;
        if isfield(target.dimensions{k}, 'flags'), updatedTarget.dimensions{k}.flags = target.dimensions{k}.flags; end
      end
    end
  end

  function metadataRepCallback(location, fields, values)
  %METADATAREPCALLBACK Replicates the given metadata attributes across all
  % loaded data sets. Does nothing if only one data set is loaded.
  %
    if length(rawData) <= 1, return; end
    
    response = questdlg(...
      ['Replicate the selected ' location ...
       ' attributes across all data sets?'],...
      'Replicate attributes?', ...
      'Yes', ...
      'No',...
      'Yes');

    if ~strncmp(response, 'Yes', 3), return; end
    
    for k = 1:length(rawData)
      rawData{k} = replicate(rawData{k}); 
    end
    
    if ~isempty(autoQCData)
      for k = 1:length(autoQCData)
        autoQCData{k} = replicate(autoQCData{k}); 
      end
    end
    
    function sam = replicate(sam)
    % Copies the given fields/values into sam.
      
      % target is either global attributes (sam itself), 
      % or variable/dimension attributes (one of the 
      % variable/dimension structs contained in sam)
      % targetIdx is the variable/dimension index, if 
      % the target is a variable/dimension
      target    = 0;
      targetIdx = 0;
      
      if strcmp(location, 'global'), target = sam;
      else
        
        list = {};
        if     strfind(location, 'variable'),  list = sam.variables;
        elseif strfind(location, 'dimension'), list = sam.dimensions;
        end
        
        vname     = strtok(location);
        targetIdx = getVar(list, vname);
        
        % this data set does not contain this variable/dimension
        if targetIdx == 0, return; end
        
        target = list{targetIdx};
      end
      
      % copy the field values across
      for m = 1:length(fields)
        
        % but only if the field exists in the target
        if isfield(target, fields{m}), target.(fields{m}) = values{m}; end
      end
      
      % copy the target back to the input struct
      if     strcmp( location, 'global'),    sam = target;
      elseif strfind(location, 'variable'),  sam.variables{ targetIdx} = target;
      elseif strfind(location, 'dimension'), sam.dimensions{targetIdx} = target;
      end
    end
  end

  function sample_data = rawDataRequestCallback()
  %RAWDATAREQUESTCALLBACK Called when raw data is needed. Returns the raw
  %data set.
  %
    sample_data = rawData;
  end
  
  function sample_data = autoQCRequestCallback(setIdx, stateChange)
  %AUTOQCREQUESTCALLBACK Called when the user chooses to run auto QC
  % routines over the data. Delegates to the autoQCManager. The first time
  % this function is called, the QC routines are executed over every data
  % set. On subsequent calls, if the provided stateChange parameter is true,
  % the existing QC data is returned. Otherwise, if the provided setIdx 
  % parameter is the same as that previously passed in, the routines are 
  % only executed on the set with the given index, and only after the user 
  % confirms that they wish to overwrite the previous QC modifications.
  %
    sample_data = autoQCData;
    
    % save data set selection
    lastAutoQCSetIdx = setIdx;

    qcLevel = cellfun(@(x) x(:).meta.level, autoQCData, 'UniformOutput', false);
    qcLevel = [qcLevel{:}];
    
    % if QC has not been run before, run QC over every data set
    if all(qcLevel == 0)

        setIdx = 1:length(sample_data);
        
    % if just a state change, return previous QC data
    elseif stateChange, return;
        
    % if QC has already been executed, prompt
    % user if they want to keep old QC data, or redo QC, for this set only
    elseif all(qcLevel == 1)
        
        response = questdlg(...
            ['Re-run auto-QC routines '...
            '(existing flags/mods will be discarded)?'],...
            'Re-run QC Routines?', ...
            'No', ...
            'Re-run for this data set',...
            'Re-run for all data sets',...
            'No');
        
        if ~strncmp(response, 'Re-run', 6), return; end
        
        if strcmp(response, 'Re-run for all data sets')
            setIdx = 1:length(sample_data);
        end
        
    end

    % run QC routines over raw data
    aqc = autoQCManager(sample_data(setIdx));
    
    % if user interrupted process, return either pre-processed data (if no QC performed yet) or old QC data
    if isempty(aqc)
      aqc = autoQCData(setIdx);
    end
        
    % otherwise return new QC data
    autoQCData(setIdx) = aqc;
    sample_data = autoQCData;
  end

  function manualQCRequestCallback(setIdx, varIdx, dataIdx, flag, manualQcComment)
  %MANUALQCREQUESTCALLBACK Called on a request to manually
  % modify/add/delete flags on a portion of a data set.
  %
  % Inputs:
  %   setIdx  - index of sample_data
  %   varIdx  - index of variable
  %   dataIdx - indices of data
  %   flag    - flag values to be assigned for the indices of data
  %   manualQcComment - Author manual QC comment
  %
    if isempty(autoQCData), return; end
    
    % we update the flags values
    autoQCData{setIdx}.variables{varIdx}.flags(dataIdx) = flag;
    
    qcSet = str2double(readProperty('toolbox.qc_set'));
    rawFlag = imosQCFlag('raw', qcSet, 'flag');
    
    % add a log entry if the user has added flags
    if ~isempty(dataIdx) && flag ~= rawFlag
        
        % add an attribute comment to the ancillary variable if the user has added
        % a comment
        if ~isempty(manualQcComment)
            % merge with previous comments
            if isfield(autoQCData{setIdx}.variables{varIdx}, 'ancillary_comment')
                if ~isempty(autoQCData{setIdx}.variables{varIdx}.ancillary_comment)
                    autoQCData{setIdx}.variables{varIdx}.ancillary_comment = strrep([autoQCData{setIdx}.variables{varIdx}.ancillary_comment, '. ', manualQcComment], '.. ', '. ');
                else
                    autoQCData{setIdx}.variables{varIdx}.ancillary_comment = manualQcComment;
                end
            else
                autoQCData{setIdx}.variables{varIdx}.ancillary_comment = manualQcComment;
            end
        end
        
        autoQCData{setIdx}.meta.log{end+1} = ...
            ['Author manually flagged ' num2str(length(dataIdx)) ...
            ' ' autoQCData{setIdx}.variables{varIdx}.name ...
            ' samples with flag ' imosQCFlag(flag,  qcSet, 'desc')];
    end
  end

  function exportNetCDFRequestCallback()
  %EXPORTNETCDFREQUESTCALLBACK Called on a request to export data to NetCDF
  % files. Passes the data to the export manager.
  %
  
    data = {};
    names = {};
    if ~isempty(rawData)
      data = {rawData}; 
      names = {'Raw'};
    end
    if autoQCData{1}.meta.level == 1
      data = [data {autoQCData}];
      names = [names, {'QC'}];
    end
    
    exportManager(data, names, 'netcdf');
  end

  function exportRawRequestCallback()
  %EXPORTRAWREQUESTCALLBACK Called on a request to export data to raw
  % files. Passes the raw data to the export manager.
  %
  
    data  = {rawData};
    names = {'raw'};
    
    exportManager(data, names, 'raw');
  end
end
