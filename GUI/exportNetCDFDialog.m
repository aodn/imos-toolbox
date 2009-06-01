function [exportDir sets] = exportNetCDFDialog( rawData, qcData )
%EXPORTNETCDFDIALOG Prompts the user to select an output directory in which
% to save the NetCDF file(s) which are to be generated for the given data
% sets. 
%
% For the given data sets, prompts the user to select an output directory,
% and which data sets and process levels that should be exported as NetCDF
% files. The selected directory and data sets are returned.
%
% Inputs:
%   rawData   - Cell array containing raw data sets.
%
%   qcData    - Cell array containing qc'd data sets. If QC has not yet been
%               performed, this array may be empty. Otherwise it must be the
%               same length as rawData.
%
% Outputs:
%   exportDir - absolute path to the selected output directory.
%
%   sets      - Cell array containnig the selected data sets to be exported.
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
  error(nargchk(2,2,nargin));

  if ~iscell(rawData), error('rawData must be a cell array'); end
  if ~iscell(qcData),  error('qcData must be a cell array');  end

  if ~isempty(qcData) && length(qcData) ~= length(rawData)
    error('qcData must be empty, or the same length as rawData'); 
  end

  exportDir       = pwd;
  selectedSets    = zeros(size(rawData));
  selectedSets(:) = 1;
  selectedLevels  = []; % populated when the level checkboxes are created
  
  try
    exportDir = readToolboxProperty('exportNetCDFDialog.defaultDir');
  catch e
  end
  
  descs = genDataSetDescs(rawData);
  
  % dialog figure
  f = figure(...
    'Name',        'Choose export options',...
    'Visible',     'off',...
    'MenuBar',     'none',...
    'Resize',      'off',...
    'WindowStyle', 'modal'...
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
  
  levels{1} = 'Raw';
  if ~isempty(qcData), levels{2} = 'QC'; end
  
  levelCheckboxes = [];
  for k = 1:length(levels)
    
    levelCheckboxes(k) = uicontrol(...
      'Style',    'checkbox',...
      'String',   levels{k},...
      'Value',    1,...
      'UserData', k ...
    );
    selectedLevels(k) = 1;
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
  set(f,             'Position', [0.4,  0.4, 0.2,  0.2]);
  set(cancelButton,  'Position', [0.0,  0.0, 0.5,  0.1]);
  set(confirmButton, 'Position', [0.5,  0.0, 0.5,  0.1]);
  set(dirLabel,      'Position', [0.0,  0.1, 0.15, 0.1]);
  set(dirText,       'Position', [0.15, 0.1, 0.8,  0.1]);
  set(dirButton,     'Position', [0.85, 0.1, 0.15, 0.1]);
  set(levelLabel,    'Position', [0.0,  0.2, 0.15, 0.1]);
    
  % position data level checkboxes
  for k = 1:length(levelCheckboxes)
    
    lLength = 0.85 / length(levelCheckboxes);
    lStart  = 0.15 + (0.85 * (k-1)) / length(levelCheckboxes);
    
    set(levelCheckboxes(k), 'Position', [lStart, 0.2, lLength, 0.1]);
  end
  
  % position data set checkboxes
  for k = 1:length(setCheckboxes)
    
    bLength = 0.7 / length(setCheckboxes);
    bStart = 0.3 + (((k-1) * 0.7) / length(setCheckboxes));
    
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
  rawData = rawData(logical(selectedSets));
  if selectedLevels(1)
    sets = rawData;
  end
  
  if ~isempty(qcData) && selectedLevels(2)
    qcData = qcData(logical(selectedSets)); 
    sets = [sets qcData];
  end
  
  % save the export directory for next time
  writeToolboxProperty('exportNetCDFDialog.defaultDir', exportDir);
  
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
  
  function descs = genDataSetDescs(dataSets)
  %GENDATASETDESCS Generates a description for the given data sets, to be
  %used in the dialog display.
  %
    descs = {};
    
    for k = 1:length(dataSets)
      set = dataSets{k};
      
      descs{k} = [set.instrument_model genNetCDFFileName(set)];
    end
  end
end
