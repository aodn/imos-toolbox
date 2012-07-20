function [exportDir sets] = exportDialog( ...
  dataSets, levelNames, setNames, varOpts )
%EXPORTDIALOG Prompts the user to select an output directory in which to 
% save the file(s) which are to be generated for the given data sets. 
%
% For the given data sets, prompts the user to select an output directory,
% and which data sets that should be exported. The selected directory and 
% data sets are returned.
%
% The dataSets input parameter is a cell array, where each entry is a cell
% array of sample data structs. Each struct is referred to as a data set.
% Each array of structs is referred to as a level (i.e. 'Raw' level, 'QC'
% level). Each level must be of the same length.
%
% Inputs:
%   dataSets   - Cell array, where each element is a cell array of sample 
%                data structs.
%
%   levelNames - Names of each data level (e.g. 'raw', 'qc').
%
%   setNames   - Names of each data set (e.g. filenames).
%
%   varOpts    - Logical value - if true, the user will be able to choose
%                which variables to export for each data set..
%
% Outputs:
%   exportDir  - absolute path to the selected output directory.
%
%   sets       - Cell array containing the selected data sets to be exported.
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
  error(nargchk(4,4,nargin));

  if ~iscell(dataSets),      error('dataSets must be a cell array');        end
  if ~iscellstr(levelNames), error('levelNames must be a char cell array'); end
  if ~iscellstr(setNames),   error('setNames must be a char cell array');   end
  if ~islogical(varOpts),    error('varOpts must be logical');              end
  if isempty(dataSets),      error('dataSets cannot be empty');             end
  if length(dataSets) ~= length(levelNames)
    error('dataSets and levelNames must be the same length'); 
  end
  
  numLevels = length(dataSets);
  numSets   = length(dataSets{1});
  for k = 2:length(dataSets)
    if length(dataSets{k}) ~= numSets, error('data set length mismatch'); end
  end
  if length(setNames) ~= numSets, error('set name length mismatch'); end

  % all of these variables store the current settings
  exportDir         = pwd;
  selectedLevels    = zeros(numSets, numLevels);
  selectedLevels(:) = 1;
  selectedVars      = cell(numSets, 1);
  for k = 1:length(selectedVars)
    selectedVars{k} = zeros(length(dataSets{1}{k}.variables), 1);
    selectedVars{k}(:) = 1;
  end
  
  % use default export dir if present
  try
    exportDir = readProperty('exportDialog.defaultDir');
  catch e
  end
  
  descs = {};
  for k = 1:length(dataSets{1})
    descs{k} = genSampleDataDesc(dataSets{1}{k});
  end
  
  % dialog figure
  f = figure(...
    'Name',        'Export',...
    'Visible',     'off',...
    'MenuBar',     'none',...
    'Resize',      'off',...
    'WindowStyle', 'modal',...
    'NumberTitle', 'off'...
  );

  % panel which contains data set tabs
  tabPanel = uipanel(...
    'Parent',     f,...
    'BorderType', 'none'...
  );

  % create text entry/directory browse button
  dirLabel  = uicontrol('Style', 'text',       'String', 'Directory');
  dirText   = uicontrol('Style', 'edit',       'String',  exportDir);
  dirButton = uicontrol('Style', 'pushbutton', 'String', 'Browse');
  set([dirLabel, dirText], 'HorizontalAlignment', 'Left');
  
  % ok/cancel buttons
  cancelButton  = uicontrol('Style', 'pushbutton', 'String', 'Cancel');
  confirmButton = uicontrol('Style', 'pushbutton', 'String', 'Ok');
  
  % replicate button for output format
  repButton = uicontrol('Style', 'pushbutton', 'String', 'Replicate');
  
  % use normalized units for positioning
  set(f,             'Units', 'normalized');
  set(tabPanel,      'Units', 'normalized');
  set(dirLabel,      'Units', 'normalized');
  set(dirText,       'Units', 'normalized');
  set(dirButton,     'Units', 'normalized');
  set(cancelButton,  'Units', 'normalized');
  set(confirmButton, 'Units', 'normalized');
  set(repButton,     'Units', 'normalized');
  
  % position widgets
  set(f,             'Position', [0.25, 0.35, 0.5,  0.3]);
  set(cancelButton,  'Position', [0.0,  0.0,  0.5,  0.1]);
  set(confirmButton, 'Position', [0.5,  0.0,  0.5,  0.1]);
  set(dirLabel,      'Position', [0.0,  0.1,  0.15, 0.1]);
  set(dirText,       'Position', [0.15, 0.1,  0.8,  0.1]);
  set(dirButton,     'Position', [0.85, 0.1,  0.15, 0.1]);
  set(tabPanel,      'Position', [0.0,  0.2,  1.0,  0.8]);
  set(repButton,     'Position', [0.85, 0.2,  0.15, 0.1]);
  
  % reset back to pixel units
  set(f,             'Units', 'pixels');
  set(tabPanel,      'Units', 'pixels');
  set(dirLabel,      'Units', 'pixels');
  set(dirText,       'Units', 'pixels');
  set(dirButton,     'Units', 'pixels');
  set(cancelButton,  'Units', 'pixels');
  set(confirmButton, 'Units', 'pixels');
  set(repButton,     'Units', 'pixels');

  % create a panel for each data set
  setPanels = [];
  for k = 1:numSets
    setPanels(k) = uipanel(...
      'BorderType', 'none',...
      'UserData',    k); 
  end
  
  % put the panels into a tabbed pane
  tabbedPane(tabPanel, setPanels, descs, false);
  
  % populate the panels
  for k = 1:numSets
    
    % label for level checkboxes (below)
    levelLabel = uicontrol(...
      'Parent',              setPanels(k),...
      'Style',               'text',...
      'String',              'Levels', ...
      'HorizontalAlignment', 'Left' ...
    );

    % checkboxes allowing user to (de-)select levels
    levelCheckboxes = [];
    for m = 1:length(levelNames)

      levelCheckboxes(m) = uicontrol(...
        'Parent',   setPanels(k),...
        'Style',    'checkbox',...
        'String',   levelNames{m},...
        'Value',    1,...
        'Tag',      ['levelCheckboxes' num2str(m)],...
        'UserData', m ...
      );
    end
    
    if varOpts
      % label for variable checkboxes (below)
      varLabel = uicontrol(...
        'Parent',              setPanels(k),...
        'Style',               'text',...
        'String',              'Variables',...
        'HorizontalAlignment', 'Left'...
      );

      % checkbox allowing user to select 
      % which variables to export
      varCheckboxes = [];
      l = 0;
      for m = 1:length(dataSets{1}{k}.variables)
        
        if any(strcmpi(dataSets{1}{k}.variables{m}.name, {'TIME', 'DIRECTION', 'LATITUDE', 'LONGITUDE'})), continue; end
        
        l = l + 1;
        varCheckboxes(l) = uicontrol(...
          'Parent',   setPanels(k),...
          'Style',    'checkbox',...
          'String',   dataSets{1}{k}.variables{m}.name,...
          'Value',    1,...
          'UserData', m...
        );
      end
    end
    
    % set callbacks for level/variable selection
    set(levelCheckboxes, 'Callback', @levelCheckboxCallback);
    if varOpts
      set(varCheckboxes, 'Callback', @varCheckboxCallback);
    end
    
    % use normalized units for positioning
    set(levelLabel,      'Units', 'normalized');
    set(levelCheckboxes, 'Units', 'normalized');
    
    if varOpts
      set(varCheckboxes, 'Units', 'normalized');
      set(varLabel,      'Units', 'normalized');
    end
    
    % position widgets (panel is positioned when it is added to tabbedPane)
    set(levelLabel, 'Position', [0.0,  0.0,  0.15, 0.2]);
    if varOpts
      set(varLabel, 'Position', [0.0,  0.2,  0.15, 0.7]);
    end
    
    % position data level checkboxes
    for m = 1:length(levelCheckboxes)

      lLength = 0.85 / length(levelCheckboxes);
      lStart  = 0.15 + (0.85 * (m-1)) / length(levelCheckboxes);

      set(levelCheckboxes(m), 'Position', [lStart, 0.0, lLength, 0.2]);
    end
    
    % position var checkboxes in two columns
    if varOpts
      
      % number of rows in first column - if an odd number of 
      % vars, number of rows in second column will be one less
      numRows = ceil(length(varCheckboxes) / 2);
      
      vHeight = 0.7 / numRows;
      
      for m = 1:length(varCheckboxes)
        
        % figure out vertical start position of this variable's row
        vStart = vHeight * mod(m,numRows);
        if vStart == 0, vStart = vHeight * numRows; end
        vStart = 0.9 - vStart;
        
        hStart = 0.15;
        
        % second half of variable list -> second column
        if m > numRows, hStart = 0.575; end
        set(varCheckboxes(m), 'Position', [hStart, vStart, 0.425, vHeight]);
      end
    end
    
    set(levelLabel,      'Units', 'pixels');
    set(levelCheckboxes, 'Units', 'pixels');
    if varOpts
      set(varCheckboxes, 'Units', 'pixels'); 
      set(varLabel,      'Units', 'pixels');
    end
  end
  
  % set widget callbacks
   set(f,               'WindowKeyPressFcn', @keyPressCallback);
   set(f,               'CloseRequestFcn',   @cancelButtonCallback);
   set(dirText,         'Callback',          @dirTextCallback);
   set(dirButton,       'Callback',          @dirButtonCallback);
   set(cancelButton,    'Callback',          @cancelButtonCallback);
   set(confirmButton,   'Callback',          @confirmButtonCallback);
   set(repButton,       'Callback',          @repButtonCallback);
  
  % display and wait
  set(f, 'Visible', 'on');
  uiwait(f);
  
  % user cancelled dialog
  if isempty(exportDir), return; end
  
  % get selected data sets
  sets = {};
  
  for k = 1:numSets
    
    vars   = selectedVars{k};
    levels = selectedLevels(k,:);
    
    % no levels selected for this data set - no data to output
    if ~any(levels), continue; end
    
    
    % the dataSets array is organised by level then set - 
    % rearrange to get  all levels for the current set
    s = {};
    
    for m = 1:numLevels, s{end+1} = dataSets{m}{k}; end
    
    % delete unselected levels from data set
    s(~logical(levels)) = [];
    
    for m = 1:length(s)
      
      % delete unselected variables from data set
      s{m}.variables(~logical(vars)) = [];

      % no variables were selected - no data to output
      if isempty(s{m}.variables), continue; end;

      % save data set
      sets{end+1} = s{m};
    end    
  end
  
  % save the export directory for next time
  writeProperty('exportDialog.defaultDir', exportDir);
  
  return;
  
  function keyPressCallback(source,ev)
  %KEYPRESSCALLBACK If the user pushes escape/return while the dialog has 
  % focus, the dialog is cancelled/confirmed. This is done by delegating 
  % to the cancelButtonCallback/confirmButtonCallback functions.
  %
    if     strcmp(ev.Key, 'escape'), cancelButtonCallback( source,ev); 
    elseif strcmp(ev.Key, 'return'), confirmButtonCallback(source,ev); 
    end
  end

  function dirTextCallback(source,ev)
  %DIRTEXTCALLBACK Captures the text entered by the user.
  % 
    newDir = get(source, 'String');
    
    % ignore invalid input
    if ~isdir(newDir), set(source, 'String', exportDir); return; end
    
    exportDir = newDir;
  end

  function dirButtonCallback(source,ev)
  %DIRBUTTONCALLBACK Opens a directory browser, prompting the user to
  % select a directory.
  %
    newDir = '';
    
    while ~isdir(newDir)
      newDir = uigetdir(exportDir, 'Select Data Directory');
    
      % user cancelled dialog 
      if newDir == 0, return; end
    end
    
    % update dirText text field
    exportDir = newDir;
    set(dirText, 'String', exportDir);
  end

  function cancelButtonCallback(source,ev)
  %CANCELBUTTONCALLBACK Discards user input, and closes the dialog.
  % 
    sets      = {};
    exportDir = '';
    delete(f);
  end

  function confirmButtonCallback(source,ev)
  %CONFIRMBUTTONCALLBACK Closes the dialog.
  % 
    delete(f);
  end

  function varCheckboxCallback(source,ev)
  %VARCHECKBOXCALLBACK Saves the variable selection for the current data set.
  %
    varIdx = get(source, 'UserData');
    setIdx = get(get(source, 'Parent'), 'UserData');
    selectedVars{setIdx}(varIdx) = get(source, 'Value');
  end

  function levelCheckboxCallback(source,ev)
  %LEVELCHECKBOXCALLBACK Saves the process level selection for the current
  %data set.
  %
    lvlIdx = get(source, 'UserData');
    setIdx = get(get(source, 'Parent'), 'UserData');
    
    selectedLevels(setIdx, lvlIdx) = get(source, 'Value');
  end

    function repButtonCallback(source,ev)
    %REPBUTTONCALLBACK Replicates the selected output levels from the
    %current data set to all the others.
    %
        [nDataSet, nlevel] = size(selectedLevels);
    
        % get level definition from current data set
        curTab = get(tabPanel, 'Children');
        curPop = findobj(curTab, 'Tag', 'exportPopUpMenu');
        curK = get(curPop, 'Value');
        curLevel = selectedLevels(curK, :);
        
        allPan = get(curTab, 'Children');
        allPan(allPan == curPop) = [];
        
        for i=1:nDataSet
            for j=1:nlevel
                % replicate to all data sets
                selectedLevels(i, j) = curLevel(j);
                
                % update the relevant uipanels
                hCurCheck = findobj(allPan(i), 'Tag',      ['levelCheckboxes' num2str(j)]);
                if curLevel(j) == 1
                    set(hCurCheck, 'Value', get(hCurCheck,'Max'));
                else
                    set(hCurCheck, 'Value', get(hCurCheck,'Min'));
                end
            end
        end
    end
end
