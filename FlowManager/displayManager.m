function displayManager(windowTitle, sample_data, callbacks)
%DISPLAYMANGER Manages the display of data.
%
% The display manager handles the interaction between the main window and
% the rest of the toolbox. It defines what is displayed in the main window,
% and how the system reacts when the user interacts with the main window.
%
% Inputs:
%   windowTitle - String to be used as main window title.
%   sample_data - Cell array of sample_data structs, one for each instrument.
%   callbacks   - struct containing the following function handles:
%     importRequestCallback       - Callback function which is called when
%                                   the user requests to import more data.
%                                   Takes no parameters.
%     metadataUpdateCallback      - Callback function which is called when a 
%                                   data set's metadata is modified. Takes
%                                   a single sample_data struct as the only
%                                   parameter.
%     metadataRepCallback         - Callback function which is called when
%                                   a set of metadata fields should be
%                                   replicated across all loaded data sets.
%                                   Takes a location string, and cell arrays 
%                                   of field names and values as the three 
%                                   parameters.
%     rawDataRequestCallback      - Callback function which is called to 
%                                   retrieve the raw data set. Takes no
%                                   parameters.
%     autoQCRequestCallback       - Callback function called when the user 
%                                   attempts to execute an automatic QC 
%                                   routine. Takes two parameters, setIdx
%                                   (index into current sample_data
%                                   struct). and stateChange (logical, to
%                                   determine whether to prompt the user
%                                   to (re-)run auto QC routines over the
%                                   data).
%     manualQCRequestCallback     - Callback function called when the user 
%                                   attempts to execute a manual QC
%                                   routine. Takes four parameters: setIdx 
%                                   (sample_data index), varIdx (variable 
%                                   index), dataIdx (data indices), flag (flag 
%                                   value).
%     exportNetCDFRequestCallback - Callback function called when the user 
%                                   attempts to export data. Takes no
%                                   parameters.
%     exportRawRequestCallback    - Callback function called when the user
%                                   attempts to export raw data. Takes no
%                                   parameters.
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
  error(nargchk(3,3,nargin));

  if ~ischar(windowTitle), error('windowTitle must be a string');     end
  if ~iscell(sample_data), error('sample_data must be a cell array'); end
  if isempty(sample_data), error('sample_data is empty');             end
  if ~isstruct(callbacks), error('callbacks must be a struct');       end

  if ~isa(callbacks.importRequestCallback, 'function_handle')
    error('importRequestCallback must be a function handle'); 
  end
  if ~isa(callbacks.metadataUpdateCallback, 'function_handle')
    error('metadataUpdateCallback must be a function handle'); 
  end
  if ~isa(callbacks.metadataRepCallback, 'function_handle')
    error('metadataRepCallback must be a function handle'); 
  end
  if ~isa(callbacks.rawDataRequestCallback, 'function_handle')
    error('rawDataRequestCallback must be a function handle'); 
  end
  if ~isa(callbacks.autoQCRequestCallback, 'function_handle')
    error('autoQCRequestCallback must be a function handle'); 
  end
  if ~isa(callbacks.manualQCRequestCallback, 'function_handle')
    error('manualQCRequestCallback must be a function handle'); 
  end
  if ~isa(callbacks.exportNetCDFRequestCallback, 'function_handle')
    error('exportNetCDFRequestCallback must be a function handle'); 
  end
  if ~isa(callbacks.exportRawRequestCallback, 'function_handle')
    error('exportRawRequestCallback must be a function handle'); 
  end
  
  lastState  = '';
  lastSetIdx = [];
  lastVars   = [];
  qcSet      = str2double(readProperty('toolbox.qc_set'));
  rawFlag    = imosQCFlag('raw', qcSet, 'flag');
  
  % define the user options, and create the main window
  states = {'Import', 'Metadata', 'Raw data', 'QC data', 'QC stats' ...
            'Export NetCDF', 'Export Raw'};

  mainWindow(windowTitle, sample_data, states, 3, @stateSelectCallback);
      
  function state = stateSelectCallback(event,...
    panel, updateCallback, state, sample_data, graphType, setIdx, vars)
  %STATESELECTCALLBACK Called when the user interacts with the main 
  % window, by changing the state, the selected data set, the selected
  % variables or the selected graph type.
  %
  % Inputs:
  %   event          - String describing what triggered the callback.
  %   panel          - uipanel on which things can be drawn.
  %   updateCallback - function to be called when data is modified.
  %   state          - selected state (string).
  %   sample_data    - Cell array of sample_data structs
  %   graphType      - currently selected graph type (string).
  %   setIdx         - currently selected sample_data struct (index)
  %   vars           - currently selected variables (indices).
  %
  % Outputs:
  %   state          - If a state change was forced, tells the main window
  %                    to update its own state.
  %
  
    switch(state)
      case 'Import',          importCallback();
      case 'Metadata',        metadataCallback();
      case 'Raw data',        rawDataCallback();
      case 'QC data',         qcDataCallback();
      case 'QC stats',        qcStatsCallback();
      case 'Export NetCDF',   exportNetCDFCallback();
      case 'Export Raw',      exportRawCallback();
    end
    
    lastState  = state;
    lastSetIdx = setIdx;
    
    function importCallback()
    %IMPORTCALLBACK Called when the user clicks the 'Import' button. Calls
    %the importRequestCallback function.
    %
      callbacks.importRequestCallback();
      
      switch (lastState)
        case 'Raw data'
          sample_data = callbacks.rawDataRequestCallback();
        case {'QC data', 'QC stats'}
          sample_data = callbacks.autoQCRequestCallback(0, true);
        otherwise
          sample_data = callbacks.rawDataRequestCallback();
      end
      
      for k = 1:length(sample_data), updateCallback(sample_data{k}); end
      
      stateSelectCallback('state', panel, updateCallback, lastState, ...
        sample_data, graphType, setIdx, vars);
      state = lastState;
    end
  
    function metadataCallback()
    %METADATACALLBACK Displays a metadata viewer/editor for the selected 
    % data set.
    %
    
      % get the toolbox execution mode. Values can be 'timeSeries' and 'profile'.
      % If no value is set then default mode is 'timeSeries'
      mode = lower(readProperty('toolbox.mode'));
    
      % display metadata viewer, allowing user to modify metadata
      viewMetadata(panel, sample_data{setIdx}, ...
        @metadataUpdateWrapperCallback,...
        @metadataRepWrapperCallback, mode);

      function metadataUpdateWrapperCallback(sam)
      %METADATAUPDATEWRAPPERCALLBACK Called by the viewMetadata display when
      % metadata is updated. Calls the two subsequent metadata callback
      % functions (mainWindow and flowManager).

        % notify of change to metadata
        callbacks.metadataUpdateCallback(sam);

        sam = populateMetadata(sam);
        
        % update GUI with modified data set
        updateCallback(sam);
      end
      
      function metadataRepWrapperCallback(location, fields, values)
      %REPWRAPPERCALLBACK Called on a request to replicate a set of
      % metadata attributes across all data sets. Calls the provided
      % repCallback function.
      %
      
        callbacks.metadataRepCallback(location, fields, values);
                
        % update GUI with new data sets
        sample_data = callbacks.rawDataRequestCallback();
        for k = 1:length(sample_data), updateCallback(sample_data{k}); end
        
      end
    end

    function rawDataCallback()
    %RAWDATACALLBACK Displays raw data for the the current data set, using
    %the current graph type.
    %
      % retrieve raw data on state change - if state was already raw data,
      % main window already has the correct data set.
      if ~strcmp(lastState, state)
        
        sample_data = callbacks.rawDataRequestCallback();

        % update GUI with raw data set
        for k = 1:length(sample_data), updateCallback(sample_data{k}); end
      end

      % display selected raw data
      try
        graphFunc = getGraphFunc(graphType, 'graph', '');
        graphFunc(panel, sample_data{setIdx}, vars);
      catch e
        errorString = getErrorString(e);
        fprintf('%s\n',   ['Error says : ' errorString]);
        
        errordlg(...
          ['Could not display this data set using ' graphType ...
           ' (' e.message '). Try a different graph type.' ], ...
           'Graphing Error');
      end
    end

    function qcDataCallback()
    %QCCALLBACK Displays QC'd data for the current data set, using the
    % current graph type. If the state has changed, the autoQCRequestCallback
    % function is called, which may trigger auto-QC routines to be
    % executed. Adds callback functions to the figure allowing the user to
    % interact with the graph (highlighting data/flags and 
    % adding/modifying/removing flags).
    %
    
      % update qc data on state change
      if strcmp(event, 'state')
          
        sample_data = ...
          callbacks.autoQCRequestCallback(setIdx, ~strcmp(lastState,state));

        % update GUI with QC'd data set
        for k = 1:length(sample_data), updateCallback(sample_data{k}); end
      end

      % redisplay the data
      try 
        graphFunc = getGraphFunc(graphType, 'graph', '');
        try flagFunc  = getGraphFunc(graphType, 'flag',  '');
        catch e
          flagFunc = [];
        end
        
        [graphs lines vars] = graphFunc(panel, sample_data{setIdx}, vars);
        
        if isempty(flagFunc)
          warning(['Cannot display QC flags using ' graphType ...
                   '. Try a different graph type.']);
          return;
        else
          flags = flagFunc( panel, graphs, sample_data{setIdx}, vars);
        end
        
      catch e
        errorString = getErrorString(e);
        fprintf('%s\n',   ['Error says : ' errorString]);
        
        errordlg(...
          ['Could not display this data set using ' graphType ...
           ' (' e.message '). Try a different graph type.' ], ...
           'Graphing Error');
         return;
      end

      % save line handles and index in axis userdata 
      % so the data select callback can retrieve them
      for k = 1:length(graphs)
        
        set(graphs(k), 'UserData', {lines(k), k});
      end

      % add data selection functionality
      highlight = [];
      selectFunc = getGraphFunc(graphType, 'select', '');
      selectFunc(@dataSelectCallback, @dataClickCallback);

      function dataSelectCallback(ax, type, range)
      %DATASELECTCALLBACK Called when the user selects a region of data.
      % Highlights the selected region.
      %
        % line handles are stored in the axis userdata
        ud = get(ax, 'UserData');
        
        handle = ud{1};
        varIdx = ud{2};

        % remove any previous highlight
        if ~isempty(highlight)
          delete(highlight); 
          highlight = [];
        end

        % highlight the data, save the handle and data indices
        highlightFunc = getGraphFunc(graphType, 'highlight',...
          sample_data{setIdx}.variables{vars(varIdx)}.name);
        highlight = highlightFunc(...
          range, handle, sample_data{setIdx}.variables{vars(varIdx)}, type);
      end
      
      function dataClickCallback(ax, type, point)
      %DATACLICKCALLBACK On a click, if on a highlighted region, displays 
      % a dialog allowing the user to add/modify QC flags for that region. 
      % Otherwise, the highlighted region is cleared. 
      %
        if isempty(highlight), return; end

        % line/flag handles are stored in the axis userdata
        ud = get(ax, 'UserData');
        
        % index into vars vector, telling us which 
        % variable is on the axis in question
        varIdx = ud{2};
        
        % get the click point
        point = get(ax, 'CurrentPoint');
        point = point([1 3]);
        
        % get the indices of the data which was clicked on
        getSelectedFunc = getGraphFunc(graphType, 'getSelected', ...
          sample_data{setIdx}.variables{vars(varIdx)}.name);
        dataIdx = getSelectedFunc(...
          sample_data{setIdx}, vars(varIdx), ax, highlight, point);

        % is there data to flag?
        if ~isempty(dataIdx)

          % find the most frequently occuring flag value to 
          % pass to the flag dialog (to use as the default)
          flag = sample_data{setIdx}.variables{vars(varIdx)}.flags(dataIdx);
          flag = mode(double(flag));
          
          % popup flag modification dialog
          flag = addFlagDialog(flag);
          
          % if user didn't cancel, apply the new flag value to the data
          if ~isempty(flag)
            callbacks.manualQCRequestCallback(setIdx,vars(varIdx),dataIdx,flag);
            sample_data = callbacks.autoQCRequestCallback(setIdx, true);
            
            % update main window with modified data set
            updateCallback(sample_data{setIdx});
            
            % update graph
            if ~isempty(flags), delete(flags(flags ~= 0)); end
            flags = flagFunc(panel, graphs, sample_data{setIdx}, vars);
          end
        end
          
        % remove the highlight, regardless of the click location
        delete(highlight); 
        highlight = [];
      end
    end
    
    function qcStatsCallback()
    %QCSTATSCALLBACK Displays a QC statistic viewer for the selected 
    % data set.
    %
    
      % update qc data on state change
      if strcmp(event, 'state')
        
        sample_data = ...
            callbacks.autoQCRequestCallback(setIdx, ~strcmp(lastState,state));
      end
      
      % get the toolbox execution mode. Values can be 'timeSeries' and 'profile'.
      % If no value is set then default mode is 'timeSeries'
      mode = lower(readProperty('toolbox.mode'));
    
      % display QC stats viewer
      viewQCstats(panel, sample_data{setIdx}, mode);
%       viewMetadata(panel, sample_data{setIdx}, ...
%         @metadataUpdateWrapperCallback,...
%         @metadataRepWrapperCallback, mode);
    end
    
    function exportNetCDFCallback()
    %EXPORTNETCDFCALLBACK Called when the user clicks on the 'Export NetCDF' 
    % button. Delegates to the exportNetCDFRequestCallback function.
    %
      callbacks.exportNetCDFRequestCallback();
      
      stateSelectCallback('', panel, updateCallback, lastState, ...
        sample_data, graphType, setIdx, vars);
      state = lastState;
    end
    
    function exportRawCallback()
    %EXPORTRAWCALLBACK Called when the user clicks on the 'Export Raw'
    % button. Delegates to the exportRawRequestCallback function.
    %
      callbacks.exportRawRequestCallback();
      
      stateSelectCallback('', panel, updateCallback, lastState, ...
        sample_data, graphType, setIdx, vars);
      state = lastState;
    end
  end
end
