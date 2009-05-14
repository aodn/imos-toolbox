function panel = tabbedPane( parent, tabs, tabNames )
%TABBEDPANE Creates a tabbed pane containing the given tabs (uipanels).
%
% Creates a panel which contains a row of buttons along the top (labelled
% with the given tabNames); when the user pushes a button, the
% corresponding tab is displayed in the panel.
%
% Inputs:
%   parent   - Figure or uipanel to be used as the parent.
%   tabs     - Vector of uipanel handles.
%   tabNames - Cell array of tab names, the same length as the tabs vector.
%
% Outputs:
%   panel    - Handle to the tabbed pane uipanel.
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
error(nargchk(3,3,nargin));

if ~ishandle(parent),    error('parent must be a graphics handle');          end
if ~isvector(tabs) ||...
    isempty(tabs)  ||...
   ~any(ishandle(tabs)), error('tabs must be a vector of graphics handles'); end
if ~iscellstr(tabNames), error('tabNames must be a cell array of strings');  end
if length(tabs) ~= length(tabNames)
                         error('tabs and tabNames must be the same length'); end

  % it's up to the caller to set the position
  panel = uipanel(...
    'Parent', parent,...
    'Units', 'normalized');
  
  buttons = [];
  
  % create tab button row along top
  numTabs = length(tabNames);
  for k = 1:length(tabNames)
    
    buttons(k) = uicontrol(...
      'Parent',   panel,...
      'Style',    'pushbutton',...
      'String',   tabNames{k},...
      'Units',    'normalized',...
      'Position', [(k-1)/numTabs, 0.95, 1/numTabs, 0.05],...
      'Callback', @tabCallback);
  end
  
  % set tab positions and make all tabs invisible
  set(tabs,...
    'Parent',   panel,...
    'Units',    'normalized',...
    'Position', [0.0, 0.0, 1.0, 0.95],...
    'Visible',  'off');
  
  % initialise so the first tab is displayed
  tabCallback(buttons(1), []);

  function tabCallback(source,ev)
  % Called when one of the tab buttons is clicked. Sets all but the selected 
  % tabs invisible.
    
    set(tabs,                    'Visible', 'off');
    set(tabs(buttons == source), 'Visible', 'on');
  end
end
