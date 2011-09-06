function [graphs lines vars] = graphTimeSeries( parent, sample_data, vars )
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
%   vars               - Indices of variables which were graphed.
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
  error(nargchk(3,3,nargin));
  
  if ~ishandle( parent),       error('parent must be a handle');      end
  if ~isstruct( sample_data),  error('sample_data must be a struct'); end
  if ~isnumeric(vars),         error('vars must be a numeric');       end
    
  if isempty(vars)
    warning('no variables to graph');
    return; 
  end
  
  % get rid of variables that we should ignore
  sample_data.variables = sample_data.variables(vars);
  lenVar = length(sample_data.variables);
  
  graphs = nan(lenVar, 1);
  lines = nan(lenVar, 1);
  distinctFlagsValue = [];
  
  for k = 1:lenVar
    
    name = sample_data.variables{k}.name;
    distinctFlagsValue = union(distinctFlagsValue, unique(sample_data.variables{k}.flags));
    
    % create the axes
    graphs(k) = subplot(lenVar, 1, k);
    
    set(graphs(k), 'Parent', parent,...
                   'XGrid',  'on',...
                   'Color', 'none',...
                   'YGrid',  'on',...
                   'Layer', 'top');
    
    % plot the variable
    plotFunc            = getGraphFunc('TimeSeries', 'graph', name);
    [lines(k,:) labels] = plotFunc(   graphs(k), sample_data, k);
    
    % make sure line colour alternate; because we are creating 
    % multiple axes, this is not done automatically for us
    col = get(graphs(k), 'ColorOrder');
    col = col(mod(vars(k),length(col))+1,:);
    
    % set the line colour - wrap in a try block, 
    % as surface plot colour cannot be set
    try 
        set(lines(k,:), 'Color', col);
    catch e
    end
    
    % set x labels and ticks
    set(get(graphs(k), 'XLabel'), 'String', labels{1});

    % align xticks on first plot's xticks
    xLimits = get(graphs(1), 'XLim');
    xStep   = (xLimits(2) - xLimits(1)) / 5;
    xTicks  = xLimits(1):xStep:xLimits(2);
    set(graphs(k), 'XTick', xTicks);
    
    % tranformation of datenum xticks in datestr
    datetick('x', 'dd-mm-yy HH:MM', 'keepticks');

    % set y label and ticks
    try      uom = [' (' imosParameters(labels{2}, 'uom') ')'];
    catch e, uom = '';
    end
    yLabel = [labels{2} uom];
    if length(yLabel) > 20, yLabel = [yLabel(1:17) '...']; end
    set(get(graphs(k), 'YLabel'), 'String', strrep(yLabel, '_', ' '));
    
    if sample_data.meta.level == 1 && strcmp(func2str(plotFunc), 'graphTimeSeriesGeneric')
        qcSet     = str2double(readProperty('toolbox.qc_set'));
        goodFlag  = imosQCFlag('good',  qcSet, 'flag');
        
        % set y limits so that only good data are visible
        curData = sample_data.variables{k}.data;
        curFlag = sample_data.variables{k}.flags;
        iGood = curFlag == goodFlag;
        yLimits = [floor(min(curData(iGood))), ceil(max(curData(iGood)))];
        if any(iGood)
            set(graphs(k), 'YLim', yLimits);
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
%   if sample_data.meta.level == 1
%       % Let's add a QC legend
%       qcSet     = str2double(readProperty('toolbox.qc_set'));
%       rawFlag  = imosQCFlag('raw',  qcSet, 'flag');
%       distinctFlagsValue(distinctFlagsValue == rawFlag) = [];
%       lenFlagsValue = length(distinctFlagsValue);
%       distinctFlagName = cell(lenFlagsValue, 1);
%       distinctFlag = nan(lenFlagsValue, 1);
%       for i=1:length(distinctFlagsValue)
%           distinctFlagName{i} = strrep(imosQCFlag(distinctFlagsValue(i),  qcSet, 'desc'), '_', ' ');
%           distinctFlagColor = imosQCFlag(distinctFlagsValue(i),  qcSet, 'color');
%           distinctFlag(i) = line(0, 0,...
%               'Parent', graphs(1),...
%               'LineStyle', 'none',...
%               'Marker', 'o',...
%               'MarkerFaceColor', distinctFlagColor,...
%               'MarkerEdgeColor', 'none',...
%               'Visible', 'off');
%       end
%       
%       % link axes for panning/zooming, and add a legend - matlab has a habit of
%       % throwing 'Invalid handle object' errors for no apparent reason (i think
%       % when the user changes selections too quickly, matlab is too slow, and
%       % ends up confusing itself), so absorb any errors which are thrown
%       try
%           linkaxes(graphs, 'x');
%           for k = 2:lenVar
%               % Let's make different X axes match with the first one
%               xLimits = get(graphs(1), 'XLim');
%               set(graphs(k), 'XLim', xLimits);
%           end
%       catch e
%       end
%   end
  
  % GLT : I prefer not adding a legend for variables as it overlaps the figure
  % and in addition the different axis and plots labels are already detailed enough.
%   % compile variable names for the legend
%   names = {};
%   for k = 1:lenVar
%     names{k} = strrep(sample_data.variables{k}.name, '_', ' ');
%   end
%   
%   % link axes for panning/zooming, and add a legend - matlab has a habit of
%   % throwing 'Invalid handle object' errors for no apparent reason (i think 
%   % when the user changes selections too quickly, matlab is too slow, and 
%   % ends up confusing itself), so absorb any errors which are thrown
%   try 
%     linkaxes(graphs, 'x');
%     legend(lines(:,1), names);
%   catch e
%   end
end
