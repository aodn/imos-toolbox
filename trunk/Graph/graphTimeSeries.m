function [graphs lines flags] = graphTimeSeries( ...
  parent, sample_data, vars, dimension, displayFlags )
%GRAPHTIMESERIES Graphs the given data in a time series style using subplots.
%
% Inputs:
%   parent             - handle to the parent container.
%   sample_data        - struct containing sample data.
%   vars               - Indices of variables that should be graphed..
%   dimension          - index into the sample_data.dimensions vector, 
%                        indicating which dimension should be the x axis.
%   displayFlags       - Optional. Boolean. If true, the 
%                        sample_data.variables(x).flags values are displayed.
%
% Outputs:
%   graphs             - handles to axes on which the data has been graphed.
%   lines              - handles to lines which have been drawn.
%   flags              - handles to flags which have been drawn. Empty if
%                        no flags were drawn.
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
  error(nargchk(4,5,nargin));

  if nargin == 4, displayFlags = false; end
  
  if ~ishandle( parent),       error('parent must be a handle');            end
  if ~isstruct( sample_data),  error('sample_data must be a struct');       end
  if ~isnumeric(dimension)...
  || ~isscalar( dimension),    error('dimension must be a scalar numeric'); end

  if ~isnumeric(vars),         error('vars must be a numeric');             end
  if ~islogical(displayFlags), error('displayFlags must be a logical');     end
  
  graphs = [];
  lines  = [];
  flags  = [];
  
  qc_set = str2double(readToolboxProperty('toolbox.qc_set'));
  
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
    
    % make sure line colour alternates; because we are creating 
    % multiple axes, this is not done automatically for us
    col = get(graphs(k), 'ColorOrder');
    col = col(mod(k,length(col))+1,:);
    
    % create the data plot
    hold all;
    lines(k) = plot(sample_data.dimensions{dimension}.data, ...
                    sample_data.variables{k}         .data,...
                    'Color', col);
    
    % overlay flags if needed
    if displayFlags
      
      hold on;
      
      dim  = sample_data.dimensions{dimension}.data;
      f    = sample_data.variables{k}.flags;
      data = sample_data.variables{k}.data;
      
      f = find(f);
      if isempty(f), continue; end
      
      fx = dim(f);
      fy = data(f);
      
      % display flags in their appropriate colours
      for m = 1:length(f)
        
        fc(m,:) = ...
          imosQCFlag(sample_data.variables{k}.flags(f(m)), qc_set, 'color');
      end
      
      flags(k) = scatter(graphs(k), fx, fy, 100, fc, 'filled',...
        'MarkerEdgeColor', 'black');
    end
    
    % set x labels and ticks on graph 1
    xLabel = sample_data.dimensions{dimension}.name;
    set(get(graphs(k), 'XLabel'), 'String', xLabel);

    xLimits = get(graphs(k), 'XLim');
    xStep   = (xLimits(2) - xLimits(1)) / 5;
    xTicks  = xLimits(1):xStep:xLimits(2);
    set(graphs(k), 'XTick', xTicks);

    % if the x dimension is time, convert 
    % the tick labels into strings
    if strcmpi(xLabel, 'time')
      xTicks = datestr(xTicks); 
      set(graphs(k), 'XTickLabel', xTicks);
    end
    
    % set y label and ticks
    yLabel = [name ' ' uom];
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
  legend(lines, names);
end
