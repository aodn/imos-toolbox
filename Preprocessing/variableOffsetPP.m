function sample_data = variableOffsetPP( sample_data, qcLevel, auto )
%VARIABLEOFFSETPP Allows the user to apply a linear offset and scale to the 
% variables in the given data sets.
%
% Displays a dialog which allows the user to apply linear offsets and scales 
% to each variable in the given data sets. The variable data is modified as
% follows:
%
%   data = offset + (scale * data)
%
% Inputs:
%   sample_data - cell array of structs, the data sets for which variable
%                 offset/scaling is to be applied.
%   qcLevel     - string, 'raw' or 'qc'. Some pp not applied when 'raw'.
%   auto        - logical, run pre-processing in batch mode.
%
% Outputs:
%   sample_data - same as input, potentially with variable data modified.
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
  narginchk(2,3);

  if ~iscell(sample_data), error('sample_data must be a cell array'); end
  if isempty(sample_data), return;                                    end
  
  % auto logical in input to enable running under batch processing
  if nargin<3, auto=false; end
  
  % no modification of data is performed on the raw FV00 dataset except
  % local time to UTC conversion
  if strcmpi(qcLevel, 'raw'), return; end
  
  % generate descriptions for each data set
  nSampleData = length(sample_data);
  descs = cell(1, nSampleData);
  for k = 1:nSampleData
    descs{k} = genSampleDataDesc(sample_data{k});
  end
  
  offsetFile = ['Preprocessing' filesep 'variableOffsetPP.txt'];
  
  % cell arrays of numeric arrays, representing the 
  % offsets/scales to  be applied to each variable 
  % in each data set; populated when the panels for 
  % each data set are populated
  offsets = cell(1, nSampleData);
  scales  = cell(1, nSampleData);
  
  if ~auto
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
      set(f,             'Position', [0.25, 0.25,  0.5, 0.5]);
      set(cancelButton,  'Position', [0.0,  0.0,  0.5,  0.1]);
      set(confirmButton, 'Position', [0.5,  0.0,  0.5,  0.1]);
      set(tabPanel,      'Position', [0.0,  0.1,  1.0,  0.9]);
      
      % reset back to pixels
      set(f,             'Units', 'pixels');
      set(cancelButton,  'Units', 'pixels');
      set(confirmButton, 'Units', 'pixels');
      set(tabPanel,      'Units', 'pixels');
      
      % create a panel for each data set
      setPanels = nan(1, nSampleData);
      for k = 1:nSampleData
          setPanels(k) = uipanel('BorderType', 'none','UserData', k);
      end
      
      % put the panels into a tabbed pane
      tabbedPane(tabPanel, setPanels, descs, false);
      
      % populate the data set panels
      for k = 1:nSampleData
          
          nVars = length(sample_data{k}.variables);
          rh    = 0.95 / (nVars + 1);
          offsets{k} = zeros(nVars,1);
          scales{ k} = ones( nVars,1);
          
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
          scaleHeaderLabel  = uicontrol('Parent', setPanels(k), 'Style', 'text', ...
              'String', 'Scale',    'FontWeight', 'bold');
          
          % position headers
          set(varHeaderLabel,    'Units', 'normalized');
          set(minHeaderLabel,    'Units', 'normalized');
          set(meanHeaderLabel,   'Units', 'normalized');
          set(maxHeaderLabel,    'Units', 'normalized');
          set(offsetHeaderLabel, 'Units', 'normalized');
          set(scaleHeaderLabel,  'Units', 'normalized');
          
          set(varHeaderLabel,    'Position', [0.0,  0.95 - rh, 0.16, rh]);
          set(minHeaderLabel,    'Position', [0.16, 0.95 - rh, 0.16, rh]);
          set(meanHeaderLabel,   'Position', [0.32, 0.95 - rh, 0.16, rh]);
          set(maxHeaderLabel,    'Position', [0.48, 0.95 - rh, 0.16, rh]);
          set(offsetHeaderLabel, 'Position', [0.64, 0.95 - rh, 0.16, rh]);
          set(scaleHeaderLabel,  'Position', [0.80, 0.95 - rh, 0.16, rh]);
          
          set(varHeaderLabel,    'Units', 'pixels');
          set(minHeaderLabel,    'Units', 'pixels');
          set(meanHeaderLabel,   'Units', 'pixels');
          set(maxHeaderLabel,    'Units', 'pixels');
          set(offsetHeaderLabel, 'Units', 'pixels');
          set(scaleHeaderLabel,  'Units', 'pixels');
          
          % column values (one row for each variable)
          for m = 1:nVars
              
              v = sample_data{k}.variables{m};
              
              notRelevantParams = {'DIRECTION'};
              if any(strcmpi(v.name, notRelevantParams)), continue; end
              
              try
                  str              = readProperty(v.name, offsetFile);
                  [offsetVal, str] = strtok(str, ',');
                  [scaleVal,  str] = strtok(str, ',');
              catch
                  offsetVal = '0.0';
                  scaleVal  = '1.0';
              end
              
              offsets{k}(m) = str2double(offsetVal);
              scales{ k}(m) = str2double(scaleVal);
          
              varLabel    = uicontrol(...
                  'Parent', setPanels(k), 'Style', 'text', 'String', v.name);
              minLabel    = uicontrol(...
                  'Parent', setPanels(k), 'Style', 'text', 'String', min(v.data(:)));
              meanLabel   = uicontrol(...
                  'Parent', setPanels(k), 'Style', 'text', 'String', mean(v.data(:)));
              maxLabel    = uicontrol(...
                  'Parent', setPanels(k), 'Style', 'text', 'String', max(v.data(:)));
              offsetField = uicontrol(...
                  'Parent', setPanels(k), 'Style', 'edit', 'String', offsetVal);
              scaleField  = uicontrol(...
                  'Parent', setPanels(k), 'Style', 'edit', 'String', scaleVal);
              
              set(offsetField, 'UserData', m);
              set(offsetField, 'Callback', @offsetFieldCallback);
              set(scaleField,  'UserData', m);
              set(scaleField,  'Callback', @scaleFieldCallback);
              
              % alternate background colour for each row
              if mod(m, 2) ~= 0
                  color = get(varLabel, 'BackgroundColor');
                  color = color - 0.05;
                  set(varLabel,    'BackgroundColor', color);
                  set(minLabel,    'BackgroundColor', color);
                  set(meanLabel,   'BackgroundColor', color);
                  set(maxLabel,    'BackgroundColor', color);
                  set(offsetField, 'BackgroundColor', color);
                  set(scaleField,  'BackgroundColor', color);
              end
              
              % position column values
              set(varLabel,    'Units', 'normalized');
              set(minLabel,    'Units', 'normalized');
              set(meanLabel,   'Units', 'normalized');
              set(maxLabel,    'Units', 'normalized');
              set(offsetField, 'Units', 'normalized');
              set(scaleField,  'Units', 'normalized');
              
              set(varLabel,    'Position', [0.0, 0.95 - (rh*(m+1)),  0.16, rh]);
              set(minLabel,    'Position', [0.16, 0.95 - (rh*(m+1)), 0.16, rh]);
              set(meanLabel,   'Position', [0.32, 0.95 - (rh*(m+1)), 0.16, rh]);
              set(maxLabel,    'Position', [0.48, 0.95 - (rh*(m+1)), 0.16, rh]);
              set(offsetField, 'Position', [0.64, 0.95 - (rh*(m+1)), 0.16, rh]);
              set(scaleField,  'Position', [0.80, 0.95 - (rh*(m+1)), 0.16, rh]);
              
              set(varLabel,    'Units', 'pixels');
              set(minLabel,    'Units', 'pixels');
              set(meanLabel,   'Units', 'pixels');
              set(maxLabel,    'Units', 'pixels');
              set(offsetField, 'Units', 'pixels');
              set(scaleField,  'Units', 'pixels');
          end
      end
      
      set(f,             'WindowKeyPressFcn', @keyPressCallback);
      set(f,             'CloseRequestFcn',   @cancelButtonCallback);
      set(cancelButton,  'Callback',          @cancelButtonCallback);
      set(confirmButton, 'Callback',          @confirmButtonCallback);
      
      set(f, 'Visible', 'on');
      uiwait(f);
  else
      for k = 1:nSampleData
          
          nVars = length(sample_data{k}.variables);
          offsets{k} = zeros(nVars,1);
          scales{ k} = ones( nVars,1);
          
          for m = 1:nVars
              
              v = sample_data{k}.variables{m};
              try
                  str              = readProperty(v.name, offsetFile);
                  [offsetVal, str] = strtok(str, ',');
                  [scaleVal,  str] = strtok(str, ',');
              catch
                  offsetVal = '0.0';
                  scaleVal  = '1.0';
              end
              
              offsets{k}(m) = str2double(offsetVal);
              scales{ k}(m) = str2double(scaleVal);
          end
      end
  end
  
  % user cancelled dialog
  if isempty(offsets) ||  isempty(scales), return; end
  
  % otherwise, apply the offsets/scales
  for k = 1:nSampleData
    
    history = sample_data{k}.history;
      
    vars = sample_data{k}.variables;
    for m = 1:length(vars)
      
      d = vars{m}.data;
      o = offsets{k}(m);
      s = scales{k}(m);
      
      if ~isnan(offsets{k}(m)) && ~isnan(scales{k}(m)) && ...
              (offsets{k}(m) ~= 0 || scales{k}(m) ~= 1)
          vars{m}.data = o + (s .* d);
          
          variableOffsetComment = ['variableOffsetPP: variable values modified applying '...
                  'the following offset : ' num2str(offsets{k}(m)) ' and scale : ' num2str(scales{k}(m)) '.'];
          
          comment = vars{m}.comment;
          if isempty(comment)
              vars{m}.comment = variableOffsetComment;
          else
              vars{m}.comment = [comment ' ' variableOffsetComment];
          end
          
          str = sprintf('%0.6f,%0.6f', offsets{k}(m), scales{k}(m));
          writeProperty(vars{m}.name, str, offsetFile);
          
          if isempty(history)
              history = sprintf('%s - %s', datestr(now_utc, readProperty('exportNetCDF.dateFormat')), variableOffsetComment);
          else
              history = sprintf('%s\n%s - %s', history, datestr(now_utc, readProperty('exportNetCDF.dateFormat')), variableOffsetComment);
          end
      end
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
    scales  = {};
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

  function scaleFieldCallback(source, ev)
  %SCALEFIELDCALLBACK Called when the user edits one of the scale fields.
  % Verifies that the text entered is a number.
  %
  
    val    = get(source, 'String');
    setIdx = get(get(source, 'Parent'), 'UserData');
    varIdx = get(source, 'UserData');
    
    val = str2double(val);
    
    % reset the scale value on non-numerical 
    % input, otherwise save the new value
    if isnan(val), set(source, 'String', num2str(scales{setIdx}(varIdx)));
    else           scales{setIdx}(varIdx) = val;
    end
  end
end
