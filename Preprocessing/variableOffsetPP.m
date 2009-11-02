function sample_data = variableOffsetPP( sample_data )
%VARIABLEOFFSETPP Allows the user to apply a linear offset to the variables
% in the given data sets.
%
% Displays a dialog which allows the user to apply linear offsets to each
% variable in the given data sets.
%
% Inputs:
%   sample_data - cell array of structs, the data sets for which the starting 
%                 time should be modified.
%
% Outputs:
%   sample_data - same as input, with starting time modified.
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
  error(nargchk(1,1,nargin));

  if ~iscell(sample_data), error('sample_data must be a cell array'); end
  if isempty(sample_data), return;                                    end
  
  % generate descriptions for each data set
  descs = {};
  for k = 1:length(sample_data)
    descs{k} = genSampleDataDesc(sample_data{k});
  end
  
  % cell array of numeric arrays, representing the offsets to 
  % be applied to each variable in each data set; populated 
  % when the panels for each data set are populated
  offsets = {};
  
  % dialog figure
  f = figure(...
    'Name',        'Variable Offset',...
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

  % ok/cancel buttons
  cancelButton  = uicontrol('Style', 'pushbutton', 'String', 'Cancel');
  confirmButton = uicontrol('Style', 'pushbutton', 'String', 'Ok');
    
  % use normalized units for positioning
  set(f,             'Units', 'normalized');
  set(cancelButton,  'Units', 'normalized');
  set(confirmButton, 'Units', 'normalized');
  set(tabPanel,      'Units', 'normalized');
  
  % position widgets
  set(f,             'Position', [0.25, 0.35, 0.5,  0.3]);
  set(cancelButton,  'Position', [0.0,  0.0,  0.5,  0.1]);
  set(confirmButton, 'Position', [0.5,  0.0,  0.5,  0.1]);
  set(tabPanel,      'Position', [0.0,  0.1,  1.0,  0.9]);
  
  % reset back to pixels
  set(f,             'Units', 'pixels');
  set(cancelButton,  'Units', 'pixels');
  set(confirmButton, 'Units', 'pixels');
  set(tabPanel,      'Units', 'pixels');
  
  % create a panel for each data set
  setPanels = [];
  for k = 1:length(sample_data)
    
    setPanels(k) = uipanel('BorderType', 'none','UserData', k); 
  end
  
  % put the panels into a tabbed pane
  tabbedPane(tabPanel, setPanels, descs, false);
  
  % populate the data set panels
  for k = 1:length(sample_data)
    
    nVars = length(sample_data{k}.variables);
    rowHeight = 1.0 / (nVars + 1);
    offsets{k} = zeros(nVars,1);
    
    % column headers
    varHeaderLabel    = uicontrol('Parent', setPanels(k), 'Style', 'text', ...
      'String', 'Variable', 'FontWeight', 'bold');
    minHeaderLabel    = uicontrol('Parent', setPanels(k), 'Style', 'text', ...
      'String', 'Minimum',  'FontWeight', 'bold');
    meanHeaderLabel   = uicontrol('Parent', setPanels(k), 'Style', 'text', ...
      'String', 'Mean',     'FontWeight', 'bold');
    maxHeaderLabel    = uicontrol('Parent', setPanels(k), 'Style', 'text', ...
      'String', 'Maximum',  'FontWeight', 'bold');
    offsetHeaderLabel = uicontrol('Parent', setPanels(k), 'Style', 'text', ...
      'String', 'Offset',   'FontWeight', 'bold');
    
    % position headers
    set(varHeaderLabel,    'Units', 'normalized');
    set(minHeaderLabel,    'Units', 'normalized');
    set(meanHeaderLabel,   'Units', 'normalized');
    set(maxHeaderLabel,    'Units', 'normalized');
    set(offsetHeaderLabel, 'Units', 'normalized');
    
    set(varHeaderLabel,    'Position', [0.0, 0.95 - rowHeight, 0.2, rowHeight]);
    set(minHeaderLabel,    'Position', [0.2, 0.95 - rowHeight, 0.2, rowHeight]);
    set(meanHeaderLabel,   'Position', [0.4, 0.95 - rowHeight, 0.2, rowHeight]);
    set(maxHeaderLabel,    'Position', [0.6, 0.95 - rowHeight, 0.2, rowHeight]);
    set(offsetHeaderLabel, 'Position', [0.8, 0.95 - rowHeight, 0.2, rowHeight]);
    
    set(varHeaderLabel,    'Units', 'pixels');
    set(minHeaderLabel,    'Units', 'pixels');
    set(meanHeaderLabel,   'Units', 'pixels');
    set(maxHeaderLabel,    'Units', 'pixels');
    set(offsetHeaderLabel, 'Units', 'pixels');
    
    % column values (one row for each variable)
    for m = 1:nVars
      
      v = sample_data{k}.variables{m};
      
      varLabel    = uicontrol(...
        'Parent', setPanels(k), 'Style', 'text', 'String', v.name);
      minLabel    = uicontrol(...
        'Parent', setPanels(k), 'Style', 'text', 'String', min(v.data(:)));
      meanLabel   = uicontrol(...
        'Parent', setPanels(k), 'Style', 'text', 'String', mean(v.data(:)));
      maxLabel    = uicontrol(...
        'Parent', setPanels(k), 'Style', 'text', 'String', max(v.data(:)));
      offsetField = uicontrol(...
        'Parent', setPanels(k), 'Style', 'edit', 'String', '0.0');
      
      set(offsetField, 'UserData', m);
      set(offsetField, 'Callback', @offsetFieldCallback);
      
      % alternate background colour for each row
      if mod(m, 2) ~= 0
        color = get(varLabel, 'BackgroundColor');
        color = color - 0.05;
        set(varLabel,    'BackgroundColor', color);
        set(minLabel,    'BackgroundColor', color);
        set(meanLabel,   'BackgroundColor', color);
        set(maxLabel,    'BackgroundColor', color);
        set(offsetField, 'BackgroundColor', color);
      end
      
      % position column values
      set(varLabel,    'Units', 'normalized');
      set(minLabel,    'Units', 'normalized');
      set(meanLabel,   'Units', 'normalized');
      set(maxLabel,    'Units', 'normalized');
      set(offsetField, 'Units', 'normalized');
      
      set(varLabel, ...
        'Position', [0.0, 1.0 - (rowHeight*(m+1)), 0.2, rowHeight]);
      set(minLabel, ...
        'Position', [0.2, 1.0 - (rowHeight*(m+1)), 0.2, rowHeight]);
      set(meanLabel, ...
        'Position', [0.4, 1.0 - (rowHeight*(m+1)), 0.2, rowHeight]);
      set(maxLabel, ...
        'Position', [0.6, 1.0 - (rowHeight*(m+1)), 0.2, rowHeight]);
      set(offsetField, ...
        'Position', [0.8, 1.0 - (rowHeight*(m+1)), 0.2, rowHeight]);
      
      set(varLabel,    'Units', 'pixels');
      set(minLabel,    'Units', 'pixels');
      set(meanLabel,   'Units', 'pixels');
      set(maxLabel,    'Units', 'pixels');
      set(offsetField, 'Units', 'pixels');
    end
  end
  
  set(f,             'WindowKeyPressFcn', @keyPressCallback);
  set(f,             'CloseRequestFcn',   @cancelButtonCallback);
  set(cancelButton,  'Callback',          @cancelButtonCallback);
  set(confirmButton, 'Callback',          @confirmButtonCallback);
  
  set(f, 'Visible', 'on');
  uiwait(f);
  
  % user cancelled dialog
  if isempty(offsets), return; end
  
  % otherwise, apply the offsets
  for k = 1:length(sample_data)
    
    vars = sample_data{k}.variables;
    for m = 1:length(vars)
      
      vars{m}.data = vars{m}.data + offsets{k}(m);
    end
    sample_data{k}.variables = vars;
  end
  
  
  function keyPressCallback(source,ev)
  %KEYPRESSCALLBACK If the user pushes escape/return while the dialog has 
  % focus, the dialog is cancelled/confirmed. This is done by delegating 
  % to the cancelButtonCallback/confirmButtonCallback functions.
  %
    if     strcmp(ev.Key, 'escape'), cancelButtonCallback( source,ev); 
    elseif strcmp(ev.Key, 'return'), confirmButtonCallback(source,ev); 
    end
  end

  function cancelButtonCallback(source,ev)
  %CANCELBUTTONCALLBACK Discards user input, and closes the dialog.
  % 
    offsets = {};
    delete(f);
  end

  function confirmButtonCallback(source,ev)
  %CONFIRMBUTTONCALLBACK Closes the dialog.
  % 
    delete(f);
  end

  function offsetFieldCallback(source, ev)
  %OFFSETFIELDCALLBACK Called when the user edits one of the offset fields.
  % Verifies that the text entered is a number.
  %
  
    val    = get(source, 'String');
    setIdx = get(get(source, 'Parent'), 'UserData');
    varIdx = get(source, 'UserData');
    
    val = str2double(val);
    
    % reset the offset value on non-numerical 
    % input, otherwise save the new value
    if isnan(val), set(source, 'String', num2str(offsets{setIdx}(varIdx)));
    else           offsets{setIdx}(varIdx) = val;
    end
  end
end
