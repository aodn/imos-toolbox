function sample_data = timeOffsetPP(sample_data, qcLevel, auto)
%TIMEOFFSETPP Prompts the user to apply time correction to the given data 
% sets.
%
% All IMOS datasets should be provided in UTC time. Raw data may not
% necessarily have been captured in UTC time, so a correction must be made
% before the data can be considered to be in an IMOS compatible format.
% This function prompts the user to provide a time offset value (in hours)
% to apply to each of the data sets.
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
% Author:       Paul McCarthy <paul.mccarthy@csiro.au>
% Contributor:  Brad Morris <b.morris@unsw.edu.au>
%               Guillaume Galibert <guillaume.galibert@utas.edu.au>
%

%
% Copyright (C) 2017, Australian Ocean Data Network (AODN) and Integrated 
% Marine Observing System (IMOS).
%
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation version 3 of the License.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
% GNU General Public License for more details.

% You should have received a copy of the GNU General Public License
% along with this program.
% If not, see <https://www.gnu.org/licenses/gpl-3.0.en.html>.
%

  narginchk(2,3);
  
  if ~iscell(sample_data), error('sample_data must be a cell array'); end
  if isempty(sample_data), return;                                    end
  
  % auto logical in input to enable running under batch processing
  if nargin<3, auto=false; end
  
  offsetFile = ['Preprocessing' filesep 'timeOffsetPP.txt'];

  nSample = length(sample_data);
  descs     = {};
  timezones = {};
  offsets   = [];
  sets      = ones(nSample, 1);
  
  % create descriptions, and get timezones/offsets for each data set
  for k = 1:nSample
    
    descs{k} = genSampleDataDesc(sample_data{k});
    
    timezones{k} = sample_data{k}.meta.timezone;
    
    if isnan(str2double(timezones{k}))
        try
            offsets(k) = str2double(readProperty(timezones{k}, offsetFile));
        catch
            if strncmpi(timezones{k}, 'UTC', 3)
                offsetStr = timezones{k}(4:end);
                offsets(k) = str2double(offsetStr)*(-1);
            else
                offsets(k) = NaN;
            end
        end
    else
        offsets(k) = str2double(timezones{k});
    end
    
    if isnan(offsets(k)), offsets(k) = 0; end
  end
  
  if ~auto
      f = figure(...
          'Name',        'Time Data Offset',...
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
      
      for k = 1:nSample
          
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
      
      set(f,             'Position', [0.2 0.35 0.6 0.0222 * (nSample +1 )]); % need to include 1 extra space for the row of buttons
      
      rowHeight = 1 / (nSample + 1);
      
      set(cancelButton,  'Position', [0.0 0.0  0.5 rowHeight]);
      set(confirmButton, 'Position', [0.5 0.0  0.5 rowHeight]);
      
      
      for k = 1:nSample
          
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
  for k = 1:nSample
      
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
      
      % no offset to be applied on this dataset
      if offsets(k) == 0, continue; end
      
      signOffset = sign(offsets(k));
      if signOffset >= 0
          signOffset = '+';
      else
          signOffset = '-';
      end
      
      timeOffsetComment = ['timeOffsetPP: TIME values and time_coverage_start/end global attributes have been '...
          'applied the following offset : ' signOffset num2str(abs(offsets(k))) ' hours.'];
      
      % otherwise apply the offset
      sample_data{k}.(type){timeIdx}.data = ...
          sample_data{k}.(type){timeIdx}.data + (offsets(k) / 24);
      
      sample_data{k}.time_coverage_start = ...
          sample_data{k}.time_coverage_start      + (offsets(k) / 24);
      sample_data{k}.time_coverage_end   = ...
          sample_data{k}.time_coverage_end        + (offsets(k) / 24);
      
      comment = sample_data{k}.(type){timeIdx}.comment;
      if isempty(comment)
          sample_data{k}.(type){timeIdx}.comment = timeOffsetComment;
      else
          sample_data{k}.(type){timeIdx}.comment = [comment ' ' timeOffsetComment];
      end
      
      history = sample_data{k}.history;
      if isempty(history)
          sample_data{k}.history = sprintf('%s - %s', datestr(now_utc, readProperty('exportNetCDF.dateFormat')), timeOffsetComment);
      else
          sample_data{k}.history = sprintf('%s\n%s - %s', history, datestr(now_utc, readProperty('exportNetCDF.dateFormat')), timeOffsetComment);
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
