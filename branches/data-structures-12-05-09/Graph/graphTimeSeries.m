function graphs = graphTimeSeries( ...
  parent, sample_data, cal_data, params, dimension )
%GRAPHTIMESERIES Graphs the given data in a time series style using subplots.
%
% Inputs:
%   parent       - handle to the parent container.
%   sample_data  - struct containing sample data.
%   cal_data     - struct containing sample metadata.
%   params       - Indices of parameters that should be graphed..
%   dimension    - index into the sample_data.dimensions vector, indicating
%                  which dimension should be the x axis.
%
% Outputs:
%   graphs      - handles to axes on which the data has been graphed.
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
  error(nargchk(5,5,nargin));
  
  if ~ishandle( parent),       error('parent must be a handle');            end
  if ~isstruct( sample_data),  error('sample_data must be a struct');       end
  if ~isstruct( cal_data),     error('cal_data must be a struct');          end
  if ~isnumeric(dimension)...
  || ~isscalar( dimension),    error('dimension must be a scalar numeric'); end

  if ~isnumeric(params),       error('params must be a numeric');           end
  
  graphs = [];
  lines  = [];
  
  if isempty(params), return; end
  
  % get rid of parameters that we should ignore
  sample_data.parameters = sample_data.parameters(params);
  cal_data   .parameters = cal_data   .parameters(params);
  
  for k = 1:length(sample_data.parameters)
    
    name = sample_data.parameters(k).name;
    uom  = imosParameters(name, 'uom');
    
    % create the axes
    graphs(k) = subplot(length(sample_data.parameters), 1, k);
    
    set(graphs(k), 'Parent', parent,...
                   'Color',  'none',...
                   'Units',  'normalized',...
                   'XGrid',  'on',...
                   'YGrid',  'on');
    
    % make sure line colour alternates; because we are creating 
    % multiple axes, this is not done automatically for us
    col = get(graphs(k), 'ColorOrder');
    col = col(mod(k,length(col))+1,:);
    
    % create the data plot
    lines(k) = line(sample_data.dimensions(dimension).data, ...
                    sample_data.parameters(k)        .data,...
                    'Color', col);
    
    % set x labels and ticks on graph 1
    xLabel = sample_data.dimensions(dimension).name;
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
  legend(lines, {sample_data.parameters.name});
end
