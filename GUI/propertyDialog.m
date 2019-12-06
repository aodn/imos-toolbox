function propertyDialog( filename, delim )
%PROPERTYDIALOG Displays a dialog allowing the user to configure the
% properties contained in the given file.
%
% A 'property' file is a file which contains a list of name value pairs,
% separated by a delimiter. If the optional delim parameter is not provided, 
% it is assumed that the file uses '=' as the delimiter.
%
% This function displays a dialog allowing the user to modify the
% properties contained in the given file, using the listProperties, 
% readProperty and writeProperty functions.
%
% Inputs:
%
%   filename - Valid path to the properties file to display.
%   delim    - Optional. Delimiter character/string. Defaults to '='.
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
  narginchk(1,2);
  
  if nargin == 1, delim = '='; end
  
  if ~ischar(filename),         error('filename must be a string'); end
  if ~exist( filename, 'file'), error('filename does not exist');   end
  if ~ischar(delim),            error('delim must be a string');    end
  
  % get property names and values
  [names values] = listProperties(filename, delim);
  
  if all(strcmpi(values, '')), return; end
  
  % create dialog and widgets
  f = figure(...
    'Name',        filename, ...
    'Visible',     'off',...
    'MenuBar',     'none',...
    'Resize',      'off',...
    'WindowStyle', 'Modal',...
    'NumberTitle', 'off'...
  );

  confirmButton = uicontrol('Parent', f, 'Style', 'pushbutton', 'String', 'Ok');
  cancelButton  = uicontrol('Parent', f, 'Style', 'pushbutton', 'String', 'Cancel');
  
  % create property name labels and value fields
  % with alternate background colour for each row
  nameLabels  = [];
  valueFields = [];
  
  for k = 1:length(names)
    
    nameLabels(k)  = uicontrol(...
      'Parent', f, ...
      'Style', 'text', ...
      'String', names{k},...
      'HorizontalAlignment', 'left');
    valueFields(k) = uicontrol(...
      'Parent', f, ...
      'Style', 'edit', ...
      'String', values{k}, ...
      'UserData', k,...
      'HorizontalAlignment', 'left');
  
    if mod(k, 2) ~= 0
      
      color = get(nameLabels(k), 'BackgroundColor');
      color = color - 0.05;
      
      set(nameLabels(k),  'BackgroundColor', color);
      set(valueFields(k), 'BackgroundColor', color);
    end
  end
  
  % normalized units for positioning
  set(f,             'Units', 'normalized');
  set(confirmButton, 'Units', 'normalized');
  set(cancelButton,  'Units', 'normalized');
  set(nameLabels,    'Units', 'normalized');
  set(valueFields,   'Units', 'normalized');
  
  % position dialog and widgets
  set(f,             'Position', [0.3, 0.3, 0.4, 0.4]);
  set(cancelButton,  'Position', [0.0, 0.0, 0.5, 0.1]);
  set(confirmButton, 'Position', [0.5, 0.0, 0.5, 0.1]);
  
  rlen = 0.9 / k;
  
  for k = 1:length(names)
    set(nameLabels(k),  'Position', [0.0, 1.0 - rlen * k, 0.5, rlen]);
    set(valueFields(k), 'Position', [0.5, 1.0 - rlen * k, 0.5, rlen]);
  end
  
  % back to pixel units 
  set(f,             'Units', 'pixels');
  set(confirmButton, 'Units', 'pixels');
  set(cancelButton,  'Units', 'pixels');
  set(nameLabels,    'Units', 'pixels');
  set(valueFields,   'Units', 'pixels');
  
  % set callbacks
  set(f,             'CloseRequestFcn',   @cancelCallback);
  set(f,             'WindowKeyPressFcn', @keyPressCallback);
  set(confirmButton, 'Callback',          @confirmCallback);
  set(cancelButton,  'Callback',          @cancelCallback);
  
  set(f, 'Visible', 'on');
  
  uiwait(f);
  
  function keyPressCallback(source,ev)
  %KEYPRESSCALLBACK If the user pushes escape while the dialog has focus,
  % the dialog is closed. This is done by delegating to the cancelCallback
  % function.
  %
    if     strcmp(ev.Key, 'escape'), cancelCallback( source,ev);
    elseif strcmp(ev.Key, 'return'), confirmCallback(source,ev); 
    end
  end

  function cancelCallback(source,ev)
  %CANCELCALLBACK Discards any changes the user may have made, and
  % closes the dialog.
  %
    delete(f);
  end

  function confirmCallback(source,ev)
  %CONFIRMCALLBACK Applies all property changes, and closes the dialog.
  %
  
    % update property values
    for k = 1:length(names)
      
      values{k} = get(valueFields(k), 'String');
      
      writeProperty(names{k}, values{k}, filename, delim);
    end
    
    delete(f);
  end
end
