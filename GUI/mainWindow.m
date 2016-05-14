function mainWindow(...
  windowTitle, sample_data, states, startState, selectionCallback)
%MAINWINDOW Displays a window which allows the user to view data.
%
% The mainWindow is the main toolbox window. It provides menus allowing the
% user to select the data set to use and the graph type to display (if a
% graph is being displayed), and enable/disable variables.
%
% The central area of the mainWindow is left empty, it is up to the
% calling function (the displayManager) to populate this window. It is also
% up to the calling function to define the buttons which will appear down
% the left of the window; these are referred to as states.
%
% Whenever the user changes the state (via a state button) or any of the 
% options, the provided selectionCallback function is called with the new 
% selection.
%
% The main window never modifies data, but must be kept informed of changes
% to the data set. This is achieved by the updateCallback function handle
% which is passed to the selectionCallback function. Whenever data is
% changed, this function must be called in order to keep the main window 
% display consistent.
%
% Inputs:
%   windowTitle       - String to be used as the window title.
%   sample_data       - Cell array of structs of sample data.
%   states            - Cell array of strings containing state names.
%   startState        - Index into states array, specifying initial state.
%   selectionCallback - A function which is called when the user pushes a 
%                       state button. The function must take the following 
%                       input arguments:
%                         event          - String describing what triggered
%                                          the callback. One of 'state',
%                                          'set', 'graph', or 'var'.
%                         panel          - A uipanel on which things can be 
%                                          drawn.
%                         updateCallback - Function to be called when data
%                                          is updated. The function is of
%                                          the form:
%                                            function updateCallback(...
%                                              sample_data)
%                         state          - Currently selected state (String)
%                         sample_data    - Cell array of sample_data
%                                          structs
%                         graphType      - Currently selected graph type 
%                                          (String)
%                         set            - Currently selected sample_data
%                                          struct
%                         vars           - Currently selected variables
%                       The function must also provide one output argument:
%                         state          - the new state, if it changed.
% 
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
%
  narginchk(5,5);

  if ~ischar(windowTitle),   error('windowTitle must be a string');         end
  if ~iscell(sample_data)...
  || isempty(sample_data),   error('sample_data must be a cell array');     end
  if ~iscellstr(states),     error('states must be a cell array');          end
  if ~isnumeric(startState), error('initialState must be a numeric');       end
  if ~isa(selectionCallback,... 
         'function_handle'), error('selectionCallback must be a function'); end
 
  currentState = states{startState};
  
  % sample menu entries (1-1 mapping to sample_data structs)
  lenSam = length(sample_data);
  sampleDataDescs = cell(lenSam, 1);
  for k = 1:lenSam
    sampleDataDescs{k} = genSampleDataDesc(sample_data{k});
  end

  % window figure
  fig = figure(...
    'Name',        windowTitle, ...
    'Visible',     'off',...
    'Color',       [0.92549 0.913725 0.847059],...
    'MenuBar',     'none',...
    'ToolBar',     'figure',...
    'Resize',      'on',...
    'WindowStyle', 'Normal',...
    'NumberTitle', 'off',...
    'Tag',         'mainWindow');

  % sample data selection menu
  sampleMenu = uicontrol(...
    'Style',  'popupmenu',...
    'String', sampleDataDescs,...
    'Value',  1,...
    'Tag', 'samplePopUpMenu');
  
  % get the toolbox execution mode. Values can be 'timeSeries' and 'profile'. 
  % If no value is set then default mode is 'timeSeries'
  mode = lower(readProperty('toolbox.mode'));
  
  switch mode
      case 'profile'
          graphMenuValue = 2;
      otherwise
          graphMenuValue = 1;
  end

  % graph type selection menu
  graphMenu = uicontrol(...
    'Style',    'popupmenu',...
    'String',   listGraphs(),...
    'Value',    graphMenuValue);
  
  % side panel
  sidePanel = uipanel(...
    'Parent',     fig,...
    'BorderType', 'none');
    
  % state buttons
  lenStates = length(states);
  stateButtons = nan(lenStates, 1);
  for k = 1:lenStates
    stateButtons(k) = uicontrol(...
      'Parent', sidePanel,...
      'Style',  'pushbutton',...
      'String', states{k});
  end
  
  % button to save current graph as an image
  graphButton = uicontrol(...
    'Parent',  sidePanel,  ...
    'Style',  'pushbutton',...
    'String', 'Save Graph' ...
  );
  
  % variable selection panel - created in createVarPanel
  varPanel = uipanel(...
    'Parent',     sidePanel,...
    'BorderType', 'none');
  
  % main display
  mainPanel = uipanel(...
    'Parent',     fig,...
    'BorderType', 'none',...
    'Tag', 'mainPanel');
  
  % use normalized units
  set(fig,              'Units', 'normalized');
  set(sidePanel,        'Units', 'normalized');
  set(mainPanel,        'Units', 'normalized');
  set(varPanel,         'Units', 'normalized');
  set(graphButton,      'Units', 'normalized');
  set(sampleMenu,       'Units', 'normalized');
  set(graphMenu,        'Units', 'normalized');
  set(stateButtons,     'Units', 'normalized');
  
  % set window position
  set(fig,        'Position', [0.1,  0.15, 0.8,  0.7 ]);
  
  % restrict window to primary screen
  set(fig, 'Units', 'pixels');
  pos = get(fig, 'OuterPosition');
  monitors = get(0, 'MonitorPositions');
  if pos(3) > monitors(1,3)
      pos(1) = 1;
      pos(3) = monitors(1,3);
      set(fig, 'OuterPosition', pos);
      get(fig, 'Position');
  end
  
  % set widget positions
  set(sidePanel,  'Position', [0.0,  0.0,  0.15, 0.95]);
  set(mainPanel,  'Position', [0.15, 0.0,  0.85, 0.95]);
  set(sampleMenu, 'Position', [0.0,  0.95, 0.75, 0.05]);
  set(graphMenu,  'Position', [0.75, 0.95, 0.25, 0.05]);
  
  set(fig, 'Units', 'normalized');

  % set widget positions
%   set(sidePanel,  'Position', [0.0,  0.0,  0.15, 0.95]);
  set(sidePanel,  'Position', posUi2(fig, 100, 100, 6:100, 1:10, 0));
%   set(mainPanel,  'Position', [0.15, 0.0,  0.85, 0.95]);
  set(mainPanel,  'Position', posUi2(fig, 100, 100, 6:100, 11:100, 0));
%   set(sampleMenu, 'Position', [0.0,  0.95, 0.75, 0.05]);
  set(sampleMenu, 'Position', posUi2(fig, 100, 100, 1:5, 1:75, 0));
%   set(graphMenu,  'Position', [0.75, 0.95, 0.25, 0.05]);
  set(graphMenu,  'Position', posUi2(fig, 100, 100, 1:5, 76:100, 0));
  
  % varPanel, graph and stateButtons are positioned relative to sidePanel
%   set(varPanel, 'Position', [0.0, 0.0, 1.0, 0.5]);
  set(varPanel, 'Position', posUi2(sidePanel, 10, 1, 6:10, 1, 0));
  
  n = length(stateButtons);
  for k = 1:n
%     set(stateButtons(k), 'Position', ...
%       [0.0, 0.5+(n+1-k)*(0.5/(n+1)), 1.0, 0.5/(n+1)]);
    set(stateButtons(k), 'Position', ...
      posUi2(sidePanel, 2*(n+1)+1, 1, k, 1, 0));
  end
  
  % graph button is tacked on right below state buttons
%   set(graphButton, 'Position', [0.0, 0.5, 1.0, 0.5/(n+1)]);
  set(graphButton, 'Position', posUi2(sidePanel, 2*(n+1)+1, 1, n+1, 1, 0));
  
  % reset back to pixels
%   set(fig,          'Units', 'pixels');
%   set(sidePanel,    'Units', 'pixels');
%   set(mainPanel,    'Units', 'pixels');
%   set(varPanel,     'Units', 'pixels');
%   set(graphButton,  'Units', 'pixels');
%   set(sampleMenu,   'Units', 'pixels');
%   set(graphMenu,    'Units', 'pixels');
%   set(stateButtons, 'Units', 'pixels');
  
  % set callbacks - variable panel widget 
  % callbacks are set in createParamPanel
  set(sampleMenu,   'Callback', @sampleMenuCallback);
  set(graphMenu,    'Callback', @graphMenuCallback);
  set(stateButtons, 'Callback', @stateButtonCallback);
  set(graphButton,  'Callback', @graphButtonCallback);
  
  set(fig, 'Visible', 'on');
  createVarPanel(sample_data{1}, []);
  selectionChange('state');
  
  tb      = findall(fig, 'Type', 'uitoolbar');
  buttons = findall(tb);
  
  zoomoutb = findobj(buttons, 'TooltipString', 'Zoom Out');
  zoominb  = findobj(buttons, 'TooltipString', 'Zoom In');
  panb     = findobj(buttons, 'TooltipString', 'Pan');
  datacursorb     = findobj(buttons, 'TooltipString', 'Data Cursor');
  
  buttons(buttons == tb)            = [];
  buttons(buttons == zoomoutb)      = [];
  buttons(buttons == zoominb)       = [];
  buttons(buttons == panb)          = [];
  buttons(buttons == datacursorb)   = [];
  
  delete(buttons);
  
  %set zoom/pan post-callback
  %zoom v6 off; % undocumented Matlab to make sure zoom function prior to R14 is not used. Seems to not be supported from R2015a.
  hZoom = zoom(fig);
  hPan = pan(fig);
  set(hZoom, 'ActionPostCallback', @zoomPostCallback);
  set(hPan, 'ActionPostCallback', @zoomPostCallback);
  
  %set uimenu
  hToolsMenu                        = uimenu(fig, 'label', 'Tools');
  if strcmpi(mode, 'timeseries')
      hToolsCheckPlannedDepths      = uimenu(hToolsMenu, 'label', 'Check measured against planned depths');
      hToolsCheckPlannedDepthsNonQC = uimenu(hToolsCheckPlannedDepths, 'label', 'non QC');
      hToolsCheckPlannedDepthsQC    = uimenu(hToolsCheckPlannedDepths, 'label', 'QC');
      hToolsCheckPressDiffs         = uimenu(hToolsMenu, 'label', 'Check pressure differences between selected instrument and nearest neighbours');
      hToolsCheckPressDiffsNonQC    = uimenu(hToolsCheckPressDiffs, 'label', 'non QC');
      hToolsCheckPressDiffsQC       = uimenu(hToolsCheckPressDiffs, 'label', 'QC');
      hToolsLineDepth               = uimenu(hToolsMenu, 'label', 'Line plot mooring''s depths');
      hToolsLineDepthNonQC          = uimenu(hToolsLineDepth, 'label', 'non QC');
      hToolsLineDepthQC             = uimenu(hToolsLineDepth, 'label', 'QC');
      hToolsLineCommonVar           = uimenu(hToolsMenu, 'label', 'Line plot mooring''s 1D variables');
      hToolsLineCommonVarNonQC      = uimenu(hToolsLineCommonVar, 'label', 'non QC');
      hToolsLineCommonVarQC         = uimenu(hToolsLineCommonVar, 'label', 'QC');
      hToolsScatterCommonVar        = uimenu(hToolsMenu, 'label', 'Scatter plot mooring''s 1D variables VS depth');
      hToolsScatterCommonVarNonQC   = uimenu(hToolsScatterCommonVar, 'label', 'non QC');
      hToolsScatterCommonVarQC      = uimenu(hToolsScatterCommonVar, 'label', 'QC');
      hToolsScatter2DCommonVar      = uimenu(hToolsMenu, 'label', 'Scatter plot mooring''s 2D variables VS depth');
      hToolsScatter2DCommonVarNonQC = uimenu(hToolsScatter2DCommonVar, 'label', 'non QC');
      hToolsScatter2DCommonVarQC    = uimenu(hToolsScatter2DCommonVar, 'label', 'QC');
      
      %set menu callbacks
      set(hToolsCheckPlannedDepthsNonQC, 'callBack', {@displayCheckPlannedDepths, false});
      set(hToolsCheckPlannedDepthsQC,    'callBack', {@displayCheckPlannedDepths, true});
      set(hToolsCheckPressDiffsNonQC,    'callBack', {@displayCheckPressDiffs, false});
      set(hToolsCheckPressDiffsQC,       'callBack', {@displayCheckPressDiffs, true});
      set(hToolsLineDepthNonQC,          'callBack', {@displayLineMooringDepth, false});
      set(hToolsLineDepthQC,             'callBack', {@displayLineMooringDepth, true});
      set(hToolsLineCommonVarNonQC,      'callBack', {@displayLineMooringVar, false});
      set(hToolsLineCommonVarQC,         'callBack', {@displayLineMooringVar, true});
      set(hToolsScatterCommonVarNonQC,   'callBack', {@displayScatterMooringVar, false, true});
      set(hToolsScatterCommonVarQC,      'callBack', {@displayScatterMooringVar, true, true});
      set(hToolsScatter2DCommonVarNonQC, 'callBack', {@displayScatterMooringVar, false, false});
      set(hToolsScatter2DCommonVarQC,    'callBack', {@displayScatterMooringVar, true, false});
  else
      hToolsLineCastVar             = uimenu(hToolsMenu, 'label', 'Line plot profile variables');
      hToolsLineCastVarNonQC        = uimenu(hToolsLineCastVar, 'label', 'non QC');
      hToolsLineCastVarQC           = uimenu(hToolsLineCastVar, 'label', 'QC');
      
      %set menu callbacks
      set(hToolsLineCastVarNonQC,       'callBack', {@displayLineCastVar, false});
      set(hToolsLineCastVarQC,          'callBack', {@displayLineCastVar, true});
  end
  hHelpMenu                         = uimenu(fig, 'label', 'Help');
  hHelpWiki                         = uimenu(hHelpMenu, 'label', 'IMOS Toolbox Wiki');
  
  %set menu callbacks
  set(hHelpWiki,                        'callBack', @openWikiPage);
  
  %% Widget Callbacks
  
  function selectionChange(event)
  %Retrieves the current selection, clears the main panel, and calls 
  % selectionCallback.
  % 
    state = currentState;
    sam   = getSelectedData();
    vars  = getSelectedVars();
    graph = getSelectedGraphType();
    
    % clear main panel
    children = get(mainPanel, 'Children');
    delete(children);
    
    % delete any mouse listeners that may have been added
    zoom off;
    pan off;
    set(fig, 'WindowButtonDownFcn',   []);
    set(fig, 'WindowButtonMotionFcn', []);
    set(fig, 'WindowButtonUpFcn',     []);
    
    currentState = selectionCallback(...
      event,...
      mainPanel, ...
      @updateCallback, ...
      state, ...
      sample_data, ...
      graph, ...
      sam.meta.index, vars);
  
    % set data cursor mode custom display
    dcm_obj = datacursormode(fig);
    set(dcm_obj, 'UpdateFcn', {@customDcm, sam, vars, graph, mode});
  end
  
  function sampleMenuCallback(source,ev)
  %SAMPLEMENUCALLBACK Called when a dataset is selected from the sample
  % menu. Updates the variables panel, then delegates to selectionChange.
  % 
    sam = getSelectedData();
    createVarPanel(sam, []);
    selectionChange('set');
  end

  function graphMenuCallback(source,ev)
  %GRAPHMENUCALLBACK Called when the user changes the graph type via the
  % graph selection menu. Delegates to selectionChange.
  %
    selectionChange('graph');
  end

  function stateButtonCallback(source, ev)
  %STATEBUTTONCALLBACK Called when the user pushes a state button. Updates
  % the current state, then delegates to selectionChange.
  %

    currentState = get(source, 'String');
    selectionChange('state');
    
    % reset varPanel
    sam = getSelectedData();
    vars = getSelectedVars();
    createVarPanel(sam, vars);
  end

  function graphButtonCallback(source, ev)
  %GRAPHBUTTONCALLBACK Called when the user pushes the 'Save Graph' button.
  % Prompts the user to save the current graph.
  
    % find all axes objects on the main panel
    ax = findobj(mainPanel, 'Type', 'axes');
    
    % save the axes
    saveGraph(fig, ax);
  
  end

  function varPanelCallback(source,ev)
  %PARAMPANELCALLBACK Called when the variable or dimension selection 
  % changes. Delegates to selectionChange.
  %
    selectionChange('var');
  end

  function zoomPostCallback(source,ev)
  %ZOOMPOSTCALLBACK Called when the zoom function is called. Redraws axis ticks. 
  %
    graphs1D = findobj('Tag', 'axis1D');
    graphs2D = findobj('Tag', 'axis2D');
    
    isCurAx1D = false;
    iGraph1D = (gca == graphs1D);
    if any(iGraph1D)
        isCurAx1D = true;
        graphs1D(iGraph1D) = [];
    else
        graphs2D(gca == graphs2D) = [];
    end
    
    graphs = [graphs1D; graphs2D];
    
    % reset current axis yTicks
    yLimits = get(gca, 'YLim');
    yStep   = (yLimits(2) - yLimits(1)) / 5;
    yTicks  = yLimits(1):yStep:yLimits(2);
    set(gca, 'YTick', yTicks);
    
    % sync all other 2D Y axis if needed
    if ~isCurAx1D && ~isempty(graphs2D)
        set(graphs2D, 'YLim', yLimits);
        set(graphs2D, 'YTick', yTicks);
    end
    
    % reset current axis xTicks
    xLimits = get(gca, 'XLim');
    xStep   = (xLimits(2) - xLimits(1)) / 5;
    xTicks  = xLimits(1):xStep:xLimits(2);
    set(gca, 'XTick', xTicks);
    
    graphName = get(graphMenu, 'String');
    graphName = graphName{get(graphMenu, 'Value')};
    if strcmpi(graphName, 'TimeSeries')
        % sync all other X axis
        set(graphs, 'XLim', xLimits);
        set(graphs, 'XTick', xTicks);
        
        % reset other 1D axis yTicks if needed because the X axis sync causes a
        % change in the Y range
        if ~isempty(graphs1D)
            for i=1:length(graphs1D)
                yLimits = get(graphs1D(i), 'YLim');
                yStep   = (yLimits(2) - yLimits(1)) / 5;
                yTicks  = yLimits(1):yStep:yLimits(2);
                set(graphs1D(i), 'YTick', yTicks);
            end
        end
        
        % tranformation of datenum xticks in datestr
        datetick(gca, 'x', 'dd-mm-yy HH:MM', 'keepticks');
        xTickLabel = get(gca, 'XTickLabel');
        for i=1:length(graphs)
            set(graphs(i), 'XTickLabel', xTickLabel); % this is to avoid too many calls to datetick()
        end
        
    elseif strcmpi(graphName, 'DepthProfile')
        % sync all other Y axis
        set(graphs, 'YLim', yLimits);
        set(graphs, 'YTick', yTicks);
    end
  end

  %% Menu callback
  function displayCheckPressDiffs(source,ev, isQC)
      %DISPLAYLINEPRESSDIFFS opens a new window where all the PRES/PRES_REL
      %values for instruments adjacent to the current instrument are
      %displayed with the differences between these instrument pressures
      %
      %check for pressure
      iSampleMenu = get(sampleMenu, 'Value');
      iPRES_REL = getVar(sample_data{iSampleMenu}.variables, 'PRES_REL');
      iPRES = getVar(sample_data{iSampleMenu}.variables, 'PRES');
      if iPRES_REL == 0 && iPRES == 0
          sampleMenuStrings = get(sampleMenu, 'String');
          disp(['No pressure data for ' sampleMenuStrings{iSampleMenu}])
          return
      end
        
      checkMooringPresDiffs(sample_data, iSampleMenu, isQC, false, '');      
  end

  function displayCheckPlannedDepths(source,ev, isQC)
      %DISPLAYCHECKPLANNEDDEPTHS Opens a new window where the actual
      %depths recorded are compared to the planned depths.
      %
      checkMooringPlannedDepths(sample_data, isQC, false, '');
  end
  
  function displayLineMooringDepth(source,ev, isQC)
  %DISPLAYLINEMOORINGDEPTH Opens a new window where all the nominal depths and
  %actual/computed depths from intruments on the mooring are line-plotted.
  %
  
  lineMooring1DVar(sample_data, 'DEPTH', isQC, false, '');

  end

  function displayLineMooringVar(source,ev, isQC)
    %DISPLAYLINEMOORINGVAR Opens a new window where all the previously selected
    % variables collected by intruments on the mooring are line-plotted.
    %
    stringQC = 'non QC';
    if isQC, stringQC = 'QC'; end

    % get all params that are in common in at least two datasets
    lenSampleData = length(sample_data);
    paramsName = {};
    paramsCount = [];
    for i=1:lenSampleData
        lenParamsSample = length(sample_data{i}.variables);
        for j=1:lenParamsSample
            if i==1 && j==1
                paramsName{1} = sample_data{1}.variables{1}.name;
                paramsCount(1) = 1;
            else
                sameParam = strcmpi(paramsName, sample_data{i}.variables{j}.name);
                if ~any(sameParam)
                    paramsName{end+1} = sample_data{i}.variables{j}.name;
                    paramsCount(end+1) = 1;
                else
                    paramsCount(sameParam) = paramsCount(sameParam)+1;
                end
            end
        end
    end

    iParamsToGetRid = (paramsCount == 1);
    paramsName(iParamsToGetRid) = [];

    % we get rid of DEPTH parameter, if necessary user should use the
    % Depth specific plot
    iDEPTH = strcmpi(paramsName, 'DEPTH');
    paramsName(iDEPTH) = [];

    % we get rid of TIMESERIES, PROFILE, TRAJECTORY, LATITUDE, LONGITUDE and NOMINAL_DEPTH parameters
    iParam = strcmpi(paramsName, 'TIMESERIES');
    paramsName(iParam) = [];
    iParam = strcmpi(paramsName, 'PROFILE');
    paramsName(iParam) = [];
    iParam = strcmpi(paramsName, 'TRAJECTORY');
    paramsName(iParam) = [];
    iParam = strcmpi(paramsName, 'LATITUDE');
    paramsName(iParam) = [];
    iParam = strcmpi(paramsName, 'LONGITUDE');
    paramsName(iParam) = [];
    iParam = strcmpi(paramsName, 'NOMINAL_DEPTH');
    paramsName(iParam) = [];
    
    % by default TEMP is selected
    iTEMP = find(strcmpi(paramsName, 'TEMP'));

    [iSelection, ok] = listdlg(...
        'ListString', paramsName, ...
        'SelectionMode', 'single', ...
        'ListSize', [150 150], ...
        'InitialValue', iTEMP, ...
        'Name', ['Plot a ' stringQC '''d variable accross all instruments in the mooring'], ...
        'PromptString', 'Select a variable :');

    if ok==0
        return;
    else
        varName = paramsName{iSelection};
    end

    lineMooring1DVar(sample_data, varName, isQC, false, '');

  end

function displayLineCastVar(source,ev, isQC)
    %DISPLAYLINECASTVAR Opens a new window where all the 
    % variables collected by the CTD cast are line-plotted.
    %
    stringQC = 'non QC';
    if isQC; stringQC = 'QC'; end
        
    % get all params names
    lenSampleData = length(sample_data);
    paramsName = {};
    for i=1:lenSampleData
        lenParamsSample = length(sample_data{i}.variables);
        for j=1:lenParamsSample
            isParamQC = any(sample_data{i}.variables{j}.flags == 1) || any(sample_data{i}.variables{j}.flags == 2);
            if i==1 && j==1
                paramsName{1} = sample_data{1}.variables{1}.name;
            else
                sameParam = strcmpi(paramsName, sample_data{i}.variables{j}.name);
                if ~any(sameParam)
                    paramsName{end+1} = sample_data{i}.variables{j}.name;
                end
            end
            % get rid of non QC'd params if only interested in QC
            if isQC && ~isParamQC; paramsName(end) = []; end
        end
    end

    lineCastVar(sample_data, paramsName, isQC, false, '');

  end

function displayScatterMooringVar(source,ev, isQC, is1D)
    %DISPLAYSCATTERMOORINGVAR Opens a new window where all the previously selected
    % variables collected by intruments on the mooring are scatter-plotted.
    %
    stringQC = 'non QC';
    if isQC, stringQC = 'QC'; end

    % go through all datasets and parameters and count them
    lenSampleData = length(sample_data);
    paramsName = {};
    paramsCount = [];
    params2D = [];
    for i=1:lenSampleData
        lenParamsSample = length(sample_data{i}.variables);
        for j=1:lenParamsSample
            sameParam = strcmpi(paramsName, sample_data{i}.variables{j}.name);
            if ~any(sameParam)
                paramsName{end+1} = sample_data{i}.variables{j}.name;
                paramsCount(end+1) = 1;
                if length(sample_data{i}.variables{j}.dimensions) == 2 && ... % TIME, HEIGHT_ABOVE_SENSOR
                        size(sample_data{i}.variables{j}.data, 2) > 1 && ...
                        size(sample_data{i}.variables{j}.data, 3) == 1 % we're only plotting ADCP 2D variables with DEPTH variable.
                    params2D(end+1) = true;
                else
                    params2D(end+1) = false;
                end
            else
                paramsCount(sameParam) = paramsCount(sameParam)+1;
            end
        end
    end
        
    if is1D
        % get only params that are in common in at least two datasets
        iParamsNotInCommon = (paramsCount == 1);
        % get only params that are 1D
        iParamsToGetRid = params2D | iParamsNotInCommon;
        
        paramsName(iParamsToGetRid) = [];
        
        % we get rid of DEPTH, PRES and PRES_REL parameters
        iDEPTH = strcmpi('DEPTH', paramsName);
        paramsName(iDEPTH) = [];
        iDEPTH = strcmpi('PRES', paramsName);
        paramsName(iDEPTH) = [];
        iDEPTH = strcmpi('PRES_REL', paramsName);
        paramsName(iDEPTH) = [];
    
        % we get rid of TIMESERIES, PROFILE, TRAJECTORY, LATITUDE, LONGITUDE and NOMINAL_DEPTH parameters
        iParam = strcmpi(paramsName, 'TIMESERIES');
        paramsName(iParam) = [];
        iParam = strcmpi(paramsName, 'PROFILE');
        paramsName(iParam) = [];
        iParam = strcmpi(paramsName, 'TRAJECTORY');
        paramsName(iParam) = [];
        iParam = strcmpi(paramsName, 'LATITUDE');
        paramsName(iParam) = [];
        iParam = strcmpi(paramsName, 'LONGITUDE');
        paramsName(iParam) = [];
        iParam = strcmpi(paramsName, 'NOMINAL_DEPTH');
        paramsName(iParam) = [];
        
        % by default TEMP is selected
        iDefault = find(strcmpi(paramsName, 'TEMP'));
    else
        % get only params that are 2D
        paramsName(~params2D) = [];
        
        % we get rid of DEPTH, PRES and PRES_REL parameters
        iDEPTH = strcmpi('DEPTH', paramsName);
        paramsName(iDEPTH) = [];
        iDEPTH = strcmpi('PRES', paramsName);
        paramsName(iDEPTH) = [];
        iDEPTH = strcmpi('PRES_REL', paramsName);
        paramsName(iDEPTH) = [];
        
        % we get rid of HEIGHT parameter
        iHEIGHT = strcmpi('HEIGHT', paramsName);
        paramsName(iHEIGHT) = [];
        
        % we get rid of ADCP diagnostic parameters
        for i=1:4
            iStr = num2str(i);
            iABSI = strcmpi(['ABSI' iStr], paramsName);
            paramsName(iABSI) = [];
            iABSIC = strcmpi(['ABSIC' iStr], paramsName);
            paramsName(iABSIC) = [];
            iCORR = strcmpi(['CMAG' iStr], paramsName);
            paramsName(iCORR) = [];
            iPERG = strcmpi(['PERG' iStr], paramsName);
            paramsName(iPERG) = [];
        end
       
        % by default CDIR is selected
        iDefault = find(strcmpi(paramsName, 'CDIR'));
    end

    if isempty(iDefault), iDefault = 1; end
    
    [iSelection, ok] = listdlg(...
        'ListString', paramsName, ...
        'SelectionMode', 'single', ...
        'ListSize', [150 150], ...
        'InitialValue', iDefault, ...
        'Name', ['Plot a ' stringQC '''d variable accross all instruments in the mooring'], ...
        'PromptString', 'Select a variable :');

    if ok==0
        return;
    else
        varName = paramsName{iSelection};
    end

    if is1D
        scatterMooring1DVarAgainstDepth(sample_data, varName, isQC, false, '');
    else
        scatterMooring2DVarAgainstDepth(sample_data, varName, isQC, false, '');
    end

end

  function openWikiPage(source,ev)
  %OPENWIKIPAGE opens a new tab in your web-browser to access the
  %IMOS-Toolbox wiki
  %
    url = 'https://github.com/aodn/imos-toolbox/wiki';
    stat = web(url, '-browser');
    if stat == 1
        fprintf('%s\n', 'Warning : Browser was not found.');
    elseif stat == 2
        fprintf('%s\n', 'Warning : Browser was found but could not be launched.');
    end
  end

  %% Data update callback
  
  function updateCallback(sam)
  %UPDATECALLBACK Called when a data set has been modified. Saves the new
  % copy of the data set.
  %
    narginchk(1,1);
    if ~isstruct(sam),              error('sam must be a struct');         end
    if ~isfield(sam.meta, 'index'), error('sam must have an index field'); end
    
    % synchronise current data sets and sample_data
    sample_data{sam.meta.index} = sam;
    lenSam = length(sample_data);
    
    % regenerate descriptions
    sampleDataDescs = cell(lenSam, 1);
    for k = 1:lenSam
        sampleDataDescs{k} = genSampleDataDesc(sample_data{k});
    end
    
    set(sampleMenu, 'String', sampleDataDescs);
    
  end

  %% Retrieving current selection

  function sam = getSelectedData()
  %GETSELECTEDDATA Returns the currently selected sample_data.
  %
    idx = get(sampleMenu, 'Value');
    
    sam = sample_data{idx};
  end

  function graphType = getSelectedGraphType()
  %GETSELECTEDGRAPHTYPE Returns the currently selected graph type.
  %
    idx   = get(graphMenu, 'Value');
    types = get(graphMenu, 'String');
    
    graphType = types{idx};
    
  end

  function vars = getSelectedVars()
  %GETSELECTEDVARS Returns a vector containing the indices of the
  % variables which are selected.
  %
  
    % menu and checkboxes are stored in user data
    checkboxes = get(varPanel, 'UserData');
    
    vars = [];
    
    for m = 1:length(checkboxes)
      if get(checkboxes(m), 'Value'), vars(end+1) = m; end
    end
  end

  %% Miscellaneous
  
  function createVarPanel(sam, vars)
  %CREATEVARPANEL Creates the variable selection panel. Called when the
  % selected dataset changes. The panel allows users to select which
  % variables should be displayed.
  %
    % delete checkboxes and dim menu from previous data set
    checkboxes = get(varPanel, 'Children');
    for m = 1:length(checkboxes), delete(checkboxes(m)); end
    
    switch mode
        case 'profile'
            % we don't want to plot TIME, PROFILE, DIRECTION, LATITUDE, LONGITUDE, BOT_DEPTH
            p = getVar(sam.variables, 'BOT_DEPTH');
                
            % we don't want to plot DEPTH if it's a variable
            iDepth = getVar(sam.variables, 'DEPTH');
            if iDepth ~= 0
                sam.variables(iDepth) = [];
            end
        otherwise
            % we don't want to plot TIMESERIES, PROFILE, TRAJECTORY, LATITUDE, LONGITUDE, NOMINAL_DEPTH
            p = getVar(sam.variables, 'NOMINAL_DEPTH');
    end
        
    % create checkboxes for new data set. The order in which the checkboxes
    % are created is the same as the order of the variables - this is
    % important, as the getSelectedParams function assumes that the indices
    % line up.
    checkboxes(:) = [];
    n = length(sam.variables);
    for m = 1+p:n
        if isempty(vars)
            % enable at most 3 variables initially,
            % otherwise the graph will be cluttered
            val = 1;
            if m-p > 3, val = 0; end
        else
            if any(m-p == vars)
                val = 1;
            else
                val = 0;
            end
        end

%       checkboxes(m) = uicontrol(...
%         'Parent',   varPanel,...
%         'Style',    'checkbox',...
%         'String',   sam.variables{m}.name,...
%         'Value',    val,...
%         'Callback', @varPanelCallback,...
%         'Units',    'normalized',...
%         'Position', [0.0, (n-m)/n, 1.0, 1/n]);
        
        checkboxes(m-p) = uicontrol(...
            'Parent',           varPanel,...
            'Style',            'checkbox',...
            'String',           sam.variables{m}.name,...
            'TooltipString',    sprintf('%s\n(%s)', sam.variables{m}.long_name, sam.variables{m}.units),...
            'Value',            val,...
            'Callback',         @varPanelCallback,...
            'Units',            'normalized',...
            'Position',         posUi2(varPanel, n-p, 1, m-p, 1, 0),...
            'Tag',              ['checkbox' sam.variables{m}.name]);
    end
%     set(checkboxes, 'Units', 'pixels');
    
    % the checkboxes are saved in UserData field to make them
    % easy to retrieve in the getSelectedVars function
    set(varPanel, 'UserData', checkboxes);
  end

    function txt = customDcm(~, event_obj, sam, vars, graph, mode)
        % Customizes text of data tips
        switch mode
            case 'profile'
                % we don't want to plot TIME, PROFILE, DIRECTION, LATITUDE, LONGITUDE, BOT_DEPTH
                varOffset = getVar(sam.variables, 'BOT_DEPTH');
            otherwise
                % we don't want to plot TIMESERIES, PROFILE, TRAJECTORY, LATITUDE, LONGITUDE, NOMINAL_DEPTH
                varOffset = getVar(sam.variables, 'NOMINAL_DEPTH');
        end
        
        % retrieve x/y click positions + data index
        posClic = get(event_obj, 'Position');
        I       = get(event_obj, 'DataIndex');
        
        switch graph
            case 'Profile'
                dimLabel = 'DEPTH';
                dimUnit  = ' m';
                dimFun = @num2str;
            case 'TimeSeries'
                dimLabel = 'TIME';
                dimUnit  = ' UTC';
                dimFun = @datestr;
            otherwise
                error(['graph type ' graph ' not supported']);
        end
        
        iDim = getVar(sam.dimensions, dimLabel);
        nRecord = length(sam.dimensions{iDim}.data);
        
        nVar = length(vars);
        txt = cell(1, nVar+1);
        txt{1} = [dimLabel ': ' dimFun(posClic(1)) dimUnit];
        for iVar=1:nVar
            iVarCorr  = vars(iVar)+varOffset;
            varLabel  = sam.variables{iVarCorr}.name;
            varUnit   = [' ' sam.variables{iVarCorr}.units];
            
            nSample   = numel(sam.variables{iVarCorr}.data);
            iSample   = I;
            zInfo = '';
            if I < nRecord && nSample > nRecord
                % we've clicked on a 1D plot so don't want to display
                % information from 2D plots
                txt{iVar+1} = [];
                continue;
            else
                % we've clicked on a 2D plot
                nDim = sam.variables{iVarCorr}.dimensions;
                if nDim==1
                    % and are dealing with a 1D info
                    iSample = sam.dimensions{iDim}.data == posClic(1);
                else
                    % and are dealing with a 2D info
                    iZ = sam.variables{iVarCorr}.dimensions(2);
                    nZ = length(sam.dimensions{iZ}.data);
                    iSample = repmat(sam.dimensions{iDim}.data == posClic(1), 1, nZ) & repmat((sam.dimensions{iZ}.data == posClic(2))', nRecord, 1);
                    
                    zLabel = sam.dimensions{iZ}.name;
                    zUnit  = [' ' sam.dimensions{iZ}.units];
                    zData  = num2str(posClic(2));
                    zInfo  = [' @' zLabel ': ' zData zUnit];
                end
            end
            varData   = num2str(sam.variables{iVarCorr}.data(iSample));
            
            txt{iVar+1} = [varLabel ': ' varData varUnit zInfo];
        end
        
        % clean up empty cells
        txt(cellfun(@isempty, txt)) = [];
    end
end
