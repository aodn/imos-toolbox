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
  error(nargchk(5,5,nargin));

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
      posUi2(sidePanel, 2*(n+1), 1, k, 1, 0));
  end
  
  % graph button is tacked on right below state buttons
%   set(graphButton, 'Position', [0.0, 0.5, 1.0, 0.5/(n+1)]);
  set(graphButton, 'Position', posUi2(sidePanel, 2*(n+1), 1, n+1, 1, 0));
  
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
  createVarPanel(sample_data{1});
  selectionChange('state');
  
  tb      = findall(fig, 'Type', 'uitoolbar');
  buttons = findall(tb);
  
  zoomoutb = findobj(buttons, 'TooltipString', 'Zoom Out');
  zoominb  = findobj(buttons, 'TooltipString', 'Zoom In');
  panb     = findobj(buttons, 'TooltipString', 'Pan');
  
  buttons(buttons == tb)       = [];
  buttons(buttons == zoomoutb) = [];
  buttons(buttons == zoominb)  = [];
  buttons(buttons == panb)     = [];
  
  delete(buttons);
  
  %set zoom/pan post-callback
  zoom v6 off;
  hZoom = zoom(fig);
  hPan = pan(fig);
  set(hZoom, 'ActionPostCallback', @zoomPostCallback);
  set(hPan, 'ActionPostCallback', @zoomPostCallback);
  
  %set uimenu
  hToolsMenu        = uimenu(fig, 'label', 'Tools');
  hToolsDepth       = uimenu(hToolsMenu, 'label', 'Display mooring''s depths');
  hToolsTemp        = uimenu(hToolsMenu, 'label', 'Display mooring''s variables');
  hHelpMenu         = uimenu(fig, 'label', 'Help');
  hHelpWiki         = uimenu(hHelpMenu, 'label', 'IMOS Toolbox Wiki');
  
  %set menu callbacks
  set(hToolsDepth,      'callBack', @displayMooringDepth);
  set(hToolsTemp,       'callBack', @displayMooringVar);
  set(hHelpWiki,        'callBack', @openWikiPage);
  
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
  end
  
  function sampleMenuCallback(source,ev)
  %SAMPLEMENUCALLBACK Called when a dataset is selected from the sample
  % menu. Updates the variables panel, then delegates to selectionChange.
  % 
    sam = getSelectedData();
    createVarPanel(sam);
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
  function displayMooringDepth(source,ev)
  %DISPLAYMOORINGDEPTH Opens a new window where all the nominal depths and
  %actual/computed depths from intruments on the mooring are plotted.
  %
    lenSampleData = length(sample_data);
    %plot depth information
    monitorRec = get(0,'MonitorPosition');
    xResolution = monitorRec(:, 3)-monitorRec(:, 1);
    iBigMonitor = xResolution == max(xResolution);
    if sum(iBigMonitor)==2, iBigMonitor(2) = false; end % in case exactly same monitors
    hFigMooringDepth = figure(...
        'Name', 'Mooring''s instruments depths', ...
        'NumberTitle','off', ...
        'OuterPosition', [0, 0, monitorRec(iBigMonitor, 3), monitorRec(iBigMonitor, 4)]);
    hAxMooringDepth = axes('Parent',   hFigMooringDepth, 'YDir', 'reverse');
    set(get(hAxMooringDepth, 'XLabel'), 'String', 'Time')
    set(get(hAxMooringDepth, 'YLabel'), 'String', 'Depth (m)')
    set(get(hAxMooringDepth, 'Title'), 'String', 'Mooring''s instruments depths')
    hold(hAxMooringDepth, 'on');
    
    %sort instruments by meta.depth
    metaDepth = nan(lenSampleData, 1);
    xMin = nan(lenSampleData, 1);
    xMax = nan(lenSampleData, 1);
    for i=1:lenSampleData
        metaDepth(i) = sample_data{i}.meta.depth;
        xMin = min(sample_data{i}.dimensions{1}.data);
        xMax = max(sample_data{i}.dimensions{1}.data);
    end
    [~, iSort] = sort(metaDepth);
    xMin = min(xMin);
    xMax = max(xMax);
    set(hAxMooringDepth, 'XTick', (xMin:(xMax-xMin)/4:xMax));
    set(hAxMooringDepth, 'XLim', [xMin, xMax]);
    
    % reverse the colorbar as we want surface in red and bottom in blue
    cMap = colormap(jet(lenSampleData));
    cMap = flipud(cMap);
    
    lineStyle = {'-', '--', ':', '-.'};
    lenLineStyle = length(lineStyle);
    instrumentDesc = cell(lenSampleData+1, 1);
    instrumentDesc{1} = 'Nominal depths';
    hLineDepth = nan(lenSampleData+1, 1);
    for i=1:lenSampleData
        instrumentDesc{i+1} = sample_data{iSort(i)}.instrument;
        if ~isnan(sample_data{i}.meta.depth)
            metaDepth = sample_data{iSort(i)}.meta.depth;
            instrumentDesc{i+1} = [instrumentDesc{i+1} ' (' num2str(metaDepth) 'm)'];
            hLineDepth(1) = line([sample_data{iSort(i)}.dimensions{1}.data(1), sample_data{iSort(i)}.dimensions{1}.data(end)], ...
                [metaDepth, metaDepth], ...
                'Color', 'black');
        else
            fprintf('%s\n', ['Warning : in ' sample_data{iSort(i)}.toolbox_input_file ...
                ', the ''sample_data.meta.depth'' attribute is not documented.']);
        end
        
        %look for the depth variable
        lenVar = length(sample_data{iSort(i)}.variables);
        iDepth = 0;
        for j=1:lenVar
            if strcmpi(sample_data{iSort(i)}.variables{j}.name, 'DEPTH')
                iDepth = j;
                break;
            end
        end
        
        if iDepth > 0
            hLineDepth(i+1) = line(sample_data{iSort(i)}.dimensions{1}.data, ...
                sample_data{iSort(i)}.variables{iDepth}.data, ...
                'Color', cMap(i, :), 'LineStyle', lineStyle{mod(i, lenLineStyle)+1});
        else
            fprintf('%s\n', ['Warning : in ' sample_data{iSort(i)}.toolbox_input_file ...
                ', there is no DEPTH variable.']);
        end
    end
    
    iNan = isnan(hLineDepth);
    if any(iNan)
        hLineDepth(iNan) = [];
        instrumentDesc(iNan) = [];
    end
    
    datetick(hAxMooringDepth, 'x', 'dd-mm-yy HH:MM:SS', 'keepticks');
    legend(hLineDepth, instrumentDesc, 'Location', 'NorthEastOutside');
  end

    function displayMooringVar(source,ev)
    %DISPLAYMOORINGVAR Opens a new window where all the previously selected
    % variables collected by intruments on the mooring are plotted.
    %
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
        
        % by default TEMP is selected
        iTEMP = find(strcmpi(paramsName, 'TEMP'));
        
        [iSelection, ok] = listdlg(...
            'ListString', paramsName, ...
            'SelectionMode', 'single', ...
            'ListSize', [150 150], ...
            'InitialValue', iTEMP, ...
            'Name', 'Plot a variable accross all instruments in the mooring', ...
            'PromptString', 'Select a variable :');
        
        if ok==0
            return;
        else
            varName = paramsName{iSelection};
        end
        
        varTitle = strrep(imosParameters(varName, 'long_name'), '_', ' ');
        varUnit = imosParameters(varName, 'uom');
        
        %plot depth information
        monitorRec = get(0,'MonitorPosition');
        xResolution = monitorRec(:, 3)-monitorRec(:, 1);
        iBigMonitor = xResolution == max(xResolution);
        if sum(iBigMonitor)==2, iBigMonitor(2) = false; end % in case exactly same monitors
        hFigMooringTemp = figure(...
            'Name', ['Mooring''s instruments ' varTitle], ...
            'NumberTitle','off', ...
            'OuterPosition', [0, 0, monitorRec(iBigMonitor, 3), monitorRec(iBigMonitor, 4)]);
        hAxMooringTemp = axes('Parent',   hFigMooringTemp);
        set(get(hAxMooringTemp, 'XLabel'), 'String', 'Time');
        set(get(hAxMooringTemp, 'YLabel'), 'String', [varName ' (' varUnit ')']);
        set(get(hAxMooringTemp, 'Title'), 'String', ['Mooring''s instruments ' varTitle]);
        hold(hAxMooringTemp, 'on');
        
        %sort instruments by meta.depth
        metaDepth = nan(lenSampleData, 1);
        xMin = nan(lenSampleData, 1);
        xMax = nan(lenSampleData, 1);
        for i=1:lenSampleData
            metaDepth(i) = sample_data{i}.meta.depth;
            xMin = min(sample_data{i}.dimensions{1}.data);
            xMax = max(sample_data{i}.dimensions{1}.data);
        end
        [~, iSort] = sort(metaDepth);
        xMin = min(xMin);
        xMax = max(xMax);
        set(hAxMooringTemp, 'XTick', (xMin:(xMax-xMin)/4:xMax));
        set(hAxMooringTemp, 'XLim', [xMin, xMax]);
        
        % reverse the colorbar as we want surface in red and bottom in blue
        cMap = colormap(jet(lenSampleData));
        cMap = flipud(cMap);
    
        lineStyle = {'-', '--', ':', '-.'};
        lenLineStyle = length(lineStyle);
        instrumentDesc = cell(lenSampleData, 1);
        hLineVar = nan(lenSampleData, 1);
        for i=1:lenSampleData
            instrumentDesc{i} = sample_data{iSort(i)}.instrument;
            if ~isnan(sample_data{i}.meta.depth)
                metaDepth = sample_data{iSort(i)}.meta.depth;
                instrumentDesc{i} = [instrumentDesc{i} ' (' num2str(metaDepth) 'm)'];
                
                %look for the variable
                lenVar = length(sample_data{iSort(i)}.variables);
                iVar = 0;
                for j=1:lenVar
                    if strcmpi(sample_data{iSort(i)}.variables{j}.name, varName)
                        iVar = j;
                        break;
                    end
                end
                
                if iVar > 0
                    dataVar = sample_data{iSort(i)}.variables{iVar}.data;
                    hLineVar(i) = line(sample_data{iSort(i)}.dimensions{1}.data, ...
                        dataVar, ...
                        'Color', cMap(i, :), ...
                        'LineStyle', lineStyle{mod(i, lenLineStyle)+1});
                end
            else
                fprintf('%s\n', ['Warning : in ' sample_data{iSort(i)}.toolbox_input_file ...
                    ', the ''sample_data.meta.depth'' attribute is not documented.']);
            end
        end
        
        iNan = isnan(hLineVar);
        if any(iNan)
            hLineVar(iNan) = [];
            instrumentDesc(iNan) = [];
        end
        
        datetick(hAxMooringTemp, 'x', 'dd-mm-yy HH:MM:SS', 'keepticks');
        legend(hLineVar, instrumentDesc, 'Location', 'NorthEastOutside');
    end

  function openWikiPage(source,ev)
  %OPENWIKIPAGE opens a new tab in your web-browser to access the
  %IMOS-Toolbox wiki
  %
    url = 'http://code.google.com/p/imos-toolbox/wiki/Sidebar';
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
    error(nargchk(1,1,nargin));
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
  
  function createVarPanel(sam)
  %CREATEVARPANEL Creates the variable selection panel. Called when the
  % selected dataset changes. The panel allows users to select which
  % variables should be displayed.
  %
    % delete checkboxes and dim menu from previous data set
    checkboxes = get(varPanel, 'Children');
    for m = 1:length(checkboxes), delete(checkboxes(m)); end
    
    switch mode
        case 'profile'
            % we don't want to plot TIME, DIRECTION, LATITUDE, LONGITUDE, BOT_DEPTH
            p = 5;
            
            % we don't to plot DEPTH if it's a variable
            depth = getVar(sam.variables, 'DEPTH');
            if depth ~= 0
                sam.variables(depth) = [];
            end
        otherwise
            p = 0;
    end
    
    % create checkboxes for new data set. The order in which the checkboxes
    % are created is the same as the order of the variables - this is
    % important, as the getSelectedParams function assumes that the indices 
    % line up.
    checkboxes(:) = [];
    n = length(sam.variables);
    for m = 1+p:n
      % enable at most 3 variables initially, 
      % otherwise the graph will be cluttered
      val = 1;
      if m-p > 3, val = 0; end
      
%       checkboxes(m) = uicontrol(...
%         'Parent',   varPanel,...
%         'Style',    'checkbox',...
%         'String',   sam.variables{m}.name,...
%         'Value',    val,...
%         'Callback', @varPanelCallback,...
%         'Units',    'normalized',...
%         'Position', [0.0, (n-m)/n, 1.0, 1/n]);
        checkboxes(m-p) = uicontrol(...
        'Parent',   varPanel,...
        'Style',    'checkbox',...
        'String',   sam.variables{m}.name,...
        'Value',    val,...
        'Callback', @varPanelCallback,...
        'Units',    'normalized',...
        'Position', posUi2(varPanel, n-p, 1, m-p, 1, 0));
    end
%     set(checkboxes, 'Units', 'pixels');
    
    % the checkboxes are saved in UserData field to make them 
    % easy to retrieve in the getSelectedVars function
    set(varPanel, 'UserData', checkboxes);
  end
end
