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