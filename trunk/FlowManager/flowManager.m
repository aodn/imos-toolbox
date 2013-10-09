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

  rawData      = {};
  autoQCData   = {};
  
  lastAutoQCSetIdx = 0;
  
  % import data
  rawData = importManager(toolboxVersion);
  
  if isempty(rawData), return; end
  
  % add an index field to each data struct
  for k = 1:length(rawData), rawData{k}.meta.index = k; end
  
  % preprocess data
  rawData = preprocessManager(rawData);

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
  % data sets. Forces a run of the auto QC routines over the new data if
  % necessary.
  %
  
    % prompt user to import more data
    importedData = importManager(toolboxVersion);
    
    if isempty(importedData), return; end
    
    % check for and remove duplicates
    remove = [];
    for k = 1:length(importedData)
      for m = 1:length(rawData)
        if strcmp(     rawData{m}.meta.raw_data_file,...
                  importedData{k}.meta.raw_data_file)
          remove(end+1) = k;
        end
      end
    end
    
    if ~isempty(remove)
      uiwait(msgbox('Duplicate data sets were removed during the import', ...
             'Duplicate data sets removed', 'non-modal'));
      importedData(remove) = [];
    end
    
    
    % add index to the newly imported data
    for k = 1:length(importedData)
      importedData{k}.meta.index = k + length(rawData);
    end
    
    % preprocess new data
    importedData = preprocessManager(importedData);
    
    % insert the new data into the rawData array, and run QC if necessary
    startIdx = (length(rawData)+1);
    endIdx   = startIdx + length(importedData) - 1;
    rawData = [rawData importedData];
    
    if ~isempty(autoQCData)
      autoQCRequestCallback(startIdx:endIdx, 0); 
      
      % if user cancelled auto QC process, the autoQCData and rawData arrays
      % will be out of sync; this is bad, so the following is a dirty hack
      % which ensures that the arrays will stay synced.
      if length(autoQCData) ~= length(rawData)
        
        autoQCData(startIdx:endIdx) = importedData;
        
        for k = startIdx:endIdx
          autoQCData{k}.meta.level = 1; 
          autoQCData{k}.file_version = imosFileVersion(1, 'name');
          autoQCData{k}.file_version_quality_control = ...
            imosFileVersion(1, 'desc');
        end
      end
    end
  
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
    lastSetIdx = lastAutoQCSetIdx;
    lastAutoQCSetIdx = setIdx;

    % if QC has not been run before, run QC over every data set
    if isempty(autoQCData)
      
      setIdx = 1:length(rawData);
      sample_data = rawData;
    
    % if just a state  change, return previous QC data
    elseif stateChange, return;
      
    % if QC has already been executed, passed-in set index is the same as 
    % that which was previoously passed, and state has not changed, prompt 
    % user if they want to keep old QC data, or redo QC, for this set only
    elseif lastSetIdx == setIdx
      
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
        setIdx = 1:length(rawData);
      end
    
    % otherwise if no new data sets, return the existing auto QC data
    elseif ~any(setIdx > length(autoQCData))
        return;
    end
    
    % save data set selection
    lastSetIdx = setIdx;

    % run QC routines over raw data
    aqc = autoQCManager(rawData(setIdx));
    
    % if user interrupted process, return either raw data or old QC data
    if isempty(aqc)
      if isempty(autoQCData), aqc = rawData; 
      else                    return; 
      end
    end
        
    % otherwise return new QC data
    autoQCData(setIdx) = aqc;
    sample_data = autoQCData;
  end

  function manualQCRequestCallback(setIdx, varIdx, dataIdx, flag)
  %MANUALQCREQUESTCALLBACK Called on a request to manually
  % modify/add/delete flags on a portion of a data set.
  %
  % Inputs:
  %   setIdx  - 
  %   varIdx  - 
  %   dataIdx -
  %   flag    -
  %
    if isempty(autoQCData), return; end
    
    autoQCData{setIdx}.variables{varIdx}.flags(dataIdx) = flag;
    
    qcSet = str2double(readProperty('toolbox.qc_set'));
    rawFlag = imosQCFlag('raw', qcSet, 'flag');
    
    % add a log entry if the user has added flags
    if ~isempty(dataIdx) && flag ~= rawFlag
      
      autoQCData{setIdx}.meta.log{end+1} = ...
        ['Author flagged ' num2str(length(dataIdx)) ...
         ' ' autoQCData{setIdx}.variables{varIdx}.name ...
         ' samples: ' num2str(flag)];
    end
  end

  function exportNetCDFRequestCallback()
  %EXPORTNETCDFREQUESTCALLBACK Called on a request to export data to NetCDF
  % files. Passes the data to the export manager.
  %
  
    data = {};
    names = {};
    if isempty(autoQCData)
      data = {rawData}; 
      names = {'Raw'};
    else
      data = {rawData autoQCData};
      names = {'Raw', 'QC'};
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
