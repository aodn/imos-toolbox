function [h labels] = graphTimeSeriesGeneric( ax, sample_data, var )
%GRAPHTIMESERIESGENERIC Plots the given variable as normal, single dimensional, 
% time series data. If the data are multi-dimensional, multiple lines will be
% plotted and returned.
%
% Inputs:
%   ax          - Parent axis.
%   sample_data - The data set.
%   var         - The variable to plot.
%
% Outputs:
%   h           - Handle(s) to the line(s)  which was/were plotted.
%   labels      - Cell array containing x/y labels to use.
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

if ~ishandle(ax),          error('ax must be a graphics handle'); end
if ~isstruct(sample_data), error('sample_data must be a struct'); end
if ~isnumeric(var),        error('var must be a numeric');        end

time = getVar(sample_data.dimensions, 'TIME');
time = sample_data.dimensions{time};
var  = sample_data.variables {var};

h    = line(time.data, var.data, 'Parent', ax);
set(ax, 'Tag', 'axis1D');

% test for climatology display
% mWh = findobj('Tag', 'mainWindow');
% morelloRange = get(mWh, 'UserData');
% if strcmpi(var.name, 'TEMP') && ~isempty(morelloRange)
%     hRMinT = line(time.data, morelloRange.rangeMinT, 'Parent', ax);
%     hRMaxT = line(time.data, morelloRange.rangeMaxT, 'Parent', ax);
%     set(hRMinT, 'Color', 'r');
%     set(hRMaxT, 'Color', 'r');
%     set(ax, 'YLim', [min(morelloRange.rangeMinT), max(morelloRange.rangeMaxT)]);
% elseif strcmpi(var.name, 'PSAL') && ~isempty(morelloRange)
%     hRMinS = line(time.data, morelloRange.rangeMinS, 'Parent', ax);
%     hRMaxS = line(time.data, morelloRange.rangeMaxS, 'Parent', ax);
%     set(hRMinS, 'Color', 'r');
%     set(hRMaxS, 'Color', 'r');
%     set(ax, 'YLim', [min(morelloRange.rangeMinS), max(morelloRange.rangeMaxS)]);
% elseif strcmpi(var.name, 'DOX2') && ~isempty(morelloRange)
%     hRMinS = line(time.data, morelloRange.rangeMinDO, 'Parent', ax);
%     hRMaxS = line(time.data, morelloRange.rangeMaxDO, 'Parent', ax);
%     set(hRMinS, 'Color', 'r');
%     set(hRMaxS, 'Color', 'r');
%     set(ax, 'YLim', [min(morelloRange.rangeMinDO), max(morelloRange.rangeMaxDO)]);
% end

% Set axis position so that 1D data and 2D data vertically matches on X axis
cb = colorbar();
pos_with_colorbar = get(ax, 'Position');
colorbar(cb, 'off');
set(ax, 'Position', pos_with_colorbar);

if strncmp(var.name, 'DEPTH', 4)
    set(ax, 'YDir', 'reverse');
end

labels = {'TIME', var.name};
