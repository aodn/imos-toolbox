function [h labels] = graphTimeSeriesTimeFrequencyDirection( ax, sample_data, var, color, xTickProp )
%GRAPHTIMESERIESTIMEFREQUENCYDIRECTION Plots the given data using pcolor.
%
% This function is used for plotting time/frequency/direction data for one 
% selected time value. The pcolor function is  used to display a 2-D color 
% polar plot, with frequency on the rho axis and direction on the theta
% axis. The data is indicated by the colour.
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
% Author:       Guillaume Galibert <guillaume.galibert@utas.edu.au>
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

[h, labels] = polarPcolor(ax, sample_data, var);

end

function [h, labels] = polarPcolor(ax, sample_data, var)

iTimeDim = getVar(sample_data.dimensions, 'TIME');
freq = sample_data.variables{var}.dimensions(2);
dir  = sample_data.variables{var}.dimensions(3);

timeData  = sample_data.dimensions{iTimeDim}.data;
dirData   = sample_data.dimensions{dir}.data;
freqData  = sample_data.dimensions{freq}.data;
sswvData  = sample_data.variables{var}.data;

varCheckbox = findobj('Tag', ['checkbox' sample_data.variables{var}.name]);
iTime = get(varCheckbox, 'userData');
if isempty(iTime)
    % we choose an arbitrary time to plot
    iTime = 1;
end

myVar = sample_data.variables{var};

nFreq = length(freqData);
nDir = length(dirData);
r = freqData/max(freqData);
theta = 2*pi*[dirData; dirData(end) + (dirData(end) - dirData(end-1))]/360; % we need to manually add the last angle value to complete the circle
theta = theta - (theta(2)-theta(1))/2; % we want to centre the angular beam on the actual angular value

X = nan(nDir+1, nFreq);
Y = nan(nDir+1, nFreq);
for i=1:nDir+1
    Y(i, :) = r*cos(theta(i)); % theta is positive clockwise from North
    X(i, :) = r*sin(theta(i));
end

h = pcolor(ax, double(X), double(Y), double([squeeze(sswvData(iTime, :, :)), sswvData(iTime, :, 1)']')); % we need to repeat the first values at the end
axis equal tight
shading flat
set(ax, ...
    'Color',    'none', ...
    'Visible',  'off');
clear sswvData

% get x-axis text color so grid is in same color
tc = get(ax, 'XColor');
ls = get(ax, 'GridLineStyle');

% make a radial grid
hold(ax, 'on');
hhh = line([-1, -1, 1, 1], [-1, 1, 1, -1], 'Parent', ax);
set(ax, 'DataAspectRatio', [1, 1, 1], 'PlotBoxAspectRatioMode', 'auto');
ticks = sum(get(ax, 'YTick') >= 0);
delete(hhh);
% check radial limits and ticks
rticks = max(ticks - 1, 2);
if rticks > 5   % see if we can reduce the number
    if rem(rticks, 2) == 0
        rticks = rticks / 2;
    elseif rem(rticks, 3) == 0
        rticks = rticks / 3;
    end
end

% define a circle
th = 0 : pi / 50 : 2 * pi;
xunit = sin(th);
yunit = cos(th);

% plot background if necessary
if ~ischar(get(ax, 'Color'))
    patch('XData', xunit, 'YData', yunit, ...
        'EdgeColor', tc, 'FaceColor', get(ax, 'Color'), ...
        'HandleVisibility', 'off', 'Parent', ax);
end

% draw radial circles
c82 = cos(82 * pi / 180);
s82 = sin(82 * pi / 180);
rinc = 1 / rticks;
for i = rinc : rinc : 1
    hhh = line(xunit * i, yunit * i, 'LineStyle', ls, 'Color', tc, 'LineWidth', 1, ...
        'HandleVisibility', 'off', 'Parent', ax);
    if i==1
        circleText = [num2str(interp1(r, freqData, i)) ' (Hz)'];
    else
        circleText = num2str(interp1(r, freqData, i));
    end
    text((i + rinc / 20) * c82, (i + rinc / 20) * s82, ...
        ['  ' circleText], 'VerticalAlignment', 'bottom', ...
        'HandleVisibility', 'off', 'Parent', ax);
end
set(hhh, 'LineStyle', '-'); % Make outer circle solid

% plot spokes
th = (1 : 6) * 2 * pi / 12;
cst = sin(th);
snt = cos(th);
cs = [-cst; cst];
sn = [-snt; snt];
line(cs, sn, 'LineStyle', ls, 'Color', tc, 'LineWidth', 1, ...
    'HandleVisibility', 'off', 'Parent', ax);

% annotate spokes in degrees
rt = 1.1;
for i = 1 : length(th)
    text(rt * cst(i), rt * snt(i), int2str(i * 30),...
        'HorizontalAlignment', 'center', ...
        'HandleVisibility', 'off', 'Parent', ax);
    if i == length(th)
        loc = [int2str(0) ' (' sample_data.dimensions{dir}.units ')'];
        horizAlign = 'left';
    else
        loc = int2str(180 + i * 30);
        horizAlign = 'center';
    end
    text(-rt * cst(i), -rt * snt(i), loc, 'HorizontalAlignment', horizAlign, ...
        'HandleVisibility', 'off', 'Parent', ax);
end

% display extra info
infoText = sprintf('%s\n', ...
    datestr(timeData(iTime)));

text(-1, 1, infoText,...
    'HorizontalAlignment', 'left', ...
    'HandleVisibility', 'off', 'Parent', ax);

mainPanel = findobj('Tag', 'mainPanel');
uicontrol(mainPanel, ...
    'Style',        'slider', ...
    'Min',          1, ...
    'Max',          length(timeData), ...
    'Value',        iTime, ...
    'SliderStep',   [1/(length(timeData)-1) 10/100], ...
    'Units',        'normalized', ...
    'Position',     posUi2(mainPanel, 50, 4, 49, 2:3, 0), ...
    'Callback',     {@changeITime,varCheckbox,ax,sample_data,var});
uicontrol(mainPanel, ...
    'Style'     ,'text', ...
    'Units'     , 'normalized', ...
    'Position'  , posUi2(mainPanel, 50, 1, 50, 1, 0), ...
    'String'    ,'Time cursor');
    
cb = colorbar('peer',ax);

% Attach the context menu to colorbar
hMenu = setTimeSerieColorbarContextMenu(myVar);
set(cb,'uicontextmenu',hMenu);

cbLabel = imosParameters(myVar.name, 'uom');
cbLabel = [myVar.name ' (' cbLabel ')'];
if length(cbLabel) > 20, cbLabel = [cbLabel(1:17) '...']; end
set(get(cb, 'YLabel'), 'String', cbLabel, 'Interpreter', 'none');

% set background to be grey
set(ax, 'Color', [0.75 0.75 0.75])

labels = {};

end

function changeITime(hObj,event,varCheckbox,ax, sample_data, var) %#ok<INUSL>
    
iTime = round(get(hObj, 'Value'));
set(varCheckbox, 'userData', iTime);

% clear and re-create the axe
delete(ax);

lenVar = length(sample_data.variables);
ax = subplot(lenVar, 1, var, ...
    'Parent', findobj('Tag', 'mainPanel'), ...
    'XGrid',  'on', ...
    'Color',  'none', ...
    'YGrid',  'on', ...
    'Layer',  'top');

polarPcolor(ax, sample_data, var);
if sample_data.meta.level == 1
    flagTimeSeriesTimeFrequencyDirection( ax, sample_data, var );
end

end