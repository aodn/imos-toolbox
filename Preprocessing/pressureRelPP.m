function sample_data = pressureRelPP( sample_data, qcLevel, auto )
%PRESSURERELPP Adds a PRES_REL variable to the given data sets, if not
% already exist and if they contain a PRES variable.
%
%
% Inputs:
%   sample_data - cell array of data sets, ideally with PRES variables.
%   qcLevel     - string, 'raw' or 'qc'. Some pp not applied when 'raw'.
%   auto        - logical, run pre-processing in batch mode.
%
% Outputs:
%   sample_data - the same data sets, with PRES_REL variables added.
%
% Author:       Guillaume Galibert <guillaume.galibert@utas.edu.au>
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
narginchk(2, 3);

if ~iscell(sample_data), error('sample_data must be a cell array'); end
if isempty(sample_data), return;                                    end

% auto logical in input to enable running under batch processing
if nargin<3, auto=false; end

% no modification of data is performed on the raw FV00 dataset except
% local time to UTC conversion
if strcmpi(qcLevel, 'raw'), return; end

pressureRelFile = ['Preprocessing' filesep 'pressureRelPP.txt'];
lenSam = length(sample_data);

descs     = cell(lenSam, 1);
sources   = cell(lenSam, 1);
offsets   = zeros(lenSam, 1);
sets      = ones(lenSam, 1);

% create descriptions, and get sources/offsets for each data set
for k = 1:lenSam
    
    descs{k}    = genSampleDataDesc(sample_data{k});
    sources{k}  = [];
    if isfield(sample_data{k}.meta, 'timezone')
        sources{k}  = sample_data{k}.instrument;
    end
    
    % if data set already contains PRES_REL data then next sample data
    if getVar(sample_data{k}.variables, 'PRES_REL'), continue; end
    
    presIdx = getVar(sample_data{k}.variables, 'PRES');
    
    % if no PRES data then next sample data
    if presIdx == 0, continue; end
    
    if isempty(sources{k})
        try
            offsets(k) = str2double(readProperty('default', pressureRelFile));
        end
    else
        try
            offsets(k) = str2double(readProperty(sources{k}, pressureRelFile));
        catch
            try
                offsets(k) = str2double(readProperty('default', pressureRelFile));
            end
        end
    end
end

if ~auto
    f = figure(...
        'Name',        'Pressure Offset',...
        'Visible',     'off',...
        'MenuBar'  ,   'none',...
        'Resize',      'off',...
        'WindowStyle', 'Modal',...
        'NumberTitle', 'off');
    
    cancelButton  = uicontrol('Style',  'pushbutton', 'String', 'Cancel');
    confirmButton = uicontrol('Style',  'pushbutton', 'String', 'Ok');
    
    setCheckboxes   = nan(lenSam, 1);
    sourceLabels    = nan(lenSam, 1);
    offsetFields    = nan(lenSam, 1);
    
    for k = 1:lenSam
        
        setCheckboxes(k) = uicontrol(...
            'Style',    'checkbox',...
            'String',   descs{k},...
            'Value',    1, ...
            'UserData', k);
        
        sourceLabels(k) = uicontrol(...
            'Style', 'text',...
            'String', sources{k});
        
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
    set(sourceLabels,   'Units', 'normalized');
    set(offsetFields,   'Units', 'normalized');
    
    set(f,             'Position', [0.2 0.35 0.6 0.3]);
    set(cancelButton,  'Position', [0.0 0.0  0.5 0.1]);
    set(confirmButton, 'Position', [0.5 0.0  0.5 0.1]);
    
    rowHeight = 0.9 / lenSam;
    for k = 1:lenSam
        
        rowStart = 1.0 - k * rowHeight;
        
        set(setCheckboxes (k), 'Position', [0.0 rowStart 0.6 rowHeight]);
        set(sourceLabels  (k), 'Position', [0.6 rowStart 0.2 rowHeight]);
        set(offsetFields  (k), 'Position', [0.8 rowStart 0.2 rowHeight]);
    end
    
    % set back to pixels
    set(f,              'Units', 'normalized');
    set(cancelButton,   'Units', 'normalized');
    set(confirmButton,  'Units', 'normalized');
    set(setCheckboxes,  'Units', 'normalized');
    set(sourceLabels,   'Units', 'normalized');
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

% apply the pressure offset to the selected datasets
for k = 1:lenSam
    
    % this set has been deselected or need not to be processed
    if ~sets(k) || offsets(k) == 0, continue; end
    
    sam = sample_data{k};
    
    % if data set already contains PRES_REL data then next sample data
    if getVar(sam.variables, 'PRES_REL'), continue; end
    
    presIdx = getVar(sam.variables, 'PRES');
    
    % if no PRES data then next sample data
    if presIdx == 0, continue; end
    
    computedPresRel = sam.variables{presIdx}.data + offsets(k);
    
    signOffset = sign(offsets(k));
    if signOffset >= 0
        signOffset = '+';
    else
        signOffset = '-';
    end
      
    % add PRES_REL data as new variable in data set
    dimensions = sam.variables{presIdx}.dimensions;
    computedPresRelComment = ['pressureRelPP: PRES_REL computed from PRES '...
        'applying the following offset : ' signOffset num2str(abs(offsets(k))) ' .'];
   
    if isfield(sam.variables{presIdx}, 'coordinates')
        coordinates = sam.variables{presIdx}.coordinates;
    else
        coordinates = '';
    end
    
    sample_data{k} = addVar(...
        sam, ...
        'PRES_REL', ...
        computedPresRel, ...
        dimensions, ...
        computedPresRelComment, ...
        coordinates);
    
    history = sample_data{k}.history;
    if isempty(history)
        sample_data{k}.history = sprintf('%s - %s', datestr(now_utc, readProperty('exportNetCDF.dateFormat')), computedPresRelComment);
    else
        sample_data{k}.history = sprintf('%s\n%s - %s', history, datestr(now_utc, readProperty('exportNetCDF.dateFormat')), computedPresRelComment);
    end
    
    sam = sample_data{k};
    
    presRelIdx = getVar(sam.variables, 'PRES_REL');
    sam.variables{presRelIdx}.applied_offset = offsets(k);
    sample_data{k} = sam;
    
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
        if isnan(val)
            set(source, 'String', num2str(offsets(idx)));
        else
            offsets(idx) = val;
        end
    end
end