function [graphs lines] = graphTimeSeries( parent, sample_data, vars )
%GRAPHTIMESERIES Graphs the given data in a time series style using subplots.
%
% Graphs the selected variables from the given data set. Each variable is
% graphed by looking up the respective 'graphXY.m' function, where X is the
% IMOS name of the variable (e.g. TEMP, CDIR).
%
% Inputs:
%   parent             - handle to the parent container.
%   sample_data        - struct containing sample data.
%   vars               - Indices of variables that should be graphed..
%
% Outputs:
%   graphs             - A vector of handles to axes on which the data has 
%                        been graphed.
%   lines              - A matrix of handles to line or surface (or other) 
%                        handles which have been drawn, the same length as 
%                        graphs.
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
  
  if ~ishandle( parent),       error('parent must be a handle');      end
  if ~isstruct( sample_data),  error('sample_data must be a struct'); end
  if ~isnumeric(vars),         error('vars must be a numeric');       end
  
  graphs = [];
  lines  = [];
    
  if isempty(vars), return; end
  
  % get rid of variables that we should ignore
  sample_data.variables = sample_data.variables(vars);
  
  for k = 1:length(sample_data.variables)
    
    name = sample_data.variables{k}.name;
    uom  = imosParameters(name, 'uom');
    
    % create the axes
    graphs(k) = subplot(length(sample_data.variables), 1, k);
    
    set(graphs(k), 'Parent', parent,...
                   'XGrid',  'on',...
                   'Color', 'none',...
                   'YGrid',  'on');
    
    % make sure line colour alternate; because we are creating 
    % multiple axes, this is not done automatically for us
    col = get(graphs(k), 'ColorOrder');
    col = col(mod(k,length(col))+1,:);
    
    % plot the variable
    plotFunc                    = getGraphFunc('TimeSeries', 'graph', name);
    [lines(k,:) xLabel, yLabel] = plotFunc(   graphs(k), sample_data, k);
    
    % set the line colour - wrap in a try block, 
    % as surface plot colour cannot be set
    try set(lines(k,:), 'Color', col);
    catch e
    end
    
    % set x labels and ticks
    set(get(graphs(k), 'XLabel'), 'String', xLabel);

    xLimits = get(graphs(k), 'XLim');
    xStep   = (xLimits(2) - xLimits(1)) / 5;
    xTicks  = xLimits(1):xStep:xLimits(2);
    set(graphs(k), 'XTick', xTicks);

    % convert the tick labels into date strings
    xTicks = datestr(xTicks); 
    set(graphs(k), 'XTickLabel', xTicks);
    
    % set y label and ticks
    yLabel = [yLabel ' (' uom ')'];
    if length(yLabel) > 20, yLabel = [yLabel(1:17) '...']; end
    set(get(graphs(k), 'YLabel'), 'String', yLabel);
    
    yLimits = get(graphs(k), 'YLim');
    yStep   = (yLimits(2) - yLimits(1)) / 5;
    yTicks  = yLimits(1):yStep:yLimits(2);
    set(graphs(k), 'YTick', yTicks);
  end
  
  % link axes for panning/zooming
  linkaxes(graphs, 'x');
  
  % add a legend
  names = {};
  for k = 1:length(sample_data.variables)
    names{k} = sample_data.variables{k}.name;
  end
  legend(lines(:,1), names);
end
