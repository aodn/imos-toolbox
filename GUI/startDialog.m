function [fieldTrip dataDir] = startDialog( dataDir, fieldTrip )
%STARTDIALOG Displays a dialog prompting the user to select a Field Trip ID
% and a directory which contains raw data files.
%
% The user is able to choose from a list of field trip IDs; these are 
% retrieved from the deployment database. When the user confirms the
% dialog, the selected field trip ID and data directory are returned. 
% If the user cancels the dialog, both the fieldTrip and dataDir return 
% values will be empty matrices.
%
% Inputs:
%
%   dataDir   - Optional. The default raw data directory to display. If
%               not provided, the current working directory (pwd) is used.
%
%   fieldTrip - Optional. The default field trip to display. If not
%               provided, the first field trip is used.
%
% Outputs:
%
%   fieldTrip - a numeric value; the field trip ID selected by the user..
%
%   dataDir   - a string containing the location of the directory selected
%               by the user.
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
  error(nargchk(0,2,nargin));
  
  % default values if args not provided
  if nargin == 0, dataDir   = pwd;     end
  if nargin < 2,  fieldTrip = -99999;  end
  
  if ~ischar(dataDir),      error('defaultDir must be a string'); end
  if ~isnumeric(fieldTrip), error('fieldTrip must be a numeric'); end

  % check that dataDir is a directory
  [stat atts] = fileattrib(dataDir);
  if ~stat || ~atts.directory || ~atts.UserRead
    error([dataDir ' does not exist, is not a directory, or is not readable']);
  end

  % retrieve all field trip IDs; they are displayed as a drop down menu
  fieldTrips = executeDDBQuery('FieldTrip', [], []);
  
  if isempty(fieldTrips), error('No field trip entries in DDB'); end
  
  defaultFieldTrip     = 1;
  defaultFieldTripDesc = ...
    [num2str(fieldTrips(1).FieldTripID) ': ' fieldTrips(1).FieldDescription];

  % create a cell array containing descriptions of all available field
  % trips; these are the entries of the field trip drop down menu
  fieldTripDescs = cell(size(fieldTrips));
  for k = 1:length(fieldTrips)

    f = fieldTrips(k);
    fieldTripDescs{k} = [num2str(f.FieldTripID) ': ' f.FieldDescription];
    
    % save default field trip selection
    if f.FieldTripID == fieldTrip
      defaultFieldTrip     = k; 
      defaultFieldTripDesc = fieldTripDescs{k};
    end
  end  
  
  fieldTrip = defaultFieldTripDesc;
  clear fieldTrips;
  clear defaultFieldTripDesc;
  
  %% Dialog creation
  %

  % dialog figure
  f = figure('Name',        'Select Field Trip', ...
             'Visible',     'off',...
             'MenuBar',     'none',...
             'Resize',      'off',...
             'WindowStyle', 'Modal');

  % create the widgets
  fidLabel      = uicontrol('Style',  'text',       'String', 'Field Trip ID');
  fidMenu       = uicontrol('Style',  'popupmenu', ...
                            'String', fieldTripDescs,...
                            'Value',  defaultFieldTrip);

  dirLabel      = uicontrol('Style', 'text',       'String', 'Data Directory');
  dirText       = uicontrol('Style', 'edit',       'String',  dataDir);
  dirButton     = uicontrol('Style', 'pushbutton', 'String', 'Browse');

  cancelButton  = uicontrol('Style', 'pushbutton', 'String', 'Cancel');
  confirmButton = uicontrol('Style', 'pushbutton', 'String', 'Ok');

  % labels and text are aligned to the left
  set([fidLabel, dirLabel, dirText], 'HorizontalAlignment', 'Left');

  % use normalised coordinates
  set(f,                              'Units', 'normalized');
  set([fidLabel,fidMenu],             'Units', 'normalized');
  set([dirLabel, dirText, dirButton], 'Units', 'normalized');
  set([cancelButton, confirmButton],  'Units', 'normalized');

  % position the widgets
  set(f,             'Position', [0.4,  0.45, 0.25,  0.08]);

  set(cancelButton,  'Position', [0.0,  0.0,  0.5,   0.34]);
  set(confirmButton, 'Position', [0.5,  0.0,  0.5,   0.34]);

  set(dirLabel,      'Position', [0.0,  0.35, 0.199, 0.33]);
  set(dirText,       'Position', [0.2,  0.35, 0.65,  0.33]);
  set(dirButton,     'Position', [0.85, 0.35, 0.15,  0.33]);

  set(fidLabel,      'Position', [0.0,  0.70, 0.199, 0.30]);
  set(fidMenu,       'Position', [0.2,  0.70, 0.8,   0.30]);
  
  % set widget callbacks
  set(f,             'CloseRequestFcn', @cancelCallback);
  set(fidMenu,       'Callback',        @fidMenuCallback);
  set(dirText,       'Callback',        @dirTextCallback);
  set(dirButton,     'Callback',        @dirButtonCallback);
  set(cancelButton,  'Callback',        @cancelCallback);
  set(confirmButton, 'Callback',        @confirmCallback);
  
  % user can hit escape to quit dialog. matlab sucks arse
  set(f,             'KeyPressFcn',     @keyPressCallback);
  set(fidMenu,       'KeyPressFcn',     @keyPressCallback);
  set(dirText,       'KeyPressFcn',     @keyPressCallback);
  set(dirButton,     'KeyPressFcn',     @keyPressCallback);
  set(cancelButton,  'KeyPressFcn',     @keyPressCallback);
  set(confirmButton, 'KeyPressFcn',     @keyPressCallback);

  % display the dialog and wait for user input
  set(f, 'Visible', 'on');
  uiwait(f);
  
  %% Callback functions
  %
  
  function keyPressCallback(source,ev)
  %KEYPRESSCALLBACK If the user pushes escape while the dialog has focus,
  % the dialog is closed. This is done by delegating to the cancelCallback
  % function.
    if strcmp(ev.Key, 'escape'), cancelCallback(source,ev); end
  end
  
  function fidMenuCallback(source,ev)
  % FIDMENUCALLBACK Field Trip ID popup menu callback. Saves the currently 
  % selected field trip.
  %
    str = get(source, 'String');
    val = get(source, 'Value');
    fieldTrip = str{val};
  end

  function dirTextCallback(source,ev)
  %DIRTEXTCALLBACK Directory text field callback. If the text entered in
  % the dirText field is a valid directory, saves it. Otherwise the dirText
  % field is reset.
  %
    newDir = get(source, 'String');
    
    % ignore invalid input
    if ~isdir(newDir), set(source, 'String', dataDir); return; end
    
    dataDir = newDir;
  end

  function dirButtonCallback(source,ev)
  %DIRBUTTONCALLBACK Directory browse button callback. Opens a file browser, 
  % prompting the user to select a directory. Saves the selected directory, 
  % and updates the contents of the dirText field.
  %
    newDir = '';
    
    while ~isdir(newDir)
      newDir = uigetdir(dataDir, 'Select Data Directory');
    
      % user cancelled dialog 
      if newDir == 0, return; end
    end
    
    % save new dir, update dirText text field
    dataDir = newDir;
    set(dirText, 'String', dataDir);
  end

  function cancelCallback(source,ev)
  %CANCELCALLBACK Cancel button callback. Discards user input and closes the 
  % dialog .
  %
    dataDir   = [];
    fieldTrip = [];
    delete(f);
  end

  function confirmCallback(source,ev)
  % CONFIRMCALLBACK. Confirm button callback. Closes the dialog.
  %
    delete(f);
  end


  %% Input processing
  %
  
  % if user cancelled, return empty matrices
  if isempty(dataDir) || isempty(fieldTrip), return; end
    
  % extract the field trip number from the description string
  colonIdx = find(fieldTrip == ':');
  fieldTrip = int32(str2double(fieldTrip(1:colonIdx(1)-1)));
  
end
