function sample_data = timeStartPP( sample_data, qcLevel, auto )
%TIMESTARTPP Allows modification of a data set's starting time.
%
% Prompts the user to enter a new starting time for the data set. Useful for 
% data sets which were retrieved from an instrument with an unreliable or
% unset clock.
%
% Inputs:
%   sample_data - cell array of structs, the data sets for which the starting 
%                 time should be modified.
%   qcLevel     - string, 'raw' or 'qc'. Some pp not applied when 'raw'.
%   auto        - logical, check if pre-processing in batch mode.
%
% Outputs:
%   sample_data - same as input, with starting time modified.
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
  error(nargchk(2,3,nargin));

  if ~iscell(sample_data), error('sample_data must be a cell array'); end
  if isempty(sample_data), return;                                    end

  % auto logical in input to check if running under batch processing
  if nargin<3, auto=false; end
  if auto, error('timeStart pre-processing cannot be ran in batch mode'); end
  
  % no modification of data is performed on the raw FV00 dataset except
  % local time to UTC conversion
  if strcmpi(qcLevel, 'raw'), return; end
  
  timeFmt = readProperty('toolbox.timeFormat');

  descs        = {};
  startTimes   = [];
  startTimeFmt = {};
  sets         = ones(length(sample_data), 1);
  
  % create descriptions, and get default starting times for each data set
  for k = 1:length(sample_data)
    
    descs{k}        = genSampleDataDesc(sample_data{k});
    startTimes(k)   = sample_data{k}.time_coverage_start;
    startTimeFmt{k} = datestr(startTimes(k), timeFmt);
  end
  
  f = figure(...
    'Name',        'Time Start',...
    'Visible',     'off',...
    'MenuBar'  ,   'none',...
    'Resize',      'off',...
    'WindowStyle', 'Modal',...
    'NumberTitle', 'off');
    
  cancelButton  = uicontrol('Style',  'pushbutton', 'String', 'Cancel');
  confirmButton = uicontrol('Style',  'pushbutton', 'String', 'Ok');
  
  setCheckboxes   = [];
  startTimeFields = [];
  
  for k = 1:length(sample_data)
    
    setCheckboxes(k) = uicontrol(...
      'Style',    'checkbox',...
      'String',   descs{k},...
      'Value',    1, ...
      'UserData', k);
    
    startTimeFields(k) = uicontrol(...
      'Style', 'edit',...
      'String', startTimeFmt{k},...
      'UserData', k);
  end
  
  % set all widgets to normalized for positioning
  set(f,               'Units', 'normalized');
  set(cancelButton,    'Units', 'normalized');
  set(confirmButton,   'Units', 'normalized');
  set(setCheckboxes,   'Units', 'normalized');
  set(startTimeFields, 'Units', 'normalized');
  
  set(f,             'Position', [0.2 0.35 0.6 0.3]);
  set(cancelButton,  'Position', [0.6 0.015  0.15 0.07]);
  set(confirmButton, 'Position', [0.8 0.015  0.15 0.07]);
  
  rowHeight = 0.9 / length(sample_data);
  for k = 1:length(sample_data)
    
    rowStart = 1.0 - k * rowHeight;
    
    set(setCheckboxes (k),  'Position', [0.0 rowStart 0.6 rowHeight]);
    set(startTimeFields(k), 'Position', [0.6 rowStart 0.4 rowHeight]);
  end
  
  % set back to pixels
  set(f,               'Units', 'normalized');
  set(cancelButton,    'Units', 'normalized');
  set(confirmButton,   'Units', 'normalized');
  set(setCheckboxes,   'Units', 'normalized');
  set(startTimeFields, 'Units', 'normalized');
  
  % set widget callbacks
  set(f,               'CloseRequestFcn',   @cancelCallback);
  set(f,               'WindowKeyPressFcn', @keyPressCallback);
  set(setCheckboxes,   'Callback',          @checkboxCallback);
  set(startTimeFields, 'Callback',          @startTimeFieldCallback);
  set(cancelButton,    'Callback',          @cancelCallback);
  set(confirmButton,   'Callback',          @confirmCallback);
  
  set(f, 'Visible', 'on');
  
  uiwait(f);
  
  % apply the new start time to the selected datasets
  for k = 1:length(sample_data)
    
    % this set has been deselected
    if ~sets(k), continue; end
    
    % look time through dimensions
    type = 'dimensions';
    timeIdx = getVar(sample_data{k}.(type), 'TIME');
    
    if timeIdx == 0
        % look time through variables
        type = 'variables';
        timeIdx = getVar(sample_data{k}.(type), 'TIME');
    end
    
    % no time dimension nor variable in this dataset
    if timeIdx == 0, continue; end
    
    oldStart = sample_data{k}.(type){timeIdx}.data(1);
    newStart = startTimes(k);
    
    if oldStart == newStart, continue; end
    
    timeStartComment = ['timeStartPP: TIME values and time_coverage_start/end global attributes have been '...
          'changed applying a new start time ' datestr(newStart, 'dd-mm-yyyy HH:MM:SS') ', the former being ' ...
          datestr(oldStart, 'dd-mm-yyyy HH:MM:SS') '.'];
      
    % apply the new start time to the data
    sample_data{k}.(type){timeIdx}.data = ...
      sample_data{k}.(type){timeIdx}.data - oldStart;
    sample_data{k}.(type){timeIdx}.data = ...
      sample_data{k}.(type){timeIdx}.data + newStart;
    
    % and to the time coverage atttributes
    sample_data{k}.time_coverage_start = newStart;
    sample_data{k}.time_coverage_end = ...
      sample_data{k}.(type){timeIdx}.data(end);
  
    comment = sample_data{k}.(type){timeIdx}.comment;
    if isempty(comment)
        sample_data{k}.(type){timeIdx}.comment = timeStartComment;
    else
        sample_data{k}.(type){timeIdx}.comment = [comment ' ' timeStartComment];
    end
    
    history = sample_data{k}.history;
    if isempty(history)
        sample_data{k}.history = sprintf('%s - %s', datestr(now_utc, readProperty('exportNetCDF.dateFormat')), timeStartComment);
    else
        sample_data{k}.history = sprintf('%s\n%s - %s', history, datestr(now_utc, readProperty('exportNetCDF.dateFormat')), timeStartComment);
    end
  end
  
  function keyPressCallback(source,ev)
  %KEYPRESSCALLBACK If the user pushes escape/return while the dialog has 
  % focus, the dialog is cancelled/confirmed. This is done by delegating 
  % to the cancelCallback/confirmCallback functions.
  %
    if     strcmp(ev.Key, 'escape'), cancelCallback( source,ev); 
    elseif strcmp(ev.Key, 'return'), confirmCallback(source,ev); 
    end
  end

  function cancelCallback(source,ev)
  %CANCELCALLBACK Cancel button callback. Discards user input and closes the 
  % dialog .
  %
    sets(:) = 0;
    delete(f);
  end

  function confirmCallback(source,ev)
  %CONFIRMCALLBACK. Confirm button callback. Closes the dialog.
  %
    delete(f);
  end
  
  function checkboxCallback(source, ev)
  %CHECKBOXCALLBACK Called when a checkbox selection is changed.
  % Enables/disables the start time text field.
  %
    idx = get(source, 'UserData');
    val = get(source, 'Value');
    
    sets(idx) = val;
    
    if val, val = 'on';
    else    val = 'off';
    end
    
    set(startTimeFields(idx), 'Enable', val);
    
  end

  function startTimeFieldCallback(source, ev)
  %STARTTIMEFIELDCALLBACK Called when the user edits one of the start time 
  % fields. Verifies that the text entered is in the correct format.
  %
  
    val = get(source, 'String');
    idx = get(source, 'UserData');

    % reset the start time value on invalid
    % input, otherwise save the new time
    try
      nval = datenum(val, timeFmt);
      
      % regenerate the formatted string from the parsed value,
      % to discard any invalid input the user might have provided
      % (e.g. a month value of > 12)
      startTimeFmt{idx} = datestr(nval, timeFmt);
      startTimes  (idx) = nval;
      
    catch e
      set(source, 'String', startTimeFmt{idx});
    end
  end
end
