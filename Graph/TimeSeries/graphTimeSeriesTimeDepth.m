function [h labels] = graphTimeSeriesTimeDepth( ax, sample_data, var )
%GRAPHTIMESERIESTimeDepth Plots the given data using pcolor.
%
% This function is used for plotting time/depth data. The pcolor function is 
% used to display a 2-D color plot, with time on the X axis and depth on the 
% Y axis, and the data indicated indicated by the colour.
%
% Inputs:
%   ax          - Parent axis.
%   sample_data - The data set.
%   var         - The variable to plot.
%
% Outputs:
%   h           - Handle to the surface which was plotted.
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

zTitle = 'DEPTH';

time  = getVar(sample_data.dimensions, 'TIME');
depth = getVar(sample_data.dimensions, zTitle);

% case of sensors on the seabed looking upward like moored ADCPs
if depth == 0
    zTitle = 'HEIGHT_ABOVE_SENSOR';
    depth = getVar(sample_data.dimensions, zTitle);
end

time  = sample_data.dimensions{time};
depth = sample_data.dimensions{depth};
var   = sample_data.variables {var};

if strcmpi(depth.positive, 'down')
    set(ax, 'YDir', 'reverse');
end

h = pcolor(ax, time.data, depth.data, var.data');
set(h, 'FaceColor', 'flat', 'EdgeColor', 'none');
cb = colorbar();

% Define a context menu
hMenu = uicontextmenu;

% Define callbacks for context menu items that change linestyle
hcb11 = 'colormap(jet)';
hcb12 = 'colormap(r_b)';

% Define the context menu items and install their callbacks
mainItem1 = uimenu(hMenu, 'Label', 'Colormaps');
item11 = uimenu(mainItem1, 'Label', 'jet (default)', 'Callback', hcb11);
item12 = uimenu(mainItem1, 'Label', 'r_b', 'Callback', hcb12);

mainItem2 = uimenu(hMenu, 'Label', 'Color range');
item21 = uimenu(mainItem2, 'Label', 'normal (default)',     'Callback', {@cbCLimRange, 'normal', var.data});
item22 = uimenu(mainItem2, 'Label', 'auto (+/-3*stdDev)',   'Callback', {@cbCLimRange, 'auto', var.data});
item23 = uimenu(mainItem2, 'Label', 'manual',               'Callback', {@cbCLimRange, 'manual', var.data});

% Attach the context menu to each line
set(cb,'uicontextmenu',hMenu);

% Let's redefine grid lines after pcolor to make sure grid lines appear
% above color data
set(ax, 'XGrid',  'on',...
    'YGrid',  'on',...
    'Layer', 'top');

cbLabel = imosParameters(var.name, 'uom');
cbLabel = [strrep(var.name, '_', ' ') ' (' cbLabel ')'];
if length(cbLabel) > 20, cbLabel = [cbLabel(1:17) '...']; end
set(get(cb, 'YLabel'), 'String', cbLabel);

labels = {'TIME', zTitle};

end

% Callback function for CLim range
function cbCLimRange(src,eventdata, cLimMode, data)

CLim = [min(min(data)), max(max(data))];

switch cLimMode
    case 'auto'
        iNan = isnan(data);
        med = median(data(~iNan));
        stdDev = sqrt(mean((data(~iNan) - med).^2));
%         CLim = [med-3*stdDev, med+3*stdDev];
        CLim = [-3*stdDev, 3*stdDev];
    case 'manual'
        CLimCurr = get(gca, 'CLim');
        prompt = {['{\bf', sprintf('Colorbar range :}\n\nmin value :')],...
            'max value :'};
        def                 = {num2str(CLimCurr(1)), num2str(CLimCurr(2))};
        dlg_title           = 'Set the colorbar range';
        
        options.Resize      = 'on';
        options.WindowStyle = 'modal';
        options.Interpreter = 'tex';
        
        answ = inputdlg( prompt, dlg_title, 1, def, options );
        if ~isempty(answ)
            CLim = [str2double(answ{1}), str2double(answ{2})];
        else
            CLim = CLimCurr;
        end
end

set(gca, 'CLim', CLim);

end