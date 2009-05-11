function mainWindow(...
  fieldTrip, sample_data, cal_data, states, startState, selectionCallback)
%DATAWINDOW Displays a window which allows the user to view data.
%
% The mainWindow is the main toolbox window. It provides menus allowing the
% user to select the data set to use and the graph type to display (if a
% graph is being displayed), enable/disable parameters, and choose the
% dimension to graph against.
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
% Inputs:
%   fieldTrip         - Struct containing information about the field trip 
%                       from which data is being displayed.
%   sample_data       - Cell array of structs of sample data.
%   cal_data          - Cell array of structs of calibration/metadata.
%   states            - Cell array of strings containing state names.
%   startState        - Index into states array, specifying initial state.
%   selectionCallback - A function which is called when the user pushes a 
%                       state button. The function must take the following 
%                       input arguments:
%                         panel       - A uipanel on which things can be drawn.
%                         state       - Currently selected state (String)
%                         sample_data - currently selected sample data
%                         cal_data    - currently selected sample data
%                         graphType   - Currently selected graph type (String)
%                         params      - Currently selected parameters
%                         dim         - Currently selected dimension
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
  error(nargchk(6,6,nargin));

  if ~isstruct(fieldTrip),   error('fieldTrip must be a struct');           end
  if ~iscell(sample_data)...
  || isempty(sample_data),   error('sample_data must be a cell array');     end
  if ~iscell(cal_data)...
  || isempty(cal_data),      error('cal_data must be a cell array');        end
  if ~iscellstr(states),     error('states must be a cell array');          end
  if ~isnumeric(startState), error('initialState must be a numeric');       end
  if ~isa(selectionCallback,... 
         'function_handle'), error('selectionCallback must be a function'); end
  
  currentState = states{startState};
  
  timeFmt = readToolboxProperty('toolbox.timeFormat');
  fId     = fieldTrip.FieldTripID;
  
  % sample menu entries (1-1 mapping to sample_data/cal_data structs)
  sampleDataDescs = genSampleDataDescs(sample_data, cal_data, timeFmt);

  % window figure
  fig = figure(...
    'Name',        ['IMOS Field Trip ' num2str(fId)], ...
    'Visible',     'off',...
    'MenuBar',     'none',...
    'ToolBar',     'figure',...
    'Resize',      'off',...
    'WindowStyle', 'Normal');

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
  sidePanel = uipanel(fig);
  
  % state buttons
  stateButtons = [];
  for k = 1:length(states)
    stateButtons(k) = uicontrol(...
      'Parent', sidePanel,...
      'Style',  'pushbutton',...
      'String', states{k});
  end
  
  % parameter selection panel - created in createParamPanel
  paramPanel = uipanel(sidePanel);
  
  % main display
  mainPanel = uipanel(fig);
  
  % use normalized units
  set(fig,          'Units', 'normalized');
  set(sidePanel,    'Units', 'normalized');
  set(mainPanel,    'Units', 'normalized');
  set(paramPanel,   'Units', 'normalized');
  set(sampleMenu,   'Units', 'normalized');
  set(graphMenu,    'Units', 'normalized');
  set(stateButtons, 'Units', 'normalized');
  
  % set window and widget positions
  set(fig,        'Position', [0.15, 0.15, 0.7,  0.7 ]);
  set(sidePanel,  'Position', [0.0,  0.0,  0.1,  0.95]);
  set(mainPanel,  'Position', [0.1,  0.0,  0.9,  0.95]);
  set(sampleMenu, 'Position', [0.0,  0.95, 0.5,  0.05]);
  set(graphMenu,  'Position', [0.5,  0.95, 0.5,  0.05]);
  
  % paramPanel and stateButtons are positioned relative to sidePanel
  set(paramPanel, 'Position', [0.0,  0.0,  1.0,  0.3 ]);
  
  n = length(stateButtons);
  for k = 1:n
    set(stateButtons(k), 'Position', [0.0, 0.3+(n-k)*(0.7/n), 1.0, 0.7/n]);
  end
  
  % set callbacks - parameter panel widget 
  % callbacks are set in createParamPanel
  set(sampleMenu,   'Callback', @sampleMenuCallback);
  set(graphMenu,    'Callback', @graphMenuCallback);
  set(stateButtons, 'Callback', @stateButtonCallback);
  
  set(fig, 'Visible', 'on');
  createParamPanel(sample_data{1});
  selectionChange();
  uiwait(fig);
  
  %% Callbacks
  
  function selectionChange()
  %Retrieves the current selection, clears the main panel, and calls 
  % selectionCallback.
  % 
    state        = currentState;
    [sam cal]    = getSelectedData();
    [params dim] = getSelectedParams();
    graph        = getSelectedGraphType();
    
    % clear main panel
    children = get(mainPanel, 'Children');
    for k = 1:length(children), delete(children(k)); end
    
    selectionCallback(mainPanel, state, sam, cal, graph, params, dim);
  end
  
  function sampleMenuCallback(source,ev)
  %SAMPLEMENUCALLBACK Called when a dataset is selected from the sample
  % menu. Updates the parameters panel, then delegates to selectionChange.
  % 
    [sam cal] = getSelectedData();
    createParamPanel(sam);
    selectionChange();
  end

  function graphMenuCallback(source,ev)
  %GRAPHMENUCALLBACK Called when the user changes the graph type via the
  % graph selection menu. Delegates to selectionChange.
  %
    selectionChange();
  end

  function stateButtonCallback(source, ev)
  %STATEBUTTONCALLBACK Called when the user pushes a state button. Updates
  % the current state, then delegates to selectionChange.
  %
    currentState = get(source, 'String');
    selectionChange();
  end

  function paramPanelCallback(source,ev)
  %PARAMPANELCALLBACK Called when the parameter or dimension selection 
  % changes. Delegates to selectionChange.
  %
    selectionChange();
  end

  %% Retrieving current selection

  function [sam cal] = getSelectedData()
  %GETSELECTEDDATA Returns the currently selected sample_data/cal_data
  %pair.
  %
    idx = get(sampleMenu, 'Value');
    
    sam = sample_data{idx};
    cal = cal_data   {idx};
  end

  function graphType = getSelectedGraphType()
  %GETSELECTEDGRAPHTYPE Returns the currently selected graph type.
  %
    idx   = get(graphMenu, 'Value');
    types = get(graphMenu, 'String');
    
    graphType = types{idx};
    
  end

  function [params dim] = getSelectedParams()
  %GETSELECTEDPARAMS Returns a vector containing the indices of the
  % parameters and dimension which are selected.
  %
  
    % menu and checkboxes are stored in user data
    fields     = get(paramPanel, 'UserData');
    dimMenu    = fields{1};
    checkboxes = fields{2};
    
    dim = get(dimMenu, 'Value');
    
    params = [];
    
    for k = 1:length(checkboxes)
      if get(checkboxes(k), 'Value'), params(end+1) = k; end
    end
  end

  %% Miscellaneous
  
  function createParamPanel(sam)
  %CREATEPARAMPANEL Creates the parameter selection panel. Called when the
  % selected dataset changes. The panel allows users to select which
  % parameters should be displayed, and against which dimension they should 
  % be graphed.
  %
    % delete checkboxes and dim menu from previous data set
    checkboxes = get(paramPanel, 'Children');
    for k = 1:length(checkboxes), delete(checkboxes(k)); end
    
    % create checkboxes for new data set. The order in which the checkboxes
    % are created is the same as the order of the parameters - this is
    % important, as the getSelectedParams function assumes that the indices 
    % line up.
    checkboxes(:) = [];
    n = length(sam.parameters);
    for k = 1:n
      
      checkboxes(k) = uicontrol(...
        'Parent',   paramPanel,...
        'Style',    'checkbox',...
        'String',   sam.parameters(k).name,...
        'Value',    1,...
        'Callback', @paramPanelCallback,...
        'Units',    'normalized',...
        'Position', [0.0, (n-k+1)/(n+1), 1.0, 1/(n+1)]);
    end
        
    % add dimension menu - again, the getSelectedParams  function assumes
    % that the indices into the menu options line up with the 
    % sample_data.dimension vector
    dims = {sam.dimensions.name};
    dimMenu = uicontrol(...
      'Parent',   paramPanel,...
      'Style',    'popupmenu',...
      'String',   dims,...
      'Value',    1,...
      'Units',    'normalized',...
      'Callback', @paramPanelCallback,...
      'Position', [0.0, 0.0, 1.0, 1/(n+1)]);
    
    % the dimension menu and checkboxes are saved in UserData field to 
    % make them easy to retrieve in the getSelectedParams function
    set(paramPanel, 'UserData', {dimMenu checkboxes});
  end

  function descs = genSampleDataDescs(sam, cal, dateFmt)
  %GENSAMPLEDATADESCS Generates descriptions for the given datasets, for use
  % in the sample menu.
  %
    descs = {};

    for k = 1:length(sam)
      s = sam{k};
      c = cal{k};

      descs{k} = [c.instrument_make  ' ' ...
                  c.instrument_model ' ' ...
                  datestr(s.dimensions(1).data(1),   dateFmt) ' - ' ...
                  datestr(s.dimensions(1).data(end), dateFmt)];
    end
  end
end
