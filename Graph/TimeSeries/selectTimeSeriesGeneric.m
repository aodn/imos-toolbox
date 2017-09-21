function selectTimeSeriesGeneric( selectCallback, clickCallback )
%SELECTTIMESERIESGENERIC Adds callbacks to the current figure, allowing the 
% user to interact with data in the current axis using the mouse.
%
% This function adds callback functions to the current figure (gcf), allowing 
% the user to:
%   - click on a single point in the current axis (gca).
%   - click+drag to select a region in the current axis.
%
% The given selectCallback/clickCallback functions are called when the user 
% clicks/selects on a point/region of points. The type parameter can be used 
% to differentiate between left/right clicks/drags. The possible values for 
% type are:
%   - 'normal' - left click/drag
%   - 'alt'    - right click/drag
%
% Inputs:
%   selectCallback - function handle which is called when the user selects
%                    a region. Must have the following format:
%
%                      function selectCallback(ax, type, range)
%
%                    where:
%                      ax    - axis in question
%                      type  - the value of the figure's 'SelectionType'
%                              property, which can be used to differentiate 
%                              between left/right mouse drags.
%                      range - vector containing lower and upper x/y
%                              coordinates ([lx ly ux uy])
%
%   clickCallback  - function handle which is called when the user clicks
%                    on a point. Must have the following format:
%
%                      function clickCallback(ax, type, point)
% 
%                    where:
%                      ax    - axis in question
%                      type  - the value of the figure's 'SelectionType'
%                              property, which can be used to differentiate 
%                              between left/right mouse clicks.
%                      point - Vector containing click coordinates ([x y])
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
  narginchk(2, 2);

  if ~isa(selectCallback, 'function_handle')
    error('selectCallback must be a function handle');
  end
  if ~isa(clickCallback, 'function_handle')
    error('clickCallback must be a function handle');
  end
  
  % get handle to the current figure
  f = gcf;
  
  % add callbacks for dragging over an area of data/flags - 
  % this also accounts for click events
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
    % bail if the user clicks another mouse button while dragging
    if drag
      startPoint = [];
      endPoint   = [];
      drag       = false;
      delete(rect);
      rect       = [];
      return; 
    end
    
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
    if ~drag, return; end
    
    endPoint = get(gca, 'CurrentPoint');
    endPoint = endPoint([1 3]);
    
    range = [min(startPoint, endPoint), max(startPoint, endPoint)];
    
    type = get(gcbf, 'SelectionType');
    
    % click or drag?
    click = false;
    if startPoint == endPoint, click = true; end
    
    point = startPoint;
    
    startPoint = [];
    endPoint   = [];
    drag       = false;
    delete(rect);
    rect       = [];
    
    if click, clickCallback( gca, type, point);
    else      selectCallback(gca, type, range);
    end
  end
end
