function flagVal = addFlagDialog( defaultVal )
%ADDFLAGDIALOG Dialog which allows user to choose a QC flag to apply to a
% set of points.
%
% Displays a dialog which allows the user to choose a QC flag. Returns the
% selected flag value, or the empty matrix if the user cancelled.
%
% Inputs:
%   defaultVal - The initial value to use..
%
% Outputs:
%   flagVal    - The selected value. If the user cancelled the dialog, 
%                flagVal will be the empty matrix.
%
% Author:       Paul McCarthy <paul.mccarthy@csiro.au>
% Contributor:  Guillaume Galibert <guillaume.galibert@utas.edu.au>
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
  error(nargchk(1,1,nargin));

  flagVal = defaultVal;

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

  % dialog figure
  f = figure(...
    'Name',        'Select Flag Value', ...
    'Visible',     'off',...
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

  % ok/cancel buttons
  cancelButton  = uicontrol('Style', 'pushbutton', 'String', 'Cancel');
  confirmButton = uicontrol('Style', 'pushbutton', 'String', 'Ok');

  % use normalized units for positioning
  set(f,             'Units', 'normalized');
  set(optList,       'Units', 'normalized');
  set(cancelButton,  'Units', 'normalized');
  set(confirmButton, 'Units', 'normalized');

  set(f,             'Position', [0.34, 0.46, 0.28, 0.08]);
  set(cancelButton,  'Position', [0.0,  0.0,  0.5,  0.5 ]);
  set(confirmButton, 'Position', [0.5,  0.0,  0.5,  0.5 ]);
  set(optList,       'Position', [0.0,  0.5,  1.0,  0.5 ]);

  % reset back to pixels
  set(f,             'Units', 'pixels');
  set(optList,       'Units', 'pixels');
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
    delete(f);
  end
end
