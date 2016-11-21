function [h labels] = graphTimeSeriesTimeFrequency( ax, sample_data, var, color, xTickProp )
%GRAPHTIMESERIESTIMEFREQUENCY Plots the given data using pcolor.
%
% This function is used for plotting time/frequency data. The pcolor function 
% is  used to display a 2-D color plot, with time on the X axis and frequency 
% on the Y axis, and the data indicated indicated by the colour.
%
% Inputs:
%   ax          - Parent axis.
%   sample_data - The data set.
%   var         - The variable to plot.
%   color       - Not used here.
%   xTickProp   - XTick and XTickLabel properties.
%
% Outputs:
%   h           - Handle to the surface which was plotted.
%   labels      - Cell array containing x/y labels to use.
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
narginchk(5, 5);

if ~ishandle(ax),          error('ax must be a graphics handle'); end
if ~isstruct(sample_data), error('sample_data must be a struct'); end
if ~isnumeric(var),        error('var must be a numeric');        end

iTimeDim = getVar(sample_data.dimensions, 'TIME');
freq = sample_data.variables{var}.dimensions(2);

time = sample_data.dimensions{iTimeDim};
freq = sample_data.dimensions{freq};
var  = sample_data.variables {var};

xPcolor = time.data;
yPcolor = freq.data;

% we actually want each square of the surface plot to be centred on its
% coordinates
% xPcolor = [time.data(1:end-1) - diff(time.data)/2; time.data(end) - (time.data(end)-time.data(end-1))/2];
% yPcolor = [freq.data(1:end-1) - diff(freq.data)/2; freq.data(end) - (freq.data(end)-freq.data(end-1))/2];

h = pcolor(ax, double(xPcolor), double(yPcolor), double(var.data'));
set(h, 'FaceColor', 'flat', 'EdgeColor', 'none');
cb = colorbar();

% Attach the context menu to colorbar
hMenu = setTimeSerieColorbarContextMenu(var);
set(cb,'uicontextmenu',hMenu);

% Let's redefine properties after pcolor to make sure grid lines appear
% above color data and XTick and XTickLabel haven't changed
set(ax, 'XTick',        xTickProp.ticks, ...
        'XTickLabel',   xTickProp.labels, ...
        'XGrid',        'on', ...
        'YGrid',        'on', ...
        'Layer',        'top', ...
        'Tag',          'axis2D');

cbLabel = imosParameters(var.name, 'uom');
cbLabel = [var.name ' (' cbLabel ')'];
if length(cbLabel) > 20, cbLabel = [cbLabel(1:17) '...']; end
set(get(cb, 'YLabel'), 'String', cbLabel, 'Interpreter', 'none');

% set background to be grey
set(ax, 'Color', [0.75 0.75 0.75])

labels = {time.name, freq.name};

end