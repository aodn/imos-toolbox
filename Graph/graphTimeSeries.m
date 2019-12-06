function [graphs, lines, vars] = graphTimeSeries( parent, sample_data, vars, extra_sample_data )
%GRAPHTIMESERIES Graphs the given data in a time series style using subplots.
%
% Graphs the selected variables from the given data set. Each variable is
% graphed by looking up the respective 'graphXY.m' function, where X is the
% IMOS name of the variable (e.g. TEMP, CDIR).
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
  narginchk(4,4);
  
  if ~ishandle(parent),                 error('parent must be a handle');                       end
  if ~isstruct(sample_data),            error('sample_data must be a struct');                  end
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
  
  % get rid of variables that we should ignore
  sample_data.variables = sample_data.variables(vars);
  lenVar = length(sample_data.variables);
  
  if ~isempty(extra_sample_data)
      nInst = 2;
  else
      nInst = 1;
  end
      
  if verLessThan('matlab','8.1') %R2013a
      graphs = nan(lenVar, 1);
      lines  = nan(lenVar, nInst);
  else
      graphs = gobjects(lenVar, 1);
      lines  = gobjects(lenVar, nInst);
  end
  
  iTimeDim = getVar(sample_data.dimensions, 'TIME');
  dataTime = sample_data.dimensions{iTimeDim}.data;
  
  if sample_data.meta.level == 1
      qcSet     = str2double(readProperty('toolbox.qc_set'));
      goodFlag  = imosQCFlag('good',          qcSet, 'flag');
      pGoodFlag = imosQCFlag('probablyGood',  qcSet, 'flag');
      rawFlag   = imosQCFlag('raw',           qcSet, 'flag');
      
      dimFlags = sample_data.dimensions{iTimeDim}.flags;
      iGood = (dimFlags == goodFlag) | (dimFlags == pGoodFlag) | (dimFlags == rawFlag);
      dataTime = dataTime(iGood);
  end
  xLimits = [min(dataTime), max(dataTime)];
  xStep   = (xLimits(2) - xLimits(1)) / 5;
  xTicks  = xLimits(1):xStep:xLimits(2);
  xTickLabels = datestr(xTicks, 'dd-mm-yy HH:MM');
  xTickProp.ticks = xTicks;
  xTickProp.labels = xTickLabels;
    
  for k = 1:lenVar
    
    name = sample_data.variables{k}.name;
    dims = sample_data.variables{k}.dimensions;
    
    iExtraVar = 0;
    if ~isempty(extra_sample_data)
        iExtraVar = getVar(extra_sample_data.variables, name);
    end
    
    if length(dims) == 1
        % 1D display
        plotFunc = @graphTimeSeriesGeneric;
    else
        % 1D or 2D display
        plotFunc = getGraphFunc('TimeSeries', 'graph', name);
    end
    switch func2str(plotFunc)
        case 'graphTimeSeriesGeneric'
            varData = sample_data.variables{k}.data;
            if iExtraVar
                varData = [varData; extra_sample_data.variables{iExtraVar}.data];
            end
            if ischar(varData), varData = str2num(varData); end % we assume data is an array of one single character
            
            if sample_data.meta.level == 1
                % set x and y limits so that axis are optimised for good/probably good/raw data only
                varFlags = sample_data.variables{k}.flags;
                dimFlags = sample_data.dimensions{iTimeDim}.flags;
                if iExtraVar
                    varFlags = [varFlags; extra_sample_data.variables{iExtraVar}.flags];
                    dimFlags = [dimFlags; extra_sample_data.dimensions{getVar(extra_sample_data.dimensions, 'TIME')}.flags];
                end
                iGood = (varFlags == goodFlag) | (varFlags == pGoodFlag) | (varFlags == rawFlag);
                iGood = iGood & ((dimFlags == goodFlag) | (dimFlags == pGoodFlag) | (dimFlags == rawFlag));
                if any(iGood)
                    varData = varData(iGood);
                    if ischar(varData), varData = str2num(varData); end % we assume data is an array of one single character
                end
            end
            
            minData = min(varData);
            maxData = max(varData);
            yLimits = [floor(minData*10)/10, ceil(maxData*10)/10];
                    
        case 'graphTimeSeriesTimeDepth'
            iZDim = sample_data.variables{k}.dimensions(2);
            yLimits = [floor(min(sample_data.dimensions{iZDim}.data)*10)/10, ...
                ceil(max(sample_data.dimensions{iZDim}.data)*10)/10];
            
        case 'graphTimeSeriesTimeFrequency'
            iFDim = sample_data.variables{k}.dimensions(2);
            yLimits = [floor(min(sample_data.dimensions{iFDim}.data)*10)/10, ...
                ceil(max(sample_data.dimensions{iFDim}.data)*10)/10];
            
        case 'graphTimeSeriesTimeFrequencyDirection'
            yLimits = [-1, 1];
            xLimits = [-1, 1];
            
    end
    
    if xLimits(2) == xLimits(1)
        % XLim values must be increasing.
        xLimits(1) = xLimits(1) - 1;
        xLimits(2) = xLimits(2) + 1;
    end
    
    if yLimits(2) == yLimits(1)
        % YLim values must be increasing.
        yLimits(1) = yLimits(1) - 1;
        yLimits(2) = yLimits(2) + 1;
    end
    
    yStep   = (yLimits(2) - yLimits(1)) / 5;
    yTicks  = yLimits(1):yStep:yLimits(2);
    
    % create the axes
    graphs(k) = subplot(lenVar, 1, k, ...
        'Parent',       parent, ...
        'XGrid',        'on', ...
        'Color',        'none', ...
        'YGrid',        'on', ...
        'Layer',        'top', ...
        'XLim',         xLimits, ...
        'XTick',        xTicks, ...
        'XTickLabel',   xTickLabels, ...
        'YLim',         yLimits, ...
        'YTick',        yTicks);
               
    % plot the variable
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
        [lines(k,2), ~] = plotFunc(graphs(k), extra_sample_data, iExtraVar, 'k', xTickProp); % extra instrument is always plotted in black
    end
    % we plot the current instrument last so that it appears on top
    [lines(k,1), labels] = plotFunc(graphs(k), sample_data, k, 'b', xTickProp); % current instrument is always plotted in blue
    
    if ~isempty(labels)
        % set x labels and ticks
        xlabel(graphs(k), labels{1});
        
        % set y label and ticks
        try      uom = ['(' imosParameters(labels{2}, 'uom') ')'];
        catch e, uom = '';
        end
        
        % decide where to cut the Y label to display it on 1 or 2 lines 
        % depending on the number of words obtained from the variable name
        yLabel = regexp(labels{2}, '\_', 'split');
        if numel(yLabel) < 4
            nthWordToCut = min(2, numel(yLabel));
        elseif numel(yLabel) < 6
            nthWordToCut = 3;
        else
            nthWordToCut = 4;
        end
        yLabel = {strjoin(yLabel(1:nthWordToCut),     ' '), ...
                  strjoin(yLabel(nthWordToCut+1:end), ' ')};
        yLabel = yLabel(~cellfun(@isempty, yLabel));
        
        yLabel{end+1} = strrep(uom, '_', ' ');
        iLength = 12; % arbitrary string cutoff length
        %iLong = strlength(yLabel) > iLength; % only R2016b onwards
        iLong = cellfun(@length, yLabel) > iLength;
        yLabel(iLong) = cellfun(@(x) [x(1:iLength) '...'], yLabel(iLong), 'UniformOutput', false);
        ylabel(graphs(k), yLabel);
    end
  end

    function str = strjoin(strCell, sep)
        %STRJOIN Join strings in a cell array.
        % http://stackoverflow.com/questions/5292437/how-can-i-concatenate-strings-in-a-cell-array-with-spaces-between-them-in-matlab
        % R2012b onwards
        nCells = numel(strCell);
        strCell(1:nCells-1) = strcat(strCell(1:nCells-1), {sep});
        str = [strCell{:}];
    end
end