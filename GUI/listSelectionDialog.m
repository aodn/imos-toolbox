function [selected, cancel] = listSelectionDialog( ...
  title, allOpts, initialOpts, selectCB, selectLabel )
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
%   selectCB    - Optional. If provided, an extra button will be displayed 
%                 with a default label of 'Select'. This function will be 
%                 called when the user pushes the button; the name of the 
%                 first selected item in the list of currently selected 
%                 items is passed to the function.
%   selectLabel - Optional. If provided, is used as the label for the
%                 selectCB button.
%
% Outputs:
%   selected    - Cell array containing the selected options If the user 
%                 cancelled the dialog, this vector is empty.
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
  error(nargchk(2,5,nargin));

  if nargin == 2, initialOpts = []; end
  if nargin == 4, selectLabel = 'Select'; end

  if ~ischar(title),          error('title must be a string');              end
  if ~iscellstr(allOpts),     error('allOpts must be a string cell array'); end
  if  isempty(allOpts),       error('allOpts is empty');                    end
  if ~isnumeric(initialOpts), error('initialOpts must be numeric');         end
  if  exist('selectCB', 'var') && ~isa(selectCB, 'function_handle')
                              error('selectCB must be a handle');           end
  if  exist('selectLabel', 'var') && ~ischar(selectLabel)
                              error('selectLabel must be a string');        end
  
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
  if exist('selectCB', 'var')
    
    selectButton = uicontrol(...
      'Style', 'pushbutton', ...
      'String', selectLabel,...
      'Units', 'normalized',...
      'Callback', @selectCallback);
    
    set(selectButton, 'Position', [0.9, 0.9, 0.1, 0.1]);
    set(selectButton, 'Units',    'pixels');
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
  
  %SELECTCALLBACK Wrapper for the real callback function. Calls selectCB,
  % and passes it the (first) currently selected item in the selected list.
  % Does nothing if no items are selected.
  %
  function selectCallback(source, ev)

    selIdx = get(selList, 'Value');
    
    if isempty(selIdx), return; end
    
    % pass the selected item to the real callback function
    selectCB(selected{selIdx(1)});

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
