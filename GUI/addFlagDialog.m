function [returnVars, flagVal, commentText] = addFlagDialog( variable, kVar, defaultVal )
%ADDFLAGDIALOG Dialog which allows user to choose a QC flag to apply to a
% set of points of a given variable. Can be extended to other similar variables.
%
% Displays a dialog which allows the user to choose a QC flag. Returns the
% selected flag value, or the empty matrix if the user cancelled.
%
% Inputs:
%   variable   - Variable field structure from sample_data structure
%   kVar       - index of current variable being manually QC'd
%   defaultVal - The initial value to use..
%
% Outputs:
%   returnVars - Indices of variables for which original manual QC needs to
%                be generalised.
%   flagVal    - The selected value. If the user cancelled the dialog, 
%                flagVal will be the empty matrix.
%   commentText- The input comment text.
%
% Author:       Paul McCarthy <paul.mccarthy@csiro.au>
% Contributor:  Guillaume Galibert <guillaume.galibert@utas.edu.au>
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
  narginchk(3,3);

  flagVal = defaultVal;
  commentText = '';
  
  qcSet = str2double(readProperty('toolbox.qc_set'));

  flagTypes  = imosQCFlag('', qcSet, 'values');
  flagDescs  = {};
  flagColors = {};
  
  iFlagVal = (flagTypes == flagVal);
  if ~any(iFlagVal)
    error('defaultVal is not a member of the current QC set'); 
  end

  % retrieve all the flag descriptions and display colours
  for k = 1:length(flagTypes)

    flagDescs{k}  = imosQCFlag(flagTypes(k), qcSet, 'desc');
    flagColors{k} = imosQCFlag(flagTypes(k), qcSet, 'color');
  end

  % generate a menu description for each flag value
  for k = 1:length(flagTypes)
    col = sprintf('#%02x%02x%02x', uint8(flagColors{k} * 255));
    opts{k} = ['<html><font color="' col '">' ...
               num2str(flagTypes(k)) ': ' flagDescs{k} ...
               '</font></html>'];
  end
  
  returnVars = kVar;
  % retrieve a list of similar variables based on dimensions
  kVars = [];
  nameVars = {};
  currVarDims = variable{kVar}.dimensions;
  for k = 1:length(variable)
      if length(variable{k}.dimensions) == length(currVarDims)
          if all(variable{k}.dimensions == currVarDims)
              kVars(end+1) = k;
              nameVars{end+1} = variable{k}.name;
          end
      end
  end

  % dialog figure
  f = figure(...
    'Name',        'Select Flag Value', ...
    'Visible',     'on',...
    'MenuBar',     'none',...
    'Resize',      'off',...
    'WindowStyle', 'Modal',...
    'NumberTitle', 'off');

  % flag list
  listOpt = 1;
  if ~isempty(flagVal), listOpt = find(iFlagVal); end
  if  isempty(listOpt), listOpt = 1; end
  
  optList = uicontrol(...
      'Style', 'popupmenu',...
      'String', opts,...
      'Value', listOpt);
  
  % create a panel for the list of variables
  setPanel = uipanel(...
      'BorderType', 'none');
  
  % create a panel for the comment
  commentPanel = uipanel(...
      'BorderType', 'none');
  
  % ok/cancel buttons
  cancelButton  = uicontrol('Style', 'pushbutton', 'String', 'Cancel');
  confirmButton = uicontrol('Style', 'pushbutton', 'String', 'Ok');

  % use normalized units for positioning
  set(f,             'Units', 'normalized');
  set(optList,       'Units', 'normalized');
  set(setPanel,      'Units', 'normalized');
  set(commentPanel,  'Units', 'normalized');
  set(cancelButton,  'Units', 'normalized');
  set(confirmButton, 'Units', 'normalized');

%   set(f,             'Position', [0.34, 0.46, 0.28, 0.2]);
  set(f,             'Position', [0.34, 0.46, 0.28, 0.4]);
  set(optList,       'Position', [0.0,  0.9,  1.0,  0.1]);
  set(setPanel,      'Position', [0.0,  0.5,  1.0,  0.4]);
  set(commentPanel,  'Position', [0.0,  0.1,  1.0,  0.4]);
  set(cancelButton,  'Position', [0.0,  0.0,  0.5,  0.1]);
  set(confirmButton, 'Position', [0.5,  0.0,  0.5,  0.1]);

  % populate the panel for variable selection
  uicontrol(...
        'Parent',              setPanel, ...
        'Style',               'text', ...
        'String',              'Applies to:', ...
        'HorizontalAlignment', 'Left', ...
        'Units',               'normalized', ...
        'Position',            [0.0,  0.2,  0.15, 0.7] ...
      );
  
  nVars = length(kVars);
  numRows = ceil(nVars / 2);
  vHeight = 0.7 / numRows;
  varCheckboxes = nan(1, nVars);
  iVars = false(1, nVars);
  for k = 1:nVars
      % default selected variable is the currently QC'd one
      if strcmpi(nameVars{k}, variable{kVar}.name)
          value = 1;
          iVars(k) = true;
      else
          value = 0;
      end
      
      % figure out vertical start position of this variable's row
      vStart = vHeight * mod(k, numRows);
      if vStart == 0, vStart = vHeight * numRows; end
      vStart = 0.9 - vStart;
      
      hStart = 0.15;
      
      % second half of variable list -> second column
      if k > numRows, hStart = 0.575; end
      pos = [hStart, vStart, 0.425, vHeight];
      
      varCheckboxes(k) = uicontrol(...
          'Parent',   setPanel, ...
          'Style',    'checkbox', ...
          'String',   nameVars{k}, ...
          'Value',    value, ...
          'UserData', k, ...
          'Units',    'normalized', ...
          'Position', pos ...
          );
  end
  
  set(varCheckboxes, 'Callback', @varCheckboxCallback);
  
  % populate the panel for variable selection
  uicontrol(...
        'Parent',              commentPanel, ...
        'Style',               'text', ...
        'String',              'Comment:', ...
        'HorizontalAlignment', 'Left', ...
        'Units',               'normalized', ...
        'Position',            [0.0,  0.1,  0.15, 0.7] ...
      );
  
  comment = uicontrol(...
        'Parent',              commentPanel, ...
        'Style',               'edit', ...
        'BackgroundColor',     'w', ...
        'HorizontalAlignment', 'Left', ...
        'Units',               'normalized', ...
        'Position',            [0.15,  0.1,  0.8, 0.7] ...
      );
  
  % reset back to pixels
  set(f,             'Units', 'pixels');
  set(optList,       'Units', 'pixels');
  set(setPanel,      'Units', 'pixels');
  set(commentPanel,  'Units', 'pixels');
  set(cancelButton,  'Units', 'pixels');
  set(confirmButton, 'Units', 'pixels');
  
  % add callbacks
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
  %OPTLISTCALLBACK Called when the user selects an item from the flag drop
  % down list. Updates the currently selected flag value.
  %
    idx = get(optList, 'Value');
    flagVal = flagTypes(idx);
    
  end
  
  function varCheckboxCallback(source,ev)
  %VARCHECKBOXCALLBACK Saves the variable selection for the current data set.
  %
    varIdx = get(source, 'UserData');
    iVars(varIdx) = get(source, 'Value');
    returnVars = kVars(iVars);
  end

  function cancelCallback(source,ev)
  %CANCELCALLBACK Cancel button callback. Discards user input and closes the 
  % dialog .
  %
    flagVal = [];
    delete(f);
  end

  function confirmCallback(source,ev)
  % CONFIRMCALLBACK. Confirm button callback. Closes the dialog.
  %
    commentText = get(comment, 'String');
    delete(f);
  end
end
