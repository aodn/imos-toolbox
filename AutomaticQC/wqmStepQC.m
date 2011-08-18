function [data, flags, log] = wqmStepQC( sample_data, data, k, auto )
%WQMSTEP Flags consecutive equal values after an important change (WQM steps).
%
% Step test which finds and flags any consecutive data that are part of the
% most important mode below/above (mode 1 -/+ 3*std_dev) in the statistical 
% distribution
%
% Inputs:
%   sample_data - struct containing the data set.
%
%   data        - the vector of data to check.
%
%   k           - Index into the sample_data variable vector.
%
%   auto        - logical, run QC in batch mode
%
% Outputs:
%   data        - same as input.
%
%   flags       - Vector the same length as data, with flags for flatline 
%                 regions.
%
%   log         - Empty cell array.
%
% Author:       Guillaume Galibert <guillaume.galibert@utas.edu.au>
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

error(nargchk(3, 4, nargin));
if ~isstruct(sample_data),        error('sample_data must be a struct'); end
if ~isvector(data),               error('data must be a vector');        end
if ~isscalar(k) || ~isnumeric(k), error('k must be a numeric scalar');   end

% auto logical in input to enable running under batch processing
if nargin<4, auto=false; end

qcSet    = str2double(readProperty('toolbox.qc_set'));
rawFlag = imosQCFlag('raw',  qcSet, 'flag');
goodFlag = imosQCFlag('good',  qcSet, 'flag');
stepFlag = imosQCFlag('spike', qcSet, 'flag');

lenData = length(data);

log   = {};

% initially all data is good
flags = ones(lenData, 1)*goodFlag;

% let's create a statistical distribution of our signal
edges = (min(data) : (max(data)-min(data))/99 : max(data));
n = histc(data, edges);

% let's find values for which we have local max/min in the distribution
diffN = diff(n);
posSign = diffN > 0;
negSign = diffN < 0;
nulSign = diffN == 0;

% sign change from pos to neg
localMax = posSign(1:end-1) & negSign(2:end);

% sign change from pos to nul
localMax = localMax | (posSign(1:end-1) & nulSign(2:end));

% max could also be present at the edges of distribution
if negSign(1)
    localMax = [true; localMax];
else
    localMax = [false; localMax];
end

if posSign(end)
    localMax = [localMax; true];
else
    localMax = [localMax; false];
end

% sign change from neg to pos
localMin = negSign(1:end-1) & posSign(2:end);

% sign change from neg to nul
localMin = localMin | (negSign(1:end-1) & nulSign(2:end));

% min could also be present at the edges of distribution
if posSign(1)
    localMin = [true; localMin];
else
    localMin = [false; localMin];
end

if negSign(end)
    localMin = [localMin; true];
else
    localMin = [localMin; false];
end

% mode 1
nMax = n(localMax);
nMin = n(localMin);
edgesMax = edges(localMax);
edgesMin = edges(localMin);
iNMax = nMax == max(nMax);

mod1 = edgesMax(iNMax);

% look for first mode with value < mode 1 - 3*standard_deviation
edgesMax(iNMax)    = [];
nMax(iNMax)        = [];
stdDev = std(data);
test = false;
modN = NaN;
nearestLocalMin = NaN;
while ~isempty(nMax) && ~test
    iNMax = nMax == max(nMax);
    
    if sum(iNMax) > 1
        modN = max(edgesMax(iNMax));
        iNMax = edgesMax == modN;
    else
        modN = edgesMax(iNMax);
    end
       
    edgesMax(iNMax)    = [];
    nMax(iNMax)        = [];
    
    % test
    test = (modN < mod1 - 3*stdDev);
    if test
        % let's find the nearest > local min
        nearestLocalMin = min(edgesMin(modN < edgesMin));
        iToFlag = data < nearestLocalMin;
        flags(iToFlag) = stepFlag;
    end
end

% plot to see what's going on
% h_gcf = gcf;
% h_gca = gca;
% hf = figure('name', strrep(sample_data.variables{k}.name, '_', ' '));
% ha = axes('Parent',hf);
% bar(ha, edges, n,'BarWidth',1);
% xLabel = [strrep(sample_data.variables{k}.long_name, '_', ' ') ' (' sample_data.variables{k}.units ')'];
% yLabel = 'counts';
% set(get(ha, 'XLabel'), 'String', xLabel);
% set(get(ha, 'YLabel'), 'String', yLabel);
% 
% yCoord = get(ha, 'YLim');
% xCoordMod1 = [mod1, mod1];
% hMod1 = line('XData', xCoordMod1, 'YData', yCoord, 'Parent', ha, 'Color', 'green');
% 
% xCoordModN = [modN, modN];
% hModN = line('XData', xCoordModN, 'YData', yCoord, 'Parent', ha, 'Color', 'red');
% 
% xCoord3StdDevM = [mod1-3*stdDev, mod1-3*stdDev];
% h3StdDevM = line('XData', xCoord3StdDevM, 'YData', yCoord, 'Parent', ha, 'Color', 'red', 'LineStyle', '-.');
% 
% xCoordLocalMin = [nearestLocalMin, nearestLocalMin];
% hLocalMin = line('XData', xCoordLocalMin, 'YData', yCoord, 'Parent', ha, 'Color', 'magenta', 'LineStyle', '--');
% 
% legend(ha, [hMod1, hModN, h3StdDevM, hLocalMin], {'mode 1', 'first mode N < test', 'test = mode 1 - 3*std. dev.', 'nearest local min from mode N'}, 'Location', 'NorthWest');
% set(0, 'CurrentFigure', h_gcf);
% set(h_gcf, 'CurrentAxes', h_gca);