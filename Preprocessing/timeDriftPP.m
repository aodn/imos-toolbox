function sample_data = timeDriftPP(sample_data, qcLevel, auto)
%TIMEDRIFTPP Prompts the user to apply time drift correction to the given data 
% sets. A pre-deployment time offset and end deployment time offset are
% required and if included in the DDB (or CSV file), will be shown in the
% dialog box. Otherwise, user is required to enter them.
%
% Offsets should be entered in seconds from UTC time (instrumentTime - UTCtime).
% An offset at the start will result in an offset to the start time. Global
% attributes of time coverage are also adjusted.
%
% All IMOS datasets should be provided in UTC time. Raw data may not
% necessarily have been captured in UTC time, so a correction must be made
% before the data can be considered to be in an IMOS compatible format.
%
% Default time offset values for timezone codes are stored in a plain text
% file, timeDriftPP.txt.
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
%               Rebecca Cowley <rebecca.cowley@csiro.au>
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
  
  % auto logical in input to enable running under batch processing
  if nargin<3, auto=false; end
      
  descs     = {};
  startOffsets   = zeros(length(sample_data),1);
  endOffsets = startOffsets;
  sets      = ones(length(sample_data), 1);
  
  % create descriptions, and get timezones/offsets for each data set
  for k = 1:length(sample_data)
      
      descs{k} = genSampleDataDesc(sample_data{k});
      if isfield(sample_data{k}.meta.deployment,'StartOffset')
          %check to see if the offsets are available already from the ddb
          startOffsets(k) = str2num(sample_data{k}.meta.deployment.StartOffset);
      end
      if isfield(sample_data{k}.meta.deployment,'EndOffset')
          endOffsets(k) = str2num(sample_data{k}.meta.deployment.EndOffset);
      end
  end
  
  if ~auto
      f = figure(...
          'Name',        'Time drift calculations',...
          'Visible',     'off',...
          'MenuBar'  ,   'none',...
          'Resize',      'off',...
          'WindowStyle', 'Modal',...
          'NumberTitle', 'off');
      
      cancelButton  = uicontrol('Style',  'pushbutton', 'String', 'Cancel');
      confirmButton = uicontrol('Style',  'pushbutton', 'String', 'Ok');
      
      setCheckboxes  = [];
      startOffsetFields   = [];
      endOffsetFields = [];
      
      for k = 1:length(sample_data)
          
          setCheckboxes(k) = uicontrol(...
              'Style',    'checkbox',...
              'String',   descs{k},...
              'Value',    1, ...
              'UserData', k);
          
          startOffsetFields(k) = uicontrol(...
              'Style',    'edit',...
              'UserData', k, ...
              'String',   num2str(startOffsets(k)));
          
          endOffsetFields(k) = uicontrol(...
              'Style',    'edit',...
              'UserData', k, ...
              'String',   num2str(endOffsets(k)));

      end
      
      % set all widgets to normalized for positioning
      set(f,              'Units', 'normalized');
      set(cancelButton,   'Units', 'normalized');
      set(confirmButton,  'Units', 'normalized');
      set(setCheckboxes,  'Units', 'normalized');
      set(startOffsetFields,   'Units', 'normalized');
      set(endOffsetFields,   'Units', 'normalized');
      
      set(f,             'Position', [0.2 0.35 0.6 0.0222*length(sample_data]);
      set(cancelButton,  'Position', [0.0 0.0  0.5 0.1]);
      set(confirmButton, 'Position', [0.5 0.0  0.5 0.1]);
      
      rowHeight = 0.9 / length(sample_data);
      for k = 1:length(sample_data)
          
          rowStart = 1.0 - k * rowHeight;
          
          set(setCheckboxes (k), 'Position', [0.0 rowStart 0.6 rowHeight]);
          set(startOffsetFields  (k), 'Position', [0.6 rowStart 0.2 rowHeight]);
          set(endOffsetFields  (k), 'Position', [0.8 rowStart 0.2 rowHeight]);
      end
      
      % set back to pixels
      set(f,              'Units', 'normalized');
      set(cancelButton,   'Units', 'normalized');
      set(confirmButton,  'Units', 'normalized');
      set(setCheckboxes,  'Units', 'normalized');
      set(startOffsetFields,   'Units', 'normalized');
      set(endOffsetFields,   'Units', 'normalized');
      
      % set widget callbacks
      set(f,             'CloseRequestFcn',   @cancelCallback);
      set(f,             'WindowKeyPressFcn', @keyPressCallback);
      set(setCheckboxes, 'Callback',          @checkboxCallback);
      set(startOffsetFields,  'Callback',          @startoffsetFieldCallback);
      set(endOffsetFields,  'Callback',          @endoffsetFieldCallback);
      set(cancelButton,  'Callback',          @cancelCallback);
      set(confirmButton, 'Callback',          @confirmCallback);
      
      set(f, 'Visible', 'on');
      
      uiwait(f);
  end
  
  % calculate the drift and apply to the selected datasets
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
      
      signOffset = sign(startOffsets(k));
      if signOffset >= 0
          signOffset = '+';
      else
          signOffset = '-';
      end
      
      timeDriftComment = ['timeDriftPP: TIME values and time_coverage_end global attributes have been have been '...
          'linearly adjusted for a drift of: ' signOffset num2str(abs(endOffsets(k) - startOffsets(k))) ' seconds ' ...
          'across the deployment.'];
      
      % apply the drift correction
      newtime = timedrift_corr(sample_data{k}.(type){timeIdx}.data, ...
          startOffsets(k),endOffsets(k));
      sample_data{k}.(type){timeIdx}.data = newtime;
      
      % and to the time coverage atttributes
      sample_data{k}.time_coverage_start = newtime(1);
      sample_data{k}.time_coverage_end = ...
          newtime(end);
      
      
      comment = sample_data{k}.(type){timeIdx}.comment;
      if isempty(comment)
          sample_data{k}.(type){timeIdx}.comment = timeDriftComment;
      else
          sample_data{k}.(type){timeIdx}.comment = [comment ' ' timeDriftComment];
      end
      
      history = sample_data{k}.history;
      if isempty(history)
          sample_data{k}.history = sprintf('%s - %s', datestr(now_utc, ...
              readProperty('exportNetCDF.dateFormat')), timeDriftComment);
      else
          sample_data{k}.history = sprintf('%s\n%s - %s', history, ...
              datestr(now_utc, readProperty('exportNetCDF.dateFormat')), timeDriftComment);
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
    startOffsets(:) = 0;
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
    
    set(startOffsetFields(idx), 'Enable', val);
    
  end

  function startoffsetFieldCallback(source, ev)
  %OFFSETFIELDCALLBACK Called when the user edits one of the offset fields.
  % Verifies that the text entered is a number.
  %
  
    val = get(source, 'String');
    idx = get(source, 'UserData');
    
    val = str2double(val);
    
    % reset the offset value on non-numerical 
    % input, otherwise save the new value
    if isnan(val), set(source, 'String', num2str(startOffsets(idx)));
    else           startOffsets(idx) = val;
    
    end
  end

  function endoffsetFieldCallback(source, ev)
      %OFFSETFIELDCALLBACK Called when the user edits one of the offset fields.
      % Verifies that the text entered is a number.
      %
      
      val = get(source, 'String');
      idx = get(source, 'UserData');
      
      val = str2double(val);
      
      % reset the offset value on non-numerical
      % input, otherwise save the new value
      if isnan(val), set(source, 'String', num2str(endOffsets(idx)));
      else           endOffsets(idx) = val;
          
      end
  end

    function newtime = timedrift_corr(time,offset_s,offset_e)
        %remove linear drift of time (in days) from any instrument.
        %the drift is calculated using the start offset (offset_s in seconds) and the
        % end offset (offset_e in seconds).
        %Bec Cowley, April 2014
        
%         change the offset times to days:
        offset_e = offset_e/60/60/24;
        offset_s = offset_s/60/60/24;
        
        %make an array of time corrections using the offsets:
        tarray = (offset_s:(offset_e-offset_s)/(length(time)-1):offset_e)';
        if isempty(tarray)
            newtime = [];
        else
            newtime = time - tarray;
        end
    end
end