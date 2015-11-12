function selectedSiteId = siteDialog(siteId, siteDesc)
%SITEDIALOG Displays a dialog prompting the user to select a Site.
%
% The user is able to choose from a list of site IDs retrieved from the deployment database. 
% When the user confirms the dialog, the selected site is returned. 
% If the user cancels the dialog, the siteId return values will be empty.
%
% Inputs:
%
%   siteId    - a cell array of site IDs.
%
%   siteDesc  - a cell array of description for each site ID.
%
% Outputs:
%
%   selectedSiteId    - a string of the selected site ID.
%
% Author: Guillaume Galibert <guillaume.galibert@utas.edu.au>
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
  narginchk(2,2);
  
  % generate site labels
  nSites = length(siteId);
  siteLabel = cell(1, nSites);
  for i=1:nSites
      siteLabel{i} = [siteId{i} ' (' siteDesc{i} ')'];
  end
  
  % currently selected site
  siteIdx = 1;
  selectedSiteId  = siteId{siteIdx};
  
  %% Dialog creation
  %

  % dialog figure
  f = figure('Name',        'Select Deployment Site', ...
             'Visible',     'off', ...
             'MenuBar',     'none', ...
             'Resize',      'off', ...
             'WindowStyle', 'Modal', ...
             'NumberTitle', 'off');

  % create the widgets
  fidLabel      = uicontrol('Style',  'text',...
                            'String', 'Site ID');
  fidList       = uicontrol('Style',  'listbox', 'Min', 1, 'Max', 1,...
                            'String', siteLabel,...
                            'Value',  siteIdx);
  cancelButton  = uicontrol('Style', 'pushbutton', 'String', 'Cancel');
  confirmButton = uicontrol('Style', 'pushbutton', 'String', 'Ok');

  % labels and text are aligned to the left
  set(fidLabel, 'HorizontalAlignment', 'Left');

  % use normalised coordinates
  set(f,                                'Units', 'normalized');
  set([fidLabel,fidList],               'Units', 'normalized');
  set([cancelButton, confirmButton],    'Units', 'normalized');

  % position the widgets
  set(f,               'Position', [0.2,  0.35,  0.6,   0.3]);
  set(cancelButton,    'Position', [0.0,  0.0,   0.5,   0.1]);
  set(confirmButton,   'Position', [0.5,  0.0,   0.5,   0.1]);
  set(fidLabel,        'Position', [0.0,  0.1,   0.2,   0.9]);
  set(fidList,         'Position', [0.2,  0.1,   0.8,   0.9]);
  
  % reset back to pixels
  set(f,                                'Units', 'pixels');
  set([fidLabel,fidList],               'Units', 'pixels');
  set([cancelButton, confirmButton],    'Units', 'pixels');
  
  % set widget callbacks
  set(f,               'CloseRequestFcn', @cancelCallback);
  set(fidList,         'Callback',        @fidMenuCallback);
  set(cancelButton,    'Callback',        @cancelCallback);
  set(confirmButton,   'Callback',        @confirmCallback);
  
  % user can hit escape to quit dialog
  set(f, 'WindowKeyPressFcn', @keyPressCallback);

  % display the dialog and wait for user input
  uicontrol(fidList);
  set(f, 'Visible', 'on');
  uiwait(f);
  
  %% Callback functions
  %
  
  function keyPressCallback(source,ev)
  %KEYPRESSCALLBACK If the user pushes escape/return while the dialog has 
  % focus, the dialog is cancelled/confirmed. This is done by delegating 
  % to the cancelCallback/confirmCallback functions.
  %
    if     strcmp(ev.Key, 'escape'), cancelCallback( source,ev); 
    elseif strcmp(ev.Key, 'return'), confirmCallback(source,ev); 
    end
  end
  
  function fidMenuCallback(source,ev)
  % FIDMENUCALLBACK site ID popup menu callback. Saves the currently 
  % selected site ID.
  %
    siteIdx = get(fidList, 'Value');
    selectedSiteId  = siteId{siteIdx};
  end

  function cancelCallback(source,ev)
  %CANCELCALLBACK Cancel button callback. Discards user input and closes the 
  % dialog .
  %
    selectedSiteId = [];
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
  if isempty(selectedSiteId), return; end
  
end