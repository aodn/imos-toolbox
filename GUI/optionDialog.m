function choice = optionDialog( title, message, options, default )
%OPTIONDIALOG Prompts the user to select an item from a drop down list of 
% options.
%
% Displays a dialog allowing the user to select from a drop down list of
% optiowns.
%
% Inputs:
%   title   - the dialog title
%   message - the message to display.
%
%   options - Cell array of strings, defining the options available to the
%             user.
%
%   default - Index into the options array, defining the option which
%             should be initially selected.
%
% Outputs:
%   choice  - the selected option, or an empty matrix if the user cancelled
%             the dialog.
%
% Author: Paul McCarthy <paul.mccarthy@csiro.au>
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
  narginchk(4,4);

  if ~ischar(title),      error('title must be a string');                  end
  if ~ischar(message),    error('message must be a string');                end
  if ~iscellstr(options), error('options must be a cell array of strings'); end
  if ~isnumeric(default), error('default must be a number');                end
  if isempty(options),    error('options is empty');                        end
  options{default};       % will throw an error if default is not 
                          % a valid index into the options array
                          
  choice = options{default};

  % dialog figure
  f = figure(...
    'Name',        title, ...
    'Visible',     'off',...
    'MenuBar',     'none',...
    'Resize',      'off',...
    'WindowStyle', 'Modal',...
    'NumberTitle', 'off');

  % message panel
  msgPanel = uicontrol(...
    'Style', 'text',...
    'String', message);

  % option list
  optList = uicontrol(...
    'Style', 'popupmenu',...
    'String', options,...
    'Value', default);

  % ok/cancel buttons
  cancelButton  = uicontrol('Style', 'pushbutton', 'String', 'Cancel');
  confirmButton = uicontrol('Style', 'pushbutton', 'String', 'Ok');

  % use normalized units for positioning
  set(f,             'Units', 'normalized');
  set(msgPanel,      'Units', 'normalized');
  set(optList,       'Units', 'normalized');
  set(cancelButton,  'Units', 'normalized');
  set(confirmButton, 'Units', 'normalized');

  set(f,             'Position', [0.3,  0.46, 0.4,  0.08]);
  set(cancelButton,  'Position', [0.0,  0.0,  0.5,  0.3 ]);
  set(confirmButton, 'Position', [0.5,  0.0,  0.5,  0.3 ]);
  set(optList,       'Position', [0.0,  0.3,  1.0,  0.3 ]);
  set(msgPanel,      'Position', [0.0,  0.6,  1.0,  0.4 ]);

  % reset back to pixels
  set(f,             'Units', 'pixels');
  set(msgPanel,      'Units', 'pixels');
  set(optList,       'Units', 'pixels');
  set(cancelButton,  'Units', 'pixels');
  set(confirmButton, 'Units', 'pixels');
  
  % set callbacks
  set(f,             'WindowKeyPressFcn', @keyPressCallback);
  set(f,             'CloseRequestFcn',   @cancelCallback);
  set(optList,       'Callback',          @optListCallback);
  set(cancelButton,  'Callback',          @cancelCallback);
  set(confirmButton, 'Callback',          @confirmCallback);

  set(f, 'Visible', 'on');
  uiwait(f);

  function keyPressCallback(source,ev)
  %KEYPRESSCALLBACK If the user pushes escape/return while the dialog has 
  % focus, the dialog is cancelled/confirmed. This is done by delegating 
  % to the cancelCallback/confirmCallback functions.
  %
    if     strcmp(ev.Key, 'escape'), cancelCallback( source,ev); 
    elseif strcmp(ev.Key, 'return'), confirmCallback(source,ev); 
    end
  end

  function optListCallback(source,ev)
  %OPTLISTCALLBACK Called when the user selects an item from the drop down 
  % list. Updates the currently selected choice.
  %
    idx = get(optList, 'Value');
    choice = options{idx};
  end
  
  function cancelCallback(source,ev)
  %CANCELCALLBACK Cancel button callback. Discards user input and closes the 
  % dialog .
  %
    choice = [];
    delete(f);
  end

  function confirmCallback(source,ev)
  % CONFIRMCALLBACK. Confirm button callback. Closes the dialog.
  %
    delete(f);
  end
end
