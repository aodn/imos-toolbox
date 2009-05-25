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
% POSSIBILITY OF SUCH DAMAGE.`
  rawData      = {};
  autoQCData   = {};
  manualQCData = {};

  % import data
  [fieldTrip rawData skipped] = importManager();
  
  % add an index field to each data struct
  for k = 1:length(rawData), rawData{k}.index = k; end

  % display data
  displayManager(fieldTrip, rawData,...
                @metadataUpdateCallback,...
                @rawDataRequestCallback,...
                @autoQCRequestCallback,...
                @manualQCRequestCallback,...
                @exportRequestCallback);
              
  function metadataUpdateCallback(sample_data)
  %METADATAUPDATECALLBACK Called whenever a data set's metadata is updated.
  % Synchronizes the change with the local copies of the data sets.
  %
    idx = sample_data.index;
    
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

        dims{k}.data = target.dimensions{k}.data;
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

  function sample_data = autoQCRequestCallback()
  %AUTOQCREQUESTCALLBACK Called when the user chooses to run auto QC
  % routines over the data. Delegates to the autoQCManager.
  %
    sample_data = autoQCData;
    
    qcPrompt = true;
    try
      qcPrompt = str2num(readToolboxProperty('flowManager.qcPrompt'));
    catch e
    end
    
    % if QC has already been executed prompt user if they want to keep old
    % QC data, or redo QC
    if ~isempty(autoQCData) 
      
      % user can disable prompt via qcPrompt toolbox property - data is
      % never overwritten
      if ~qcPrompt, return; end
      
      response = questdlg(...
        'Re-run auto-QC routines (existing flags/mods will be discarded)?');
      
      if ~strcmp(response, 'Yes'), return; end
    end

    % run QC routines over raw data
    autoQCData = autoQCManager(rawData);
    sample_data = autoQCData;
  end

  function manualQCRequestCallback()
    disp('manualQCRequestCallback');

    %qcd_data = manualQCManager(selected_qc_routine data);
    %display(qcd_data);

  end

  function exportRequestCallback()
    disp('exportRequestCallback');

    %for d in data
    %  exportNetCDF(d);
  end
end
