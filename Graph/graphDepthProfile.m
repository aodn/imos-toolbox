function [graphs lines vars] = graphDepthProfile( parent, sample_data, vars )
%GRAPHDEPTHPROFILE Graphs the given data in a depth profile style using 
% subplots.
%
% This function is useful for viewing CTD data, or any data which has
% either a depth dimension or a depth variable. Depth is plotted on the Y
% axis, and each other parameter is plotted against depth on the X axis.
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
    
  if isempty(vars)
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
  
  % make sure the data set contains depth 
  % data, either a dimension or a variable
  depth = getVar(sample_data.variables, 'DEPTH');
    
  if depth ~= 0
    % we don't want to plot depth against itself, so if depth has been
    % passed in as one of the variables to plot, remove it from the list
    iAfterDepth = vars >= depth;
    if any(iAfterDepth)
      vars(iAfterDepth) = vars(iAfterDepth)+1;
      iOutnumber = vars > length(sample_data.variables);
      if any(iOutnumber)
          vars(iOutnumber) = [];
          if isempty(vars)
              warning('no variables to graph');
              return;
          end
      end
    end
    
    depth = sample_data.variables{depth};
  else
    
    depth = getVar(sample_data.dimensions, 'DEPTH');
    
    if depth == 0, error('data set contains no depth data'); end
    
    remove = [];
    
    % if depth is a dimension, we can only plot those variables 
    % which provide data along the depth dimension
    for k = 1:length(vars)
        iDepth = sample_data.variables{vars(k)}.dimensions == depth;
      if ~any(iDepth)
        remove(end+1) = vars(k);
      end  
    end
    
    vars = setdiff(vars, remove);
    if isempty(vars)
      warning('no variables to graph');
      return; 
    end
    
    depth = sample_data.dimensions{depth};
  end
  
  for k = 1:length(vars)
    
    name = sample_data.variables{vars(k)}.name;
    
    % create the axes; the subplots are laid out horizontally
    graphs(k) = subplot(1, length(vars), k);
    
    set(graphs(k), 'Parent', parent,...
                   'XGrid',  'on',...
                   'Color', 'none',...
                   'YGrid',  'on');
    
    % make sure line colour alternate; because we are creating 
    % multiple axes, this is not done automatically for us
    col = get(graphs(k), 'ColorOrder');
    col = col(mod(k, length(col))+1, :);
    
    % plot the variable
    plotFunc            = getGraphFunc('DepthProfile', 'graph', name);
    [lines(k,:) labels] = plotFunc(   graphs(k), sample_data, vars(k));
    
    % set the line colour - wrap in a try block, 
    % as surface plot colour cannot be set
    try set(lines(k,:), 'Color', col);
    catch e
    end
    
    % set x label
    uom = '';
    try      uom = [' (' imosParameters(labels{1}, 'uom') ')'];
    catch e, uom = '';
    end
    xLabel = [labels{1} uom];
    set(get(graphs(k), 'XLabel'), 'String', xLabel, 'Interpreter', 'none');

    % set y label for the first plot
    if k==1
        try      uom = [' (' imosParameters(labels{2}, 'uom') ')'];
        catch e, uom = '';
        end
        yLabel = [labels{2} uom];
        if length(yLabel) > 20, yLabel = [yLabel(1:17) '...']; end
        set(get(graphs(k), 'YLabel'), 'String', yLabel, 'Interpreter', 'none');
    end
    
    if sample_data.meta.level == 1 && strcmp(func2str(plotFunc), 'graphDepthProfileGeneric')
        qcSet     = str2double(readProperty('toolbox.qc_set'));
        
        % set x and y limits so that axis are optimised for data below surface only
        curData = sample_data.variables{vars(k)}.data;
        curDepth = depth.data;
        curFlag = sample_data.variables{vars(k)}.flags;
        iGood = curDepth>=0;

        yLimits = [floor(min(curDepth(iGood))), ceil(max(curDepth(iGood)))];
        xLimits = [floor(min(curData(iGood))),  ceil(max(curData(iGood)))];
        
        %check for my surface soak flags - and set xLimits to flag range
        if ismember(name,{'tempSoakStatus','cndSoakStatus','oxSoakStatus'})
            xLimits=[min(imosQCFlag('flag',qcSet,'values')) max(imosQCFlag('flag',qcSet,'values'))];
        end
        
        %check for xLimits max=min
        if diff(xLimits)==0;
            if xLimits(1) == 0
                xLimits = [-1, 1];
            else
                eps=0.01*xLimits(1);
                xLimits=[xLimits(1)-eps, xLimits(1)+eps];
            end
        end
        
        if any(iGood)
            set(graphs(k), 'YLim', yLimits);
            set(graphs(k), 'XLim', xLimits);
        end
    end
    
    yLimits = get(graphs(k), 'YLim');
    yStep   = (yLimits(2) - yLimits(1)) / 5;
    yTicks  = yLimits(1):yStep:yLimits(2);
    set(graphs(k), 'YTick', yTicks);
    
  end
  
    % GLT : Eventually I prefered not displaying the QC legend as it
    % influences too badly the quality of the plots. I didn't manage to have
    % a satisfying result with a ghost axis hosting the legend... So for now
    % I added the possiblity to the user to right-click on a QC'd data point
    % and it displays the description of the color flag.
    % compile variable names for the legend
%   names = {};
%   for k = 1:length(vars)
%     
%     names{k} = sample_data.variables{vars(k)}.name;
%   end
%   
%   % link axes for panning/zooming, and add a legend - matlab has a habit of
%   % throwing 'Invalid handle object' errors for no apparent reason (i think 
%   % when the user changes selections too quickly, matlab is too slow, and 
%   % ends up confusing itself), so absorb any errors which are thrown
%   try
%     linkaxes(graphs, 'y');
%     
%     % When adding a single legend for multiple subplots, by default the legend 
%     % is added to the axis which corresponds to the first handle in the vector 
%     % that is passed in ('lines' in this case). This is a problem in our case, 
%     % because it means that the legend will be added to the left most axis, 
%     % whereas we want it to be added to the right-most axis. To get around 
%     % this, I'm reversing the order of the line handles (and names) before 
%     % passing them to the legend function.
%     legend(flipud(lines(:,1)), fliplr(names));
%   catch e
%   end
end
