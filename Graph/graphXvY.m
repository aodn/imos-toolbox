function [graphs, lines, vars] = graphXvY( parent, sample_data, vars )
%GRAPHTRANSECT Graphs the two variables selected from the given data set
% against each other on an X-Y axis.
%
% Inputs:
%   parent             - handle to the parent container.
%   sample_data        - struct containing sample data.
%   vars               - Indices of variables that should be graphed.
%
% Outputs:
%   graphs             - A vector of handles to the axes on which the data has 
%                        been graphed.
%   lines              - A matrix of handles to lines which has been drawn.
%   vars               - Indices of variables which were graphed.
%
% Author:       Paul McCarthy <paul.mccarthy@csiro.au>
% Contributor:  Guillaume Galibert <guillaume.galibert@utas.edu.au>
%

%
% Copyright (c) 2016, Australian Ocean Data Network (AODN) and Integrated 
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
%     * Neither the name of the AODN/IMOS nor the names of its contributors 
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
  narginchk(3,3);
  
  if ~ishandle( parent),       error('parent must be a handle');      end
  if ~isstruct( sample_data),  error('sample_data must be a struct'); end
  if ~isnumeric(vars),         error('vars must be a numeric');       end
  
  graphs = [];
  lines  = [];
    
  if length(vars) ~= 2
    warning('2 variables and only 2 need to be selected to graph');
    return; 
  end
  
  % get the toolbox execution mode
  mode = readProperty('toolbox.mode');
  
  switch mode
      case 'profile'
          % we don't want to plot TIME, PROFILE, DIRECTION, LATITUDE, LONGITUDE, BOT_DEPTH
          p = getVar(sample_data.variables, 'BOT_DEPTH');
      case 'timeSeries'
          % we don't want to plot TIMESERIES, PROFILE, TRAJECTORY, LATITUDE, LONGITUDE, NOMINAL_DEPTH
          p = getVar(sample_data.variables, 'NOMINAL_DEPTH');
  end
  vars = vars + p;
  
  if length(sample_data.variables{vars(1)}.dimensions) > 1 ...
  || length(sample_data.variables{vars(2)}.dimensions) > 1
    error('XvY only supports single dimensional data');
  end
  
  xname = sample_data.variables{vars(1)}.name;
  yname = sample_data.variables{vars(2)}.name;
  
  % create the axes
  graphs = axes('Parent', parent,...
      'XGrid',  'on',...
      'Color', 'none',...
      'YGrid',  'on', ...
      'ZGrid',  'on');
  
  % plot the variable
  plotFunc        = getGraphFunc('XvY', 'graph', xname);
  [lines, labels] = plotFunc(graphs, sample_data, vars);
  
  set(lines, 'Color', 'blue');
  
  % set x label
  uom = '';
  try      uom = [' (' imosParameters(labels{1}, 'uom') ')'];
  catch e, uom = '';
  end
  xLabel = [labels{1} uom];
  set(get(graphs, 'XLabel'), 'String', xLabel, 'Interpreter', 'none');
  
  % set y label for the first plot
  try      uom = [' (' imosParameters(labels{2}, 'uom') ')'];
  catch e, uom = '';
  end
  yLabel = [labels{2} uom];
  if length(yLabel) > 20, yLabel = [yLabel(1:17) '...']; end
  set(get(graphs, 'YLabel'), 'String', yLabel, 'Interpreter', 'none');
  
  if sample_data.meta.level == 1 && strcmp(func2str(plotFunc), 'graphXvYGeneric')
      qcSet     = str2double(readProperty('toolbox.qc_set'));
      goodFlag  = imosQCFlag('good',          qcSet, 'flag');
      pGoodFlag = imosQCFlag('probablyGood',  qcSet, 'flag');
      rawFlag   = imosQCFlag('raw',           qcSet, 'flag');
        
      % set x and y limits so that axis are optimised for good/probably good/raw data only
      curDataX = sample_data.variables{vars(1)}.data;
      curDataY = sample_data.variables{vars(2)}.data;
      curFlagX = sample_data.variables{vars(1)}.flags;
      curFlagY = sample_data.variables{vars(2)}.flags;
      
      curFlag = max(curFlagX, curFlagY);
      iGood = (curFlag == goodFlag) | (curFlag == pGoodFlag) | (curFlag == rawFlag);
      
      yLimits = [floor(min(curDataY(iGood))*10)/10, ceil(max(curDataY(iGood))*10)/10];
      xLimits = [floor(min(curDataX(iGood))*10)/10, ceil(max(curDataX(iGood))*10)/10];
      
      %check for xLimits max=min
      if diff(xLimits)==0;
          if xLimits(1) == 0
              xLimits = [-1, 1];
          else
              eps=0.01*xLimits(1);
              xLimits=[xLimits(1)-eps, xLimits(1)+eps];
          end
      end
      
      %check for yLimits max=min
      if diff(yLimits)==0;
          if yLimits(1) == 0
              yLimits = [-1, 1];
          else
              eps=0.01*yLimits(1);
              yLimits=[yLimits(1)-eps, yLimits(1)+eps];
          end
      end
      
      if any(iGood)
          set(graphs, 'YLim', yLimits);
          set(graphs, 'XLim', xLimits);
      end
  end

end
