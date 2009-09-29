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
  sampleDataDescs = {};
  for k = 1:length(sample_data)
    sampleDataDescs{k} = genSampleDataDesc(sample_data{k});
  end

  % window figure
  fig = figure(...
    'Name',        windowTitle, ...
    'Visible',     'off',...
    'MenuBar',     'none',...
    'ToolBar',     'figure',...
    'Resize',      'off',...
    'WindowStyle', 'Normal',...
    'NumberTitle', 'off');

  % sample data selection menu
  sampleMenu = uicontrol(...
    'Style',  'popupmenu',...
    'String', sampleDataDescs,...
    'Value',  1);
  
  % graph type selection menu
  graphMenu = uicontrol(...
    'Style', 'popupmenu',...
    'String', listGraphs(),...
    'Value', 1);
  
  % side panel
  sidePanel = uipanel(...
    'Parent',     fig,...
    'BorderType', 'none');
  
  % state buttons
  stateButtons = [];
  for k = 1:length(states)
    stateButtons(k) = uicontrol(...
      'Parent', sidePanel,...
      'Style',  'pushbutton',...
      'String', states{k});
  end
  
  % variable selection panel - created in createVarPanel
  varPanel = uipanel(...
    'Parent',     sidePanel,...
    'BorderType', 'none');
  
  % main display
  mainPanel = uipanel(...
    'Parent',     fig,...
    'BorderType', 'none');
  
  % use normalized units
  set(fig,          'Units', 'normalized');
  set(sidePanel,    'Units', 'normalized');
  set(mainPanel,    'Units', 'normalized');
  set(varPanel,     'Units', 'normalized');
  set(sampleMenu,   'Units', 'normalized');
  set(graphMenu,    'Units', 'normalized');
  set(stateButtons, 'Units', 'normalized');
  
  % set window and widget positions
  set(fig,        'Position', [0.1,  0.15, 0.8,  0.7 ]);
  set(sidePanel,  'Position', [0.0,  0.0,  0.15, 0.95]);
  set(mainPanel,  'Position', [0.15, 0.0,  0.85, 0.95]);
  set(sampleMenu, 'Position', [0.0,  0.95, 0.75, 0.05]);
  set(graphMenu,  'Position', [0.75, 0.95, 0.25, 0.05]);
  
  % varPanel and stateButtons are positioned relative to sidePanel
  set(varPanel, 'Position', [0.0,  0.0,  1.0,  0.5]);
  
  n = length(stateButtons);
  for k = 1:n
    set(stateButtons(k), 'Position', [0.0, 0.5+(n-k)*(0.5/n), 1.0, 0.5/n]);
  end
  
  % reset back to pixels
  set(fig,          'Units', 'pixels');
  set(sidePanel,    'Units', 'pixels');
  set(mainPanel,    'Units', 'pixels');
  set(varPanel,     'Units', 'pixels');
  set(sampleMenu,   'Units', 'pixels');
  set(graphMenu,    'Units', 'pixels');
  set(stateButtons, 'Units', 'pixels');
  
  % set callbacks - variable panel widget 
  % callbacks are set in createParamPanel
  set(sampleMenu,   'Callback', @sampleMenuCallback);
  set(graphMenu,    'Callback', @graphMenuCallback);
  set(stateButtons, 'Callback', @stateButtonCallback);
  
  set(fig, 'Visible', 'on');
  createVarPanel(sample_data{1});
  selectionChange('state');
  
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
    for m = 1:length(children), delete(children(m)); end
    
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

  function varPanelCallback(source,ev)
  %PARAMPANELCALLBACK Called when the variable or dimension selection 
  % changes. Delegates to selectionChange.
  %
    selectionChange('var');
  end

  %% Data update callback
  
  function updateCallback(sam)
  %UPDATECALLBACK Called when a data set has been modified. Saves the new
  % copy of the data set.
  %
    error(nargchk(1,1,nargin));
    if ~isstruct(sam),              error('sam must be a struct');         end
    if ~isfield(sam.meta, 'index'), error('sam must have an index field'); end
    
    % a new data set is being added
    updateMenus = 0;
    if sam.meta.index > length(sample_data), updateMenus = 1; end
    
    sample_data{sam.meta.index} = sam;
    
    % regenerate descriptions
    sampleDataDescs = {};
    for k = 1:length(sample_data)
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
    
    % create checkboxes for new data set. The order in which the checkboxes
    % are created is the same as the order of the variables - this is
    % important, as the getSelectedParams function assumes that the indices 
    % line up.
    checkboxes(:) = [];
    n = length(sam.variables);
    for m = 1:n
      
      % enable at most 3 variables initially, 
      % otherwise the graph will be cluttered
      val = 1;
      if m > 3, val = 0; end
      
      checkboxes(m) = uicontrol(...
        'Parent',   varPanel,...
        'Style',    'checkbox',...
        'String',   sam.variables{m}.name,...
        'Value',    val,...
        'Callback', @varPanelCallback,...
        'Units',    'normalized',...
        'Position', [0.0, (n-m)/n, 1.0, 1/n]);
    end
    set(checkboxes, 'Units', 'pixels');
    
    % the checkboxes are saved in UserData field to make them 
    % easy to retrieve in the getSelectedVars function
    set(varPanel, 'UserData', checkboxes);
  end
end