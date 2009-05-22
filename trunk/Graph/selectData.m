function selectData( selectCallback )
%SELECTDATA Adds callbacks to the current figure, allowing the user
% to interact with data in the current axis using the mouse.
%
% This function adds callback functions to the current figure (gcf), allowing 
% the user to:
%   - click on a single point in the current axis (gca).
%   - click+drag to select a region in the current axis.
%
% The given selectCallback function is passed the selected point/region when 
% this occurs.
%
% Inputs:
%   selectCallback - function handle which is called when the user selects
%                    data. Must have the following format:
%
%                      function selectCallback(ax, type, range)
%
%                    where:
%                      ax    - axis in question
%                      type  - the value of the figure's 'SelectionType'
%                              property, which can be used to differentiate 
%                              between left/right mouse clicks.
%                      range - vector containing lower and upper x/y
%                              coordinates ([lx ly ux uy])
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
  error(nargchk(1,1,nargin));

  if ~isa(selectCallback, 'function_handle')
    error('selectCallback must be a function handle');
  end
  
  % add callbacks for dragging over an area of data/flags - 
  % this also accounts for click events
  f = gcf;
  set(f, 'WindowButtonDownFcn',   @buttonDown);
  set(f, 'WindowButtonMotionFcn', @buttonMove);
  set(f, 'WindowButtonUpFcn',     @buttonUp);
  
  % state variables used during dragging
  drag       = false;
  startPoint = [];
  endPoint   = [];
  rect       = [];
  rectPos    = [];
  
  function buttonDown(source,ev)
  %BUTTONDOWN Captures the coordinates when the mouse is clicked on an
  % axes.
  % 
    startPoint = get(gca, 'CurrentPoint');
    startPoint = startPoint([1 3]);
    
    rectPos = [startPoint 0.0001 0.0001];
    
    rect = rectangle(...
      'Parent',    gca,...
      'Position',  rectPos,...
      'EdgeColor', [1 1 1],...
      'LineStyle', '--',...
      'LineWidth', 0.25);
    
    drag = true;
  end

  function buttonMove(source,ev)
  %BUTTONMOVE Captures the coordinates when the mouse is dragged. Draws a
  % rectangle from where the mouse was clicked to the current mouse location.
  % 
    if ~drag, return; end
    
    endPoint = get(gca, 'CurrentPoint');
    endPoint = endPoint([1 3]);
    
    rectPos([1 2]) = min(startPoint,  endPoint);
    rectPos([3 4]) = abs(endPoint - startPoint);
    
    % guard against negative/zero width/height
    if ~any(rectPos([3 4]) <= 0), set(rect, 'Position', rectPos); end
  end

  function buttonUp(source,ev)
  %BUTTONUP Captures coordinates when the mouse button is released.
  % Calls the selectCallback.
  %
    endPoint = get(gca, 'CurrentPoint');
    endPoint = endPoint([1 3]);
    
    range = [min(startPoint, endPoint), max(startPoint, endPoint)];
    
    startPoint = [];
    endPoint   = [];
    drag       = false;
    delete(rect);
    rect =     [];
    
    selectCallback(gca, get(gcbf, 'SelectionType'), range);
  end
end
