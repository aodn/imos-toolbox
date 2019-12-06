function [selected, cancel] = listSelectionDialog( title, allOpts, initialOpts, selectCell )
%LISTSELECTIONDIALOG Prompts the user to select a subset from a list of
% options.
%
% Displays a dialog which contains two lists; one contains the list of
% options that the user is able to select from, the other contains the list
% of currently selected options. 
%
% Inputs:
%   title       - The dialog title.
%   allOpts     - the list of all options that the user can select from.
%   initialOpts - Optional. Vector of indices into the allOpts array, 
%                 defining the options that should be selected when the 
%                 dialog is first displayed. If not provided, no options
%                 are selected.
%   selectCell  - Optional, cell array of 2 tuples {@function, buttonLabel}. 
%                 If provided, an extra button will be displayed 
%                 with a label. The function will be called when the 
%                 user pushes the button; the name of the 
%                 first selected item in the list of currently selected 
%                 items is passed to the function.
%
% Outputs:
%   selected    - Cell array containing the selected options If the user 
%                 cancelled the dialog, this vector is empty.
%
% Author:       Paul McCarthy <paul.mccarthy@csiro.au>
% Contributor:	Guillaume Galibert <guillaume.galibert@utas.edu.au>
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
  narginchk(2,4);

  if nargin == 2, initialOpts = []; end

  if ~ischar(title),          error('title must be a string');              end
  if ~iscellstr(allOpts),     error('allOpts must be a string cell array'); end
  if  isempty(allOpts),       error('allOpts is empty');                    end
  if ~isnumeric(initialOpts), error('initialOpts must be numeric');         end
  if exist('selectCell', 'var') && ~iscell(selectCell)
                              error('selectCell must be a cell array'); end
  if size(selectCell, 2) ~= 2, error('selectCell must contain n tuples of length 2'); end
  nTuples = size(selectCell, 1);
  function_handles = repmat({'function_handle'}, nTuples, 1);
  if any(~cellfun(@isa, selectCell(:, 1), function_handles)), error('selectCell first column must include function handlers'); end
  if any(~cellfun(@ischar, selectCell(:, 2))), error('selectCell second column must include strings'); end
  
  cancel = false;
                          
  % create the dialog  figure and widgets
  f = figure(...
    'Name',        title, ...
    'Visible',     'off',...
    'MenuBar',     'none',...
    'Resize',      'off',...
    'WindowStyle', 'modal',...
    'NumberTitle', 'off'...
  );

  selList       = uicontrol('Style', 'listbox', 'Max', 3);
  nSelList      = uicontrol('Style', 'listbox', 'Max', 3);
  
  rightArrow = sprintf('\x2192');
  leftArrow  = sprintf('\x2190');
  upArrow    = sprintf('\x2191');
  downArrow  = sprintf('\x2193');
  
  % windows doesn't necessarily support unicode characters
  if ispc
    rightArrow = '>';
    leftArrow  = '<';
    upArrow    = '^';
    downArrow  = 'v';
  end
  
  addButton     = uicontrol('Style', 'pushbutton', 'String', rightArrow);
  remButton     = uicontrol('Style', 'pushbutton', 'String', leftArrow);
  
  upButton      = uicontrol('Style', 'pushbutton', 'String', upArrow);
  downButton    = uicontrol('Style', 'pushbutton', 'String', downArrow);
  
  confirmButton = uicontrol('Style', 'pushbutton', 'String', 'Ok');
  cancelButton  = uicontrol('Style', 'pushbutton', 'String', 'Cancel');
  
  % normalised coordinates
  set(f,             'Units', 'normalized');
  set(selList,       'Units', 'normalized');
  set(nSelList,      'Units', 'normalized');
  set(addButton,     'Units', 'normalized');
  set(remButton,     'Units', 'normalized');
  set(upButton,      'Units', 'normalized');
  set(downButton,    'Units', 'normalized');
  set(confirmButton, 'Units', 'normalized');
  set(cancelButton,  'Units', 'normalized');
  
  % position the figure and widgets
  set(f,             'Position', [0.3, 0.36, 0.4, 0.28]);
  set(cancelButton,  'Position', [0.0, 0.0,  0.5, 0.1]);
  set(confirmButton, 'Position', [0.5, 0.0,  0.5, 0.1]);
  set(nSelList,      'Position', [0.0, 0.1,  0.4, 0.9]);
  set(selList,       'Position', [0.5, 0.1,  0.4, 0.9]);
  set(downButton,    'Position', [0.9, 0.45, 0.1, 0.1]);
  set(upButton,      'Position', [0.9, 0.55, 0.1, 0.1]);
  set(remButton,     'Position', [0.4, 0.45, 0.1, 0.1]);
  set(addButton,     'Position', [0.4, 0.55, 0.1, 0.1]);
  
  % reset back to pixels
  set(f,             'Units', 'pixels');
  set(selList,       'Units', 'pixels');
  set(nSelList,      'Units', 'pixels');
  set(addButton,     'Units', 'pixels');
  set(remButton,     'Units', 'pixels');
  set(upButton,      'Units', 'pixels');
  set(downButton,    'Units', 'pixels');
  set(confirmButton, 'Units', 'pixels');
  set(cancelButton,  'Units', 'pixels');
  
  % set callback functions
  set(f,             'WindowKeyPressFcn', @keyPressCallback);
  set(addButton,     'Callback',          @addButtonCallback);
  set(remButton,     'Callback',          @remButtonCallback);
  set(upButton,      'Callback',          @upButtonCallback);
  set(downButton,    'Callback',          @downButtonCallback);
  set(cancelButton,  'Callback',          @cancelCallback);
  set(confirmButton, 'Callback',          @confirmCallback);
  
  % set item select callback function if it was passed in
  if exist('selectCell', 'var')
    
      for i=1:nTuples
          selectButton = uicontrol(...
              'Style', 'pushbutton', ...
              'String', selectCell(i, 2), ...
              'Units', 'normalized', ...
              'Callback', {@selectCallback, i});
          
          set(selectButton, 'Position', [0.9, 0.9 - (i-1)*0.1, 0.1, 0.1]);
          set(selectButton, 'Units',    'pixels');
      end
  end
  
  % set the list data
  selected = {allOpts{initialOpts}};
  notSelected = true(size(allOpts));
  notSelected(initialOpts) = false;
  notSelected = {allOpts{notSelected}};
  
  set(nSelList, 'String', notSelected);
  set(selList,  'String', selected);

  set(f, 'Visible', 'on');
  uiwait(f);
  
  return;

  %% Callback functions
  
  %SELECTCALLBACK Wrapper for the real callback function. Calls selectCellCB,
  % and passes it the (first) currently selected item in the selected list.
  % Does nothing if no items are selected.
  %
  function selectCallback(source, ev, iButton)

    selIdx = get(selList, 'Value');
    
    if isempty(selIdx)
        fprintf('%s\n', 'Info : please first select a routine.');
        return;
    end
    
    % pass the selected item to the real callback function
    selectCellCB = selectCell{iButton, 1};
    [routines, chain] = selectCellCB(selected{selIdx(1)});
    
    if ~isempty(chain)
        % reset the list data to current setting (in case would have been
        % updated by previous callback
        chainIdx = cellfun(@(x)(find(ismember(routines,x))),chain);
        
        selected = {routines{chainIdx}};
        notSelected = true(size(routines));
        notSelected(chainIdx) = false;
        notSelected = {routines{notSelected}};
        
        set(nSelList, 'String', notSelected);
        set(selList,  'String', selected);
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
  
  function addButtonCallback(source,ev)
  %ADDBUTTONCALLBACK Moves the selected entries from the nSelList to the
  % selList.
  %
    if isempty(notSelected), return; end
    selIdxs = get(nSelList, 'Value');
    sel = {notSelected{selIdxs}};
    
    notSelected(selIdxs) = [];
    selected = [selected sel];
    
    set(nSelList, 'String', notSelected);
    set(selList,  'String', selected);
    set(nSelList, 'Value', 1);
    set(selList,  'Value', 1);
  end


  function remButtonCallback(source,ev)
  %REMBUTTONCALLBACK Moves the selected entries from the selList to the
  % nSelList.
  %
    if isempty(selected), return; end
    selIdxs = get(selList, 'Value');
    sel = {selected{selIdxs}};
    
    selected(selIdxs) = [];
    notSelected = [notSelected sel];
    
    set(nSelList, 'String', notSelected);
    set(selList,  'String', selected);
    set(nSelList, 'Value', 1);
    set(selList,  'Value', 1);
  end

  function upButtonCallback(source,ev)
  %UPBUTTONCALLBACK Moves the selected entries from the selList up.
  %
    selIdxs = get(selList, 'Value');
    sel = {selected{selIdxs}};
    
    for k = 1:length(sel)
      
      if selIdxs(k) == 1, continue; end
      
      selected{selIdxs(k)}   = selected{selIdxs(k)-1};
      selected{selIdxs(k)-1} = sel{k};
    end
    
    selIdxs = selIdxs - 1;
    selIdxs(selIdxs < 1) = [];
    
    set(selList, 'String', selected);
    set(selList, 'Value', selIdxs);
  end

  function downButtonCallback(source,ev)
  %DOWNBUTTONCALLBACK Moves the selected entries from the selList down.
  %
    selIdxs = get(selList, 'Value');
    sel = {selected{selIdxs}};
    
    for k = length(sel):-1:1
      
      if selIdxs(k) == length(selected), continue; end
      
      selected{selIdxs(k)} = selected{selIdxs(k)+1};
      selected{selIdxs(k)+1} = sel{k};
    end
    
    selIdxs = selIdxs + 1;
    selIdxs(selIdxs > length(selected)) = [];
    
    set(selList, 'String', selected);
    set(selList, 'Value', selIdxs);
  end

  function cancelCallback(source,ev)
  %CANCELCALLBACK Discards user input and closes the dialog.
  %
    selected = [];
    cancel = true;
    delete(f);
  end

  function confirmCallback(source,ev)
  %CONFIRMCALLBACK Closes the dialog.
  %
    delete(f);
  end
end
