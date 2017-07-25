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
  narginchk(3,3);

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
  qcSet      = str2double(readProperty('toolbox.qc_set'));
  badFlag    = imosQCFlag('bad', qcSet, 'flag');
  
  % get the toolbox execution mode
  mode = readProperty('toolbox.mode');
  
  % define the user options, and create the main window
  states = {'Import', 'Metadata', 'Raw data', 'QC data', 'QC stats', 'Reset manual QC' ...
            'Export NetCDF', 'Export Raw'};

  mainWindow(windowTitle, sample_data, states, 3, @stateSelectCallback);
      
  function state = stateSelectCallback(event,...
    panel, updateCallback, state, sample_data, graphType, setIdx, vars, extraSetIdx)
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
  %   extraSetIdx    - currently selected extra sample_data struct (index)
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
      case 'Reset manual QC', resetManQCCallback();
      case 'Export NetCDF',   exportNetCDFCallback();
      case 'Export Raw',      exportRawCallback();
    end
    
    lastState  = state;
    
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
      
      switch(lastState)
          case 'Metadata',        metadataCallback();
          case 'Raw data',        rawDataCallback();
          case 'QC data',         qcDataCallback();
          case 'QC stats',        qcStatsCallback();
          otherwise,              rawDataCallback();
      end
      state = lastState;
    end
  
    function metadataCallback()
    %METADATACALLBACK Displays a metadata viewer/editor for the selected 
    % data set.
    %
    
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

      % we remove potentially variables that don't exist from qc to raw
      switch mode
          case 'profile'
              nVar = length(sample_data{setIdx}.variables) - 5;
          case 'timeSeries'
              nVar = length(sample_data{setIdx}.variables) - 3;
      end
      vars(vars > nVar) = [];
      
      if extraSetIdx
          extra_sample_data = sample_data{extraSetIdx};
      else
          extra_sample_data = [];
      end
    
      % display selected raw data
      graphs = [];
      try
        graphFunc = getGraphFunc(graphType, 'graph', '');
        [graphs, lines, vars] = graphFunc(panel, sample_data{setIdx}, vars, extra_sample_data);
      catch e
        errorString = getErrorString(e);
        fprintf('%s\n',   ['Error says : ' errorString]);
        
        errordlg(...
          ['Could not display this data set using ' graphType ...
           ' (' e.message '). Try a different graph type.' ], ...
           'Graphing Error');
      end
      
      % save line handles and index in axis userdata 
      % so the data select callback can retrieve them
      if ~isempty(graphs)
          for k = 1:length(graphs)
              set(graphs(k), 'UserData', {lines(k,:), k});
          end
      end
      
      % add data selection functionality
      selectFunc = getGraphFunc(graphType, 'select', '');
      selectFunc(@dataSelectCallbackDoNothing, @dataClickCallback);
      
      function dataClickCallback(ax, type, point)
      %DATACLICKCALLBACK Called when the user clicks on a region of data.
      %
          if ~strcmpi(type, 'normal'), return; end
          
          % line handles are stored in the axis userdata
          ud = get(ax, 'UserData');

          varIdx = ud{2};
          
          varName = sample_data{setIdx}.variables{vars(varIdx)}.name;
          
          graphFunc = getGraphFunc(graphType, 'graph', varName);
          if strcmpi(func2str(graphFunc), 'graphTimeSeriesTimeDepth')
              lineMooring2DVarSection(sample_data{setIdx}, varName, point(1), false, false, '')
          end
      end
      
      function dataSelectCallbackDoNothing(ax, type, range)
      %DATASELECTCALLBACKDONOTHING
      
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
        stateChanged = ~strcmp(lastState,state);
        if strcmpi(state, 'Reset Manual QC')
            stateChanged = false; % we override stateChanged so that QC is re-ran as soon as we hit the button
        end
        
        if ~stateChanged, resetPropQCCallback(); end % since QC is going to be re-ran, suggest to reset QC properties
        
        sample_data = ...
          callbacks.autoQCRequestCallback(setIdx, stateChanged);

        % update GUI with QC'd data set
        for k = 1:length(sample_data), updateCallback(sample_data{k}); end

      end
      
      if extraSetIdx
          extra_sample_data = sample_data{extraSetIdx};
      else
          extra_sample_data = [];
      end

      % redisplay the data
      try 
        graphFunc = getGraphFunc(graphType, 'graph', '');
        try flagFunc  = getGraphFunc(graphType, 'flag',  '');
        catch e
          flagFunc = [];
        end
        
        [graphs, lines, vars] = graphFunc(panel, sample_data{setIdx}, vars, extra_sample_data);
        
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
        
        set(graphs(k), 'UserData', {lines(k,:), k});
      end

      % add data selection functionality
      highlight = [];
      selectFunc = getGraphFunc(graphType, 'select', '');
      selectFunc(@dataSelectCallback, @dataClickCallback);

      function dataClickCallback(ax, type, point)
      %DATACLICKCALLBACK Called when the user clicks on a region of data.
      %
          if ~strcmpi(type, 'normal'), return; end
          
          % line handles are stored in the axis userdata
          ud = get(ax, 'UserData');

          varIdx = ud{2};
          
          varName = sample_data{setIdx}.variables{vars(varIdx)}.name;
          
          graphFunc = getGraphFunc(graphType, 'graph', varName);
          if strcmpi(func2str(graphFunc), 'graphTimeSeriesTimeDepth')
              lineMooring2DVarSection(sample_data{setIdx}, varName, point(1), true, false, '')
          end
      end
      
      function dataSelectCallback(ax, type, range)
      %DATASELECTCALLBACK Called when the user selects a region of data.
      % Highlights the selected region. If points are this region, displays 
      % a dialog allowing the user to add/modify QC flags for that region. 
      % Otherwise, the highlighted region is cleared.
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

        if isempty(highlight), return; end

        % line/flag handles are stored in the axis userdata
        ud = get(ax, 'UserData');
        
        % index into vars vector, telling us which 
        % variable is on the axis in question
        varIdx = ud{2};
        
        % get the indices of the data which was highlighted
        getSelectedFunc = getGraphFunc(graphType, 'getSelected', ...
          sample_data{setIdx}.variables{vars(varIdx)}.name);
        dataIdx = getSelectedFunc(...
          sample_data{setIdx}, vars(varIdx), ax, highlight);

        % is there any data point to flag?
        if ~isempty(dataIdx)

          % find the most frequently occuring flag value to 
          % pass to the flag dialog (to use as the default)
%           flag = sample_data{setIdx}.variables{vars(varIdx)}.flags(dataIdx);
%           flag = mode(double(flag));
          flag = badFlag;
          
          % popup flag modification dialog
          [kVar, flag, comment] = addFlagDialog(sample_data{setIdx}.variables, vars(varIdx), flag);
          
          % if user didn't cancel, apply the new flag value to the data
          if ~isempty(flag)
              flagStr = imosQCFlag(flag,  qcSet, 'desc');
              for i=1:length(kVar)
                  % add an attribute comment to the ancillary variable if the user has added
                  % a comment
                  manualQcComment = '';
                  if ~isempty(comment)
                      % we get the first dimension (either TIME or DEPTH for timeSeries or
                      % profile)
                      iDim1 = sample_data{setIdx}.variables{kVar(i)}.dimensions(1);
                      nameDim1 = sample_data{setIdx}.dimensions{iDim1}.name;
                      dataDim1 = sample_data{setIdx}.dimensions{iDim1}.data;
                      
                      if length(sample_data{setIdx}.variables{kVar(i)}.dimensions) > 1
                          iDim2 = sample_data{setIdx}.variables{kVar(i)}.dimensions(2);
                          nDim2 = length(sample_data{setIdx}.dimensions{iDim2}.data);
                          
                          dataDim1 = repmat(dataDim1, nDim2, 1);
                      end
                      
                      dataDim1 = dataDim1(dataIdx);
                      
                      startDim = dataDim1(1);
                      endDim = dataDim1(end);
                      clear dataDim;
                      
                      % retrieve TIME or DEPTH range for which data has been manually flagged
                      if strcmpi(nameDim1, 'TIME')
                          manualQcComment = ['Data values at TIME from ', datestr(startDim, 'yyyy/mm/dd HH:MM:SS'), ' UTC to ', datestr(endDim, 'yyyy/mm/dd HH:MM:SS'), ' UTC manually flagged as ', flagStr, ' : ', comment];
                      else
                          manualQcComment = ['Data values at DEPTH from ', num2str(startDim), ' to ', num2str(endDim), 'm manually flagged as ', flagStr, ' : ', comment];
                      end
                  end
                  callbacks.manualQCRequestCallback(setIdx, kVar(i), dataIdx, flag, manualQcComment);
              end
              sample_data = callbacks.autoQCRequestCallback(setIdx, true);
              
              % update main window with modified data set
              updateCallback(sample_data{setIdx});
              
              % update graph
              if ~isempty(flags), delete(flags(flags ~= 0)); end
              flags = flagFunc(panel, graphs, sample_data{setIdx}, vars);
              
              % write/update manual QC file for this dataset
              mqcFile = [sample_data{setIdx}.toolbox_input_file, '.mqc'];
              
              % we need to check first that there is not any remnants from
              % the old .mqc file naming convention
              [mqcPath, oldMqcFile, ~] = fileparts(sample_data{setIdx}.toolbox_input_file);
              oldMqcFile = fullfile(mqcPath, [oldMqcFile, '.mqc']);
              if exist(oldMqcFile, 'file')
                  movefile(oldMqcFile, mqcFile);
              end
              
              mqc = struct([]);
              
              if exist(mqcFile, 'file'), load(mqcFile, '-mat', 'mqc'); end
              
              for i=1:length(kVar)
                  mqc(end+1).nameVar = sample_data{setIdx}.variables{kVar(i)}.name;
                  mqc(end).iData = dataIdx;
                  mqc(end).flag = flag;
                  mqc(end).comment = manualQcComment;
              end
              save(mqcFile, 'mqc');
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
          stateChanged = ~strcmp(lastState,state);
          if ~stateChanged, resetPropQCCallback(); end % since QC is going to be re-ran, suggest to reset QC properties
          
          sample_data = ...
              callbacks.autoQCRequestCallback(setIdx, stateChanged);
      end
    
      % display QC stats viewer
      viewQCstats(panel, sample_data{setIdx}, mode);
%       viewMetadata(panel, sample_data{setIdx}, ...
%         @metadataUpdateWrapperCallback,...
%         @metadataRepWrapperCallback, mode);
    end
    
      function resetManQCCallback()
      %RESETMANQCCALLBACK Deletes any existing .mqc manual qc file associated
      %to the currently displayed (or all) dataset(s) and resets the(ir) ancillary variable attribute comment.
      %
          
          response = questdlg(...
              ['Reset manual QC flags '...
              '(existing manually QC''d flags will be discarded)?'],...
              'Reset manual QC flags?', ...
              'No', ...
              'Reset for this data set',...
              'Reset for all data sets',...
              'No');
          
          resetIdx = setIdx;
          
          if ~strncmp(response, 'Reset', 5)
              resetIdx = [];
          end
          
          if strcmp(response, 'Reset for all data sets')
              resetIdx = 1:length(sample_data);
          end
          
          for j=1:length(resetIdx)
              for i=1:length(sample_data{resetIdx(j)}.variables)
                  if isfield(sample_data{resetIdx(j)}.variables(i), 'ancillary_comment')
                      sample_data{resetIdx(j)}.variables(i) = rmfield(sample_data{resetIdx(j)}.variables(i), 'ancillary_comment');
                  end
              end
              
              mqcFile = [sample_data{resetIdx(j)}.toolbox_input_file, '.mqc'];
              
              % we need to migrate any remnants of the old file naming convention
              % for .mqc files.
              [mqcPath, oldMqcFile, ~] = fileparts(sample_data{resetIdx(j)}.toolbox_input_file);
              oldMqcFile = fullfile(mqcPath, [oldMqcFile, '.mqc']);
              if exist(oldMqcFile, 'file')
                  movefile(oldMqcFile, mqcFile);
              end
              
              if exist(mqcFile, 'file')
                  delete(mqcFile);
              end
          end
          
          qcDataCallback();
      end
    
      function resetPropQCCallback()
      %RESETPROPQCCALLBACK Deletes any existing .pqc qc properties file associated
      %to the currently displayed (or all) dataset(s).
      %
          
          response = questdlg(...
              ['Reset previous QC properties '...
              '(existing QC properties recorded for this dataset will be reset)?'],...
              'Reset previous QC properties?', ...
              'No', ...
              'Reset for this data set',...
              'Reset for all data sets',...
              'No');
          
          resetIdx = setIdx;
          
          if ~strncmp(response, 'Reset', 5)
              resetIdx = [];
          end
          
          if strcmp(response, 'Reset for all data sets')
              resetIdx = 1:length(sample_data);
          end
          
          for j=1:length(resetIdx)
              for i=1:length(sample_data{resetIdx(j)}.variables)
                  if isfield(sample_data{resetIdx(j)}.variables(i), 'ancillary_comment')
                      sample_data{resetIdx(j)}.variables(i) = rmfield(sample_data{resetIdx(j)}.variables(i), 'ancillary_comment');
                  end
              end
              
              pqcFile = [sample_data{resetIdx(j)}.toolbox_input_file, '.pqc'];
              
              % we need to migrate any remnants of the old file naming convention
              % for .pqc files.
              [pqcPath, oldPqcFile, ~] = fileparts(sample_data{resetIdx(j)}.toolbox_input_file);
              oldPqcFile = fullfile(pqcPath, [oldPqcFile, '.pqc']);
              if exist(oldPqcFile, 'file')
                  movefile(oldPqcFile, pqcFile);
              end
              
              if exist(pqcFile, 'file')
                  delete(pqcFile);
              end
          end
      end
      
    function exportNetCDFCallback()
    %EXPORTNETCDFCALLBACK Called when the user clicks on the 'Export NetCDF' 
    % button. Delegates to the exportNetCDFRequestCallback function.
    %
      callbacks.exportNetCDFRequestCallback();
      
      stateSelectCallback('', panel, updateCallback, lastState, ...
        sample_data, graphType, setIdx, vars, extraSetIdx);
      state = lastState;
    end
    
    function exportRawCallback()
    %EXPORTRAWCALLBACK Called when the user clicks on the 'Export Raw'
    % button. Delegates to the exportRawRequestCallback function.
    %
      callbacks.exportRawRequestCallback();
      
      stateSelectCallback('', panel, updateCallback, lastState, ...
        sample_data, graphType, setIdx, vars, extraSetIdx);
      state = lastState;
    end
  end
end
