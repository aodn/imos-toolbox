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
  narginchk(2,3);

  if ~iscell(sample_data), error('sample_data must be a cell array'); end
  if isempty(sample_data), return;                                    end
  
  % auto logical in input to enable running under batch processing
  if nargin<3, auto=false; end
  
  % no modification of data is performed on the raw FV00 dataset except
  % local time to UTC conversion
  if strcmpi(qcLevel, 'raw'), return; end
  
  % get the toolbox execution mode
  mode = readProperty('toolbox.mode');
  
  isTimeSeries = false;
  switch mode
      case 'timeSeries'
          isTimeSeries = true;
          
  end
  
  % generate descriptions for each data set
  nSampleData = length(sample_data);
  descs = cell(1, nSampleData);
  for k = 1:nSampleData
    descs{k} = genSampleDataDesc(sample_data{k});
  end
  
  % cell arrays of numeric arrays, representing the 
  % offsets/scales to  be applied to each variable 
  % in each data set; populated when the panels for 
  % each data set are populated
  defaultOffsets = cell(1, nSampleData);
  defaultScales  = cell(1, nSampleData);
  
  currentPProutine = mfilename;
  
  % populate default values for offsets and scales
  for k = 1:nSampleData
      nVars = length(sample_data{k}.variables);
      
      defaultOffsets{k} = cell(1, nVars);
      defaultScales{ k} = cell(1, nVars);
      
      defaultOffsets{k}(:) = {'0'};
      defaultScales{ k}(:) = {'1'};
      
      % read dataset specific PP parameters if exist and override previous entries from
      % parameter file depth.txt
      defaultOffsets{k} = readDatasetParameter(sample_data{k}.toolbox_input_file, currentPProutine, 'offset', defaultOffsets{k});
      defaultScales{k}  = readDatasetParameter(sample_data{k}.toolbox_input_file, currentPProutine, 'scale',  defaultScales{k});
  end
  appliedOffsetsStr = defaultOffsets;
  appliedScalesStr  = defaultScales;
  
  appliedOffsetsNum = defaultOffsets;
  appliedScalesNum  = defaultScales;
  
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
      set(f,             'Position', [0.25, 0.25, 0.5, 0.5]);
      set(cancelButton,  'Position', [0.0,  0.0,  0.5, 0.1]);
      set(confirmButton, 'Position', [0.5,  0.0,  0.5, 0.1]);
      set(tabPanel,      'Position', [0.0,  0.1,  1.0, 0.9]);
      
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
          
          diffHeaderLabelStr = '';
          if isTimeSeries
              % we might want to see the difference for this variable with
              % the nearest instrument on the mooring
              iTimeCurrent = getVar(sample_data{k}.dimensions, 'TIME');
              timeCurrent = sample_data{k}.dimensions{iTimeCurrent}.data;
              nominalDepthCurrent = inf;
              if isfield(sample_data{k}, 'instrument_nominal_depth')
                  if ~isempty(sample_data{k}.instrument_nominal_depth)
                      nominalDepthCurrent = sample_data{k}.instrument_nominal_depth;
                  end
              end
              
              if isinf(nominalDepthCurrent)
                  fprintf('%s\n', ['Info : ' sample_data{k}.toolbox_input_file ...
                      ' please document instrument_nominal_depth global attributes'...
                      ' so that a nearest instrument can be found in the mooring']);
              end
              
              % we will be looking at differences over a day from 1/4 of the
              % deployment
              timeForDiff = timeCurrent(1) + (timeCurrent(end)-timeCurrent(1))/4;
              if isfield(sample_data{k}, 'time_deployment_start')
                  if ~isempty(sample_data{k}.time_deployment_start)
                      % or preferably from the moment the mooring is in position
                      timeForDiff = sample_data{k}.time_deployment_start;
                  else
                      fprintf('%s\n', ['Info : ' sample_data{k}.toolbox_input_file ...
                      ' please document time_deployment_start global attributes'...
                      ' so that difference with a nearest instrument can be better calculated']);
                  end
              else
                  fprintf('%s\n', ['Info : ' sample_data{k}.toolbox_input_file ...
                      ' please document time_deployment_start global attributes'...
                      ' so that difference with a nearest instrument can be better calculated']);
              end
              
              iForDiff = timeCurrent >= timeForDiff & ...
                  timeCurrent <= timeForDiff + 1;
              timeCurrentForDiff = timeCurrent(iForDiff);
              
              diffHeaderLabelStr = ['Mean diff from ' datestr(timeCurrentForDiff(1), 'dd-mm-yyyy HH:MM:SS UTC') ' over 24h'];
          end
          
          % column headers
          varHeaderLabel    = uicontrol('Parent', setPanels(k), 'Style', 'text', ...
              'String', 'Variable', 'FontWeight', 'bold');
          minHeaderLabel    = uicontrol('Parent', setPanels(k), 'Style', 'text', ...
              'String', 'Minimum',  'FontWeight', 'bold');
          maxHeaderLabel    = uicontrol('Parent', setPanels(k), 'Style', 'text', ...
              'String', 'Maximum',  'FontWeight', 'bold');
          meanHeaderLabel   = uicontrol('Parent', setPanels(k), 'Style', 'text', ...
              'String', 'Mean',     'FontWeight', 'bold');
          diffHeaderLabel   = uicontrol('Parent', setPanels(k), 'Style', 'text', ...
              'String', diffHeaderLabelStr, 'FontWeight', 'bold');
          offsetHeaderLabel = uicontrol('Parent', setPanels(k), 'Style', 'text', ...
              'String', 'Offset',   'FontWeight', 'bold');
          scaleHeaderLabel  = uicontrol('Parent', setPanels(k), 'Style', 'text', ...
              'String', 'Scale',    'FontWeight', 'bold');
          
          % position headers
          set(varHeaderLabel,    'Units', 'normalized');
          set(minHeaderLabel,    'Units', 'normalized');
          set(maxHeaderLabel,    'Units', 'normalized');
          set(meanHeaderLabel,   'Units', 'normalized');
          set(diffHeaderLabel,   'Units', 'normalized');
          set(offsetHeaderLabel, 'Units', 'normalized');
          set(scaleHeaderLabel,  'Units', 'normalized');
          
          set(varHeaderLabel,    'Position', [0.0,  0.95 - rh, 0.14, rh]);
          set(minHeaderLabel,    'Position', [0.14, 0.95 - rh, 0.14, rh]);
          set(maxHeaderLabel,    'Position', [0.28, 0.95 - rh, 0.14, rh]);
          set(meanHeaderLabel,   'Position', [0.42, 0.95 - rh, 0.14, rh]);
          set(diffHeaderLabel,   'Position', [0.56, 0.95 - rh, 0.14, rh]);
          set(offsetHeaderLabel, 'Position', [0.70, 0.95 - rh, 0.14, rh]);
          set(scaleHeaderLabel,  'Position', [0.84, 0.95 - rh, 0.14, rh]);
          
          set(varHeaderLabel,    'Units', 'pixels');
          set(minHeaderLabel,    'Units', 'pixels');
          set(maxHeaderLabel,    'Units', 'pixels');
          set(meanHeaderLabel,   'Units', 'pixels');
          set(diffHeaderLabel,   'Units', 'pixels');
          set(offsetHeaderLabel, 'Units', 'pixels');
          set(scaleHeaderLabel,  'Units', 'pixels');
          
          % column values (one row for each variable)
          for m = 1:nVars
              notRelevantParams = {'TIMESERIES', 'PROFILE', 'TRAJECTORIES', 'TIME', 'LATITUDE', 'LONGITUDE', 'NOMINAL_DEPTH', 'BOT_DEPTH', 'DIRECTION'};
              if any(strcmpi(sample_data{k}.variables{m}.name, notRelevantParams)), continue; end
              
              offsetVal = defaultOffsets{k}{m};
              scaleVal  = defaultScales{k}{m};
          
              sizeData = size(sample_data{k}.variables{m}.data);
              
              dataDiffStr = '';
              if isTimeSeries && length(sizeData) == 2 && any(sizeData == 1)
                  % look for nearest instrument with the same 1D variable
                  distInstruments = inf(1, nSampleData);
                  for kk=1:nSampleData
                      if kk == k, continue; end
                      nominalDepthOther = inf;
                      if isfield(sample_data{kk}, 'instrument_nominal_depth')
                          nominalDepthOther = sample_data{kk}.instrument_nominal_depth;
                      else
                          continue;
                      end
                      distInstruments(kk) = abs(nominalDepthCurrent - nominalDepthOther);
                  end
                  distInstruments(isnan(distInstruments)) = inf;
                  
                  [~, iNearest] = min(distInstruments);
                  varName = sample_data{k}.variables{m}.name;
                  iVarNearest = getVar(sample_data{iNearest}.variables, varName);
                  signPresAtm = 0;
                  if strcmpi(varName, 'PRES') && iVarNearest == 0
                      iVarNearest = getVar(sample_data{iNearest}.variables, 'PRES_REL');
                      signPresAtm = -1;
                  elseif strcmpi(varName, 'PRES_REL') && iVarNearest == 0
                      iVarNearest = getVar(sample_data{iNearest}.variables, 'PRES');
                      signPresAtm = 1;
                  end
                  while iVarNearest == 0 && ~all(isinf(distInstruments))
                      distInstruments(iNearest) = inf;
                      [~, iNearest] = min(distInstruments);
                      iVarNearest = getVar(sample_data{iNearest}.variables, sample_data{k}.variables{m}.name);
                      signPresAtm = 0;
                      if strcmpi(varName, 'PRES') && iVarNearest == 0
                          iVarNearest = getVar(sample_data{iNearest}.variables, 'PRES_REL');
                          signPresAtm = -1;
                      elseif strcmpi(varName, 'PRES_REL') && iVarNearest == 0
                          iVarNearest = getVar(sample_data{iNearest}.variables, 'PRES');
                          signPresAtm = 1;
                      end
                  end
                  
                  if iVarNearest && ~isinf(distInstruments(iNearest))
                      dataNearest = sample_data{iNearest}.variables{iVarNearest}.data;
                      iTimeNearest = getVar(sample_data{iNearest}.dimensions, 'TIME');
                      timeNearest = sample_data{iNearest}.dimensions{iTimeNearest}.data;
                      
                      dataDiff = sample_data{k}.variables{m}.data(iForDiff) + signPresAtm*(14.7*0.689476) - interp1(timeNearest, dataNearest, timeCurrentForDiff);
                      
                      iNanDataDiff = isnan(dataDiff);
                      dataDiffStr = [num2str(mean(dataDiff(~iNanDataDiff))) ' @ ' num2str(distInstruments(iNearest)) 'm away (nominal)'];
                  end
              end
              
              iNanDataCurrent = isnan(sample_data{k}.variables{m}.data);
              
              varLabel    = uicontrol(...
                  'Parent', setPanels(k), 'Style', 'text', 'String', [sample_data{k}.variables{m}.name ' or sam.variables{' num2str(m) '}.data']);
              minLabel    = uicontrol(...
                  'Parent', setPanels(k), 'Style', 'text', 'String', num2str(min(sample_data{k}.variables{m}.data(~iNanDataCurrent))));
              maxLabel    = uicontrol(...
                  'Parent', setPanels(k), 'Style', 'text', 'String', num2str(max(sample_data{k}.variables{m}.data(~iNanDataCurrent))));
              meanLabel   = uicontrol(...
                  'Parent', setPanels(k), 'Style', 'text', 'String', num2str(mean(sample_data{k}.variables{m}.data(~iNanDataCurrent))));
              diffLabel = uicontrol(...
                  'Parent', setPanels(k), 'Style', 'text', 'String', dataDiffStr);
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
                  set(maxLabel,    'BackgroundColor', color);
                  set(meanLabel,   'BackgroundColor', color);
                  set(diffLabel,   'BackgroundColor', color);
                  set(offsetField, 'BackgroundColor', color);
                  set(scaleField,  'BackgroundColor', color);
              end
              
              % position column values
              set(varLabel,    'Units', 'normalized');
              set(minLabel,    'Units', 'normalized');
              set(maxLabel,    'Units', 'normalized');
              set(meanLabel,   'Units', 'normalized');
              set(diffLabel,   'Units', 'normalized');
              set(offsetField, 'Units', 'normalized');
              set(scaleField,  'Units', 'normalized');
              
              set(varLabel,    'Position', [0.0,  0.95 - (rh*(m+1)), 0.14, rh]);
              set(minLabel,    'Position', [0.14, 0.95 - (rh*(m+1)), 0.14, rh]);
              set(maxLabel,    'Position', [0.28, 0.95 - (rh*(m+1)), 0.14, rh]);
              set(meanLabel,   'Position', [0.42, 0.95 - (rh*(m+1)), 0.14, rh]);
              set(diffLabel,   'Position', [0.56, 0.95 - (rh*(m+1)), 0.14, rh]);
              set(offsetField, 'Position', [0.70, 0.95 - (rh*(m+1)), 0.14, rh]);
              set(scaleField,  'Position', [0.84, 0.95 - (rh*(m+1)), 0.14, rh]);
              
              set(varLabel,    'Units', 'pixels');
              set(minLabel,    'Units', 'pixels');
              set(maxLabel,    'Units', 'pixels');
              set(meanLabel,   'Units', 'pixels');
              set(diffLabel,   'Units', 'pixels');
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
  end
  
  % user cancelled dialog
  if isempty(appliedOffsetsStr) || isempty(appliedScalesStr), return; end
  
  % otherwise, apply the offsets/scales
  for k = 1:nSampleData
    sam = sample_data{k};
    vars = sam.variables;
    
    for m = 1:length(vars)
        appliedOffsetsNum{k}{m} = str2double(appliedOffsetsStr{k}{m});
        if isnan(appliedOffsetsNum{k}{m})
            % we have a string value which is a valid Matlab formula
            appliedOffsetsNum{k}{m} = eval(appliedOffsetsStr{k}{m});
        end
        
        appliedScalesNum{k}{m} = str2double(appliedScalesStr{k}{m});
        if isnan(appliedOffsetsNum{k}{m})
            % we have a string value which is a valid Matlab formula
            appliedScalesNum{k}{m} = eval(appliedScalesStr{k}{m});
        end
        
        if any(any(appliedOffsetsNum{k}{m} ~= 0)) || any(any(appliedScalesNum{k}{m} ~= 1))
            % apply offsets and scales
            vars{m}.data = appliedOffsetsNum{k}{m} + (appliedScalesNum{k}{m} .* vars{m}.data);
            
            variableOffsetComment = ['variableOffsetPP: ' vars{m}.name ' values modified '...
                'following new_data = offset + (scale * data) with offset = ' ...
                appliedOffsetsStr{k}{m} ' and scale = ' appliedScalesStr{k}{m} '.'];
            
            % replace Matlab sam structure with actual variable names in comment
            variableOffsetComment = strrep(variableOffsetComment, 'sam.', '');
            for n = 1:length(vars)
                variableOffsetComment = strrep(variableOffsetComment, ['variables{' num2str(n) '}.data'], sam.variables{n}.name);
                variableOffsetComment = strrep(variableOffsetComment, ['variables{' num2str(n) '}'], sam.variables{n}.name);
            end
            
            comment = vars{m}.comment;
            if isempty(comment)
                vars{m}.comment = variableOffsetComment;
            else
                vars{m}.comment = [comment ' ' variableOffsetComment];
            end
            
            history = sample_data{k}.history;
            if isempty(history)
                sample_data{k}.history = sprintf('%s - %s', datestr(now_utc, readProperty('exportNetCDF.dateFormat')), variableOffsetComment);
            else
                sample_data{k}.history = sprintf('%s\n%s - %s', history, datestr(now_utc, readProperty('exportNetCDF.dateFormat')), variableOffsetComment);
            end
        end
        if ~strcmpi(appliedOffsetsStr{k}{m}, defaultOffsets{k}{m}) || ~strcmpi(appliedScalesStr{k}{m}, defaultScales{k}{m})
            % write/update dataset PP parameters
            writeDatasetParameter(sample_data{k}.toolbox_input_file, currentPProutine, 'offset', appliedOffsetsStr{k});
            writeDatasetParameter(sample_data{k}.toolbox_input_file, currentPProutine, 'scale',  appliedScalesStr{k});
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
    appliedOffsetsStr = {};
    appliedScalesStr  = {};
    delete(f);
  end

  function confirmButtonCallback(source,ev)
  %CONFIRMBUTTONCALLBACK Closes the dialog.
  % 
    delete(f);
  end

  function offsetFieldCallback(source, ev)
  %OFFSETFIELDCALLBACK Called when the user edits one of the offset fields.
  % Verifies that the text entered is a number or a valid Matlab statement.
  %
  
    valStr = get(source, 'String');
    setIdx = get(get(source, 'Parent'), 'UserData');
    varIdx = get(source, 'UserData');
    
    valNum = str2double(valStr);
    
    if isnan(valNum)
        % we have a string value
        isValid = true;
        try
            sam = sample_data{setIdx};
            valNum = eval(valStr);
        catch e
            isValid = false;
        end
        
        if isValid
            % we have a valid Matlab formula
            appliedOffsetsStr{setIdx}{varIdx} = valStr;
            appliedOffsetsNum{setIdx}{varIdx} = valNum;
        else
            % we reset to default value
            set(source, 'String', defaultOffsets{setIdx}{varIdx});
        end
    else
        % we have a numerical value
        appliedOffsetsStr{setIdx}{varIdx} = valStr;
        appliedOffsetsNum{setIdx}{varIdx} = valNum;
    end
  end

  function scaleFieldCallback(source, ev)
  %SCALEFIELDCALLBACK Called when the user edits one of the scale fields.
  % Verifies that the text entered is a number or a valid Matlab statement.
  %
  
    valStr = get(source, 'String');
    setIdx = get(get(source, 'Parent'), 'UserData');
    varIdx = get(source, 'UserData');
    
    valNum = str2double(valStr);
    
    if isnan(valNum)
        % we have a string value
        isValid = true;
        try
            sam = sample_data{setIdx};
            valNum = eval(valStr);
        catch e
            isValid = false;
        end
        
        if isValid
            % we have a valid Matlab formula
            appliedScalesStr{setIdx}{varIdx} = valStr;
            appliedScalesNum{setIdx}{varIdx} = valNum;
        else
            % we reset to default value
            set(source, 'String', defaultScales{setIdx}{varIdx});
        end
    else
        % we have a numerical value
        appliedScalesStr{setIdx}{varIdx} = valStr;
        appliedScalesNum{setIdx}{varIdx} = valNum;
    end
  end
end
