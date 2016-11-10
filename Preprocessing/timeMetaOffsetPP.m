function sample_data = timeMetaOffsetPP(sample_data, qcLevel, auto)
%TIMEMEATOFFSETPP Prompts the user to apply time correction to the given metadata 
% date in deployment database.
%
% All IMOS datasets should be provided in UTC time. Metadata may not
% necessarily have been documented in UTC time, so a correction must be made
% before the metadata can be considered to be in an IMOS compatible format.
% This function prompts the user to provide a time offset value (in hours)
% to apply to each metadata related to the data sets.
%
% Default time offset values for timezone codes are stored in a plain text
% file, timeOffsetPP.txt.
%
% Inputs:
%   sample_data - cell array of structs, the data sets to which time
%                 correction should be applied.
%   qcLevel     - string, 'raw' or 'qc'. Some pp not applied when 'raw'.
%   auto        - logical, run pre-processing in batch mode.
%
% Outputs:
%   sample_data - same as input, with time correction applied.
%

%
% Author:   Guillaume Galibert <guillaume.galibert@utas.edu.au>
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
  
  % time offsets are already performed on raw FV00 dataset which then go through
  % this pp to generate the qc'd FV01 dataset.
  if strcmpi(qcLevel, 'qc'), return; end
      
  offsetFile = ['Preprocessing' filesep 'timeOffsetPP.txt'];

  descs     = {};
  timezones = {};
  offsets   = [];
  sets      = ones(length(sample_data), 1);
  
  % create descriptions, and get timezones/offsets for each data set
  for k = 1:length(sample_data)
    
    descs{k} = genSampleDataDesc(sample_data{k});
    
    timezones{k} = sample_data{k}.meta.timezone;
    
    if isnan(str2double(timezones{k}))
      try 
        offsets(k) = str2double(readProperty(timezones{k}, offsetFile));
      catch
        offsets(k) = nan;
      end
    else
      offsets(k) = str2double(timezones{k});
    end
    
    if isnan(offsets(k)), offsets(k) = 0; end
  end
  
  if ~auto
      f = figure(...
          'Name',        'Time Metadata Offset',...
          'Visible',     'off',...
          'MenuBar'  ,   'none',...
          'Resize',      'off',...
          'WindowStyle', 'Modal',...
          'NumberTitle', 'off');
      
      cancelButton  = uicontrol('Style',  'pushbutton', 'String', 'Cancel');
      confirmButton = uicontrol('Style',  'pushbutton', 'String', 'Ok');
      
      setCheckboxes  = [];
      timezoneLabels = [];
      offsetFields   = [];
      
      for k = 1:length(sample_data)
          
          setCheckboxes(k) = uicontrol(...
              'Style',    'checkbox',...
              'String',   descs{k},...
              'Value',    1, ...
              'UserData', k);
          
          timezoneLabels(k) = uicontrol(...
              'Style', 'text',...
              'String', timezones{k});
          
          offsetFields(k) = uicontrol(...
              'Style',    'edit',...
              'UserData', k, ...
              'String',   num2str(offsets(k)));
      end
      
      % set all widgets to normalized for positioning
      set(f,              'Units', 'normalized');
      set(cancelButton,   'Units', 'normalized');
      set(confirmButton,  'Units', 'normalized');
      set(setCheckboxes,  'Units', 'normalized');
      set(timezoneLabels, 'Units', 'normalized');
      set(offsetFields,   'Units', 'normalized');
      
      set(f,             'Position', [0.2 0.35 0.6 0.3]);
      set(cancelButton,  'Position', [0.0 0.0  0.5 0.1]);
      set(confirmButton, 'Position', [0.5 0.0  0.5 0.1]);
      
      rowHeight = 0.9 / length(sample_data);
      for k = 1:length(sample_data)
          
          rowStart = 1.0 - k * rowHeight;
          
          set(setCheckboxes (k), 'Position', [0.0 rowStart 0.6 rowHeight]);
          set(timezoneLabels(k), 'Position', [0.6 rowStart 0.2 rowHeight]);
          set(offsetFields  (k), 'Position', [0.8 rowStart 0.2 rowHeight]);
      end
      
      % set back to pixels
      set(f,              'Units', 'normalized');
      set(cancelButton,   'Units', 'normalized');
      set(confirmButton,  'Units', 'normalized');
      set(setCheckboxes,  'Units', 'normalized');
      set(timezoneLabels, 'Units', 'normalized');
      set(offsetFields,   'Units', 'normalized');
      
      % set widget callbacks
      set(f,             'CloseRequestFcn',   @cancelCallback);
      set(f,             'WindowKeyPressFcn', @keyPressCallback);
      set(setCheckboxes, 'Callback',          @checkboxCallback);
      set(offsetFields,  'Callback',          @offsetFieldCallback);
      set(cancelButton,  'Callback',          @cancelCallback);
      set(confirmButton, 'Callback',          @confirmCallback);
      
      set(f, 'Visible', 'on');
      
      uiwait(f);
  end
  
  % apply the time offset to the selected datasets
  for k = 1:length(sample_data)
      
      % this set has been deselected
      if ~sets(k), continue; end
      
      % no offset to be applied on this dataset
      if offsets(k) == 0, continue; end
      
      % otherwise apply the offset
      sample_data{k}.time_deployment_start = ...
          sample_data{k}.time_deployment_start      + (offsets(k) / 24);
      sample_data{k}.time_deployment_end   = ...
          sample_data{k}.time_deployment_end        + (offsets(k) / 24);
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
    sets(:)    = 0;
    offsets(:) = 0;
    delete(f);
  end

  function confirmCallback(source,ev)
  %CONFIRMCALLBACK. Confirm button callback. Closes the dialog.
  %
    delete(f);
  end
  
  function checkboxCallback(source, ev)
  %CHECKBOXCALLBACK Called when a checkbox selection is changed.
  % Enables/disables the offset text field.
  %
    idx = get(source, 'UserData');
    val = get(source, 'Value');
    
    sets(idx) = val;
    
    if val, val = 'on';
    else    val = 'off';
    end
    
    set(offsetFields(idx), 'Enable', val);
    
  end

  function offsetFieldCallback(source, ev)
  %OFFSETFIELDCALLBACK Called when the user edits one of the offset fields.
  % Verifies that the text entered is a number.
  %
  
    val = get(source, 'String');
    idx = get(source, 'UserData');
    
    val = str2double(val);
    
    % reset the offset value on non-numerical 
    % input, otherwise save the new value
    if isnan(val), set(source, 'String', num2str(offsets(idx)));
    else           offsets(idx) = val;
    
    end
  end
end
