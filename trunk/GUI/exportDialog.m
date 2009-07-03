function [exportDir sets] = exportDialog( dataSets, levelNames, setNames )
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
  error(nargchk(3,3,nargin));

  if ~iscell(dataSets),      error('dataSets must be a cell array');        end
  if ~iscellstr(levelNames), error('levelNames must be a char cell array'); end
  if ~iscellstr(setNames),   error('setNames must be a char cell array');   end
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

  exportDir         = pwd;
  selectedSets      = zeros(numSets, 1);
  selectedSets(:)   = 1;
  selectedLevels    = zeros(numLevels, 1);
  selectedLevels(:) = 1;
  
  try
    exportDir = readToolboxProperty('exportDialog.defaultDir');
  catch e
  end
  
  descs = genDataSetDescs(dataSets{1}, setNames);
  
  % dialog figure
  f = figure(...
    'Name',        'Choose export options',...
    'Visible',     'off',...
    'MenuBar',     'none',...
    'Resize',      'off',...
    'WindowStyle', 'modal',...
    'NumberTitle', 'off'...
  );

  % create checkboxes allowing user to (de-)select data sets
  setCheckboxes = [];
  for k = 1:length(descs)
    
    setCheckboxes(k) = uicontrol(...
      'Style',    'checkbox',...
      'String',   descs{k},...
      'Value',    1,...
      'UserData', k ...
    );
  end
  
  % create checkboxes allowing user to (de-)select levels
  levelLabel = uicontrol(...
    'Style',               'text',...
    'String',              'Levels', ...
    'HorizontalAlignment', 'Left' ...
  );
  
  levelCheckboxes = [];
  for k = 1:length(levelNames)
    
    levelCheckboxes(k) = uicontrol(...
      'Style',    'checkbox',...
      'String',   levelNames{k},...
      'Value',    1,...
      'UserData', k ...
    );
  end
  
  % create text entry/directory browse button
  dirLabel  = uicontrol('Style', 'text',       'String', 'Directory');
  dirText   = uicontrol('Style', 'edit',       'String',  exportDir);
  dirButton = uicontrol('Style', 'pushbutton', 'String', 'Browse');
  set([dirLabel, dirText], 'HorizontalAlignment', 'Left');
  
  % ok/cancel buttons
  cancelButton  = uicontrol('Style', 'pushbutton', 'String', 'Cancel');
  confirmButton = uicontrol('Style', 'pushbutton', 'String', 'Ok');
  
  % use normalized units for positioning
  set(f,               'Units', 'normalized');
  set(setCheckboxes,   'Units', 'normalized');
  set(levelLabel,      'Units', 'normalized');
  set(levelCheckboxes, 'Units', 'normalized');
  set(dirLabel,        'Units', 'normalized');
  set(dirText,         'Units', 'normalized');
  set(dirButton,       'Units', 'normalized');
  set(cancelButton,    'Units', 'normalized');
  set(confirmButton,   'Units', 'normalized');
  
  % position widgets
  set(f,             'Position', [0.25, 0.35, 0.5,  0.3]);
  set(cancelButton,  'Position', [0.0,  0.0,  0.5,  0.15]);
  set(confirmButton, 'Position', [0.5,  0.0,  0.5,  0.15]);
  set(dirLabel,      'Position', [0.0,  0.15, 0.15, 0.15]);
  set(dirText,       'Position', [0.15, 0.15, 0.8,  0.15]);
  set(dirButton,     'Position', [0.85, 0.15, 0.15, 0.15]);
  set(levelLabel,    'Position', [0.0,  0.3,  0.15, 0.15]);
    
  % position data level checkboxes
  for k = 1:length(levelCheckboxes)
    
    lLength = 0.85 / length(levelCheckboxes);
    lStart  = 0.15 + (0.85 * (k-1)) / length(levelCheckboxes);
    
    set(levelCheckboxes(k), 'Position', [lStart, 0.3, lLength, 0.15]);
  end
  
  % position data set checkboxes
  for k = 1:length(setCheckboxes)
    
    bLength = 0.55 / length(setCheckboxes);
    bStart = 0.45 + ((k-1) * bLength);
    
    set(setCheckboxes(k), 'Position', [0.0, bStart, 1.0, bLength]);
  end
  
  % reset back to pixel units
  set(f,               'Units', 'pixels');
  set(setCheckboxes,   'Units', 'pixels');
  set(levelLabel,      'Units', 'pixels');
  set(levelCheckboxes, 'Units', 'pixels');
  set(dirLabel,        'Units', 'pixels');
  set(dirText,         'Units', 'pixels');
  set(dirButton,       'Units', 'pixels');
  set(cancelButton,    'Units', 'pixels');
  set(confirmButton,   'Units', 'pixels');
  
  % set widget callbacks
  set(f,               'WindowKeyPressFcn', @keyPressCallback);
  set(f,               'CloseRequestFcn',   @cancelButtonCallback);
  set(setCheckboxes,   'Callback',          @setCheckboxCallback);
  set(levelCheckboxes, 'Callback',          @levelCheckboxCallback);
  set(dirText,         'Callback',          @dirTextCallback);
  set(dirButton,       'Callback',          @dirButtonCallback);
  set(cancelButton,    'Callback',          @cancelButtonCallback);
  set(confirmButton,   'Callback',          @confirmButtonCallback);
  
  % display and wait
  set(f, 'Visible', 'on');
  uiwait(f);
  
  % user cancelled dialog
  if isempty(exportDir), return; end
  
  % get selected data sets
  sets = {};
  dataSets = dataSets(logical(selectedLevels));
  for k = 1:length(dataSets)
    
    dataSet = dataSets{k};
    dataSet = dataSet(logical(selectedSets));
    sets    = [sets dataSet{:}];
  end
  
  % save the export directory for next time
  writeToolboxProperty('exportDialog.defaultDir', exportDir);
  
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

  function setCheckboxCallback(source,ev)
  %SETCHECKBOXCALLBACK Saves the current data set selection.
  %
    idx = get(source, 'UserData');
    selectedSets(idx) = get(source, 'Value');
  end

  function levelCheckboxCallback(source,ev)
  %LEVELCHECKBOXCALLBACK Saves the current process level selection.
  
    idx = get(source, 'UserData');
    selectedLevels(idx) = get(source, 'Value');
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
  
  function descs = genDataSetDescs(sets, names)
  %GENDATASETDESCS Generates a description for the given data sets, to be
  %used in the dialog display.
  %
    descs = {};
    
    for k = 1:length(sets)
      s = sets{k};
      
      descs{k} = ['(' s.instrument_model ')' names{k}];
      
      if isfield(s.meta, 'site')
        descs{k} = [s.meta.site.SiteName ' ' descs{k}];
      end
    end
  end
end
