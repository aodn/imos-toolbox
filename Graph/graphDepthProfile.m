function [graphs, lines, vars] = graphDepthProfile( parent, sample_data, vars, extra_sample_data )
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
%   vars               - Indices of variables that should be graphed.
%   extra_sample_data  - struct containing extra sample data.
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
  narginchk(4,4);
  
  if ~ishandle( parent),                error('parent must be a handle');                       end
  if ~isstruct( sample_data),           error('sample_data must be a struct');                  end
  if ~isnumeric(vars),                  error('vars must be a numeric');                        end
  if ~isstruct(extra_sample_data) && ...
          ~isempty(extra_sample_data),  error('extra_sample_data must be a struct or empty');   end
  
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
  
  yLimits = [NaN, NaN];
  for k = 1:length(vars)
    
    name = sample_data.variables{vars(k)}.name;
    
    iExtraVar = 0;
    if ~isempty(extra_sample_data)
        iExtraVar = getVar(extra_sample_data.variables, name);
        iExtraDepth = getVar(extra_sample_data.variables, 'DEPTH');
        if iExtraDepth == 0
            iExtraDepth = getVar(extra_sample_data.dimensions, 'DEPTH');
            extraDepth = extra_sample_data.dimensions{iExtraDepth}.data;
        else
            extraDepth = extra_sample_data.variables{iExtraDepth}.data;
        end
    end
    
    % create the axes; the subplots are laid out horizontally
    graphs(k) = subplot(1, length(vars), k);
    
    set(graphs(k), 'Parent', parent,...
                   'XGrid',  'on',...
                   'Color', 'none',...
                   'YGrid',  'on');
    
    % plot the variable
    plotFunc             = getGraphFunc('DepthProfile', 'graph', name);
    if iExtraVar
        if extra_sample_data.meta.level == 1
            qcSet     = str2double(readProperty('toolbox.qc_set'));
            goodFlag  = imosQCFlag('good',          qcSet, 'flag');
            pGoodFlag = imosQCFlag('probablyGood',  qcSet, 'flag');
            rawFlag   = imosQCFlag('raw',           qcSet, 'flag');
            
            iGoodExtra = (extra_sample_data.variables{iExtraVar}.flags == goodFlag) | ...
                (extra_sample_data.variables{iExtraVar}.flags == pGoodFlag) | ...
                (extra_sample_data.variables{iExtraVar}.flags == rawFlag);
            extra_sample_data.variables{iExtraVar}.data(~iGoodExtra) = NaN;
        end
        plotFunc(graphs(k), extra_sample_data, iExtraVar, 'k'); % extra instrument is always plotted in black
    end
    % we plot the current instrument last so that it appears on top
    [lines(k,:), labels] = plotFunc(graphs(k), sample_data, vars(k), 'b'); % current instrument is always plotted in blue
    
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
    
    curData  = sample_data.variables{vars(k)}.data;
    curDepth = depth.data;
    
    [nSamples, nBins] = size(curData);
    if strcmpi(mode, 'timeSeries') && nBins > 1
        % ADCP data, we look for vertical dimension
        iVertDim = sample_data.variables{vars(k)}.dimensions(2);
        curDepth = repmat(curDepth, 1, nBins) - repmat(sample_data.dimensions{iVertDim}.data', nSamples, 1);
    end
    
    if iExtraVar
        curData  = [curData(:);  extra_sample_data.variables{iExtraVar}.data(:)];
        
        [nSamples, nBins] = size(extra_sample_data.variables{iExtraVar}.data);
        if strcmpi(mode, 'timeSeries') && nBins > 1
            % ADCP data, we look for vertical dimension
            iVertDim = extra_sample_data.variables{iExtraVar}.dimensions(2);
            extraDepth = repmat(extraDepth, 1, nBins) - repmat(extra_sample_data.dimensions{iVertDim}.data', nSamples, 1);
        end
        curDepth = [curDepth(:); extraDepth(:)];
    end
        
    iGood = curDepth >= 0;
    
    if sample_data.meta.level == 1 && strcmp(func2str(plotFunc), 'graphDepthProfileGeneric')
        qcSet     = str2double(readProperty('toolbox.qc_set'));
        goodFlag  = imosQCFlag('good',          qcSet, 'flag');
        pGoodFlag = imosQCFlag('probablyGood',  qcSet, 'flag');
        rawFlag   = imosQCFlag('raw',           qcSet, 'flag');
                
        % set x and y limits so that axis are optimised for good/probably good/raw data only
        curFlag  = sample_data.variables{vars(k)}.flags;
        if iExtraVar
            curFlag  = [curFlag(:);  extra_sample_data.variables{iExtraVar}.flags(:)];
        end
        
        if strcmpi(mode, 'timeSeries')
            iGood = (curFlag == goodFlag) | (curFlag == pGoodFlag) | (curFlag == rawFlag);
        end
    end
    
    yLimits = [min(floor(min(curDepth(iGood))*10)/10, yLimits(1)), max(ceil(max(curDepth(iGood))*10)/10, yLimits(2))];
    xLimits = [floor(min(curData(iGood))*10)/10,  ceil(max(curData(iGood))*10)/10];
    
    %check for my surface soak flags - and set xLimits to flag range
    if ismember(name, {'tempSoakStatus', 'cndSoakStatus', 'oxSoakStatus'})
        xLimits = [min(imosQCFlag('flag', qcSet, 'values')) max(imosQCFlag('flag', qcSet, 'values'))];
    end
    
    %check for xLimits max=min
    if diff(xLimits) == 0;
        if xLimits(1) == 0
            xLimits = [-1, 1];
        else
            eps = 0.01 * xLimits(1);
            xLimits = [xLimits(1) - eps, xLimits(1) + eps];
        end
    end
    
    set(graphs(k), 'XLim', xLimits);
  end
  
  % update all graphs with greater Y range found over each variable
  yStep   = (yLimits(2) - yLimits(1)) / 5;
  yTicks  = yLimits(1):yStep:yLimits(2);
  set(graphs, 'YLim', yLimits, 'YTick', yTicks);
end
