function flowManager()
%FLOWMANAGER Manages the overall flow of IMOS toolbox execution and acts as 
% the custodian for all data sets.
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

  rawData      = {};
  autoQCData   = {};
  
  lastAutoQCSetIdx = 0;

  % import data
  [fieldTrip rawData skipped] = importManager();
  
  if isempty(rawData), return; end
  
  % add an index field to each data struct
  for k = 1:length(rawData), rawData{k}.meta.index = k; end

  % display data
  callbacks.importRequestCallback       = @importRequestCallback;
  callbacks.metadataUpdateCallback      = @metadataUpdateCallback;
  callbacks.rawDataRequestCallback      = @rawDataRequestCallback;
  callbacks.autoQCRequestCallback       = @autoQCRequestCallback;
  callbacks.manualQCRequestCallback     = @manualQCRequestCallback;
  callbacks.exportNetCDFRequestCallback = @exportNetCDFRequestCallback;
  callbacks.exportRawRequestCallback    = @exportRawRequestCallback;
  
  displayManager(fieldTrip, rawData, callbacks);
  
  function importRequestCallback()
  %IMPORTREQUESTCALLBACK Called when the user wishes to import more data.
  % Prompts the user to import more data, then adds the new data to the
  % data sets. Forces a run of the auto QC routines over the new data if
  % necessary.
  %
  
    % prompt user to import more data
    [fieldTrip importedData skipped] = importManager();
    
    if isempty(importedData), return; end
    
    % check for and remove duplicates
    remove = [];
    for k = 1:length(importedData)
      for m = 1:length(rawData)
        if strcmp(     rawData{m}.meta.DeploymentData.DeploymentId,...
                  importedData{k}.meta.DeploymentData.DeploymentId)
          remove(end+1) = k;
        end
      end
    end
    
    if ~isempty(remove)
      uiwait(msgbox('Duplicate data sets were removed during the import', ...
             'Duplicate data sets removed', 'modal'));
      importedData(remove) = [];
    end
    
    
    % add index to the newly imported data
    for k = 1:length(importedData)
      importedData{k}.meta.index = k + length(rawData);
    end
    
    % insert the new data into the rawData array, and run QC if necessary
    startIdx = (length(rawData)+1);
    endIdx   = startIdx + length(importedData) - 1;
    rawData = [rawData importedData];
    
    if ~isempty(autoQCData), autoQCRequestCallback(startIdx:endIdx, 0); end
  
  end
              
  function metadataUpdateCallback(sample_data)
  %METADATAUPDATECALLBACK Called whenever a data set's metadata is updated.
  % Synchronizes the change with the local copies of the data sets.
  %
    idx = sample_data.meta.index;
    
    rawData{idx} = sync(sample_data, rawData{idx});
    
    if ~isempty(autoQCData)
      autoQCData{idx} = sync(sample_data, autoQCData{idx}); 
    end
    
    function target = sync(source, target)
      
      vars  = source.variables;
      dims  = source.dimensions;

      % variables
      for k = 1:length(vars)

        vars{k}.data       = target.variables{k}.data;
        vars{k}.dimensions = target.variables{k}.dimensions;
        vars{k}.flags      = target.variables{k}.flags;
        target.variables{k} = vars{k};
      end
      
      % dimensions
      for k = 1:length(dims)

        dims{k}.data  = target.dimensions{k}.data;
        dims{k}.flags = target.dimensions{k}.flags;
        target.dimensions{k} = dims{k};
      end
      
      vars = target.variables;
      dims = target.dimensions;

      target            = source;
      target.variables  = vars;
      target.dimensions = dims;
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
    elseif ~any(setIdx > length(autoQCData)), return;
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
    
    % set level and file version on each QC'd data set
    for k = 1:length(aqc)
      aqc{k}.meta.level = 1; 
      aqc{k}.file_version                 = imosFileVersion(1, 'name');
      aqc{k}.file_version_quality_control = imosFileVersion(1, 'desc');
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
