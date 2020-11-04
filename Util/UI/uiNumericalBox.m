function [result] = uiNumericalBox(boxNames, boxValues, boxFuncs, varargin)
% function [result] = uiNumericalBox(boxNames, boxValues, boxFuncs, varargin)
%
% Create a dialog box so user can input some numeric values. The difference here
% between inputdlg is that input is validated in place and restore to defaults
% if invalid.
%
% Inputs:
%
% boxNames - the names for each box.
% values - the default values for each box.
% funcs - the validating function for each box.
% 'Title' - The title of dialog
% 'panelTitle' - The title of the panel
%
%  Particular/non-uipanel options:
% 'outerMargin' - The outer margin for a inside panel
% 'panelHorizontalMargin' - the internal margin of the panel
% 'panelVerticalMargin' - the vertical margin of the panel
% 'boxWidth' - the individual boxes widths
% 'boxHeight' - the individual boxes heights
%
%
% Outputs:
%
% The new parameters values defined by the user.
%
% Example:
%
% %manual triggering put a number on the box
% %[cvalue] = uiNumericalBox({'0+1=?'},{0},{@(x)(x)},'Title','Math Problem','panelTitle','#1');
% %assert(iscell(cvalue))
% %assert(isscalar(cvalue{1}))
%
% author: hugo.oliveira@utas.edu.au
%

% Copyright (C) 2020, Australian Ocean Data Network (AODN) and Integrated
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
%
% You should have received a copy of the GNU General Public License
% along with this program.
% If not, see <https://www.gnu.org/licenses/gpl-3.0.en.html>.
%
if nargin < 3
    error('Need at least 3 inputs')
end

nboxes = length(boxNames);
nvalues = length(boxValues);
nfuncs = length(boxFuncs);

if nboxes ~= nvalues || nboxes ~= nfuncs
    error('The length of box arguments must be the same')
end

result = cell(1, length(boxNames));

%parsing inputs
p = inputParser;
p.KeepUnmatched = true;

ismargin = @(x)(x >= 0 & x <= .25);
isnormalized = @(x)(x>=0 & x<= 0.9);
addParameter(p, 'title', 'title', @ischar);
addParameter(p, 'panelTitle', 'panel', @ischar);
addParameter(p, 'outerMargin', 0.0, ismargin);
addParameter(p, 'panelHorizontalMargin', 0.025, ismargin);
addParameter(p, 'panelVerticalMargin', 0.025, ismargin);
addParameter(p, 'boxWidth', 0.1, isnormalized);
addParameter(p, 'boxHeight', 0.1, isnormalized);
p.parse(varargin{:})
extraOpts = struct2parameters(p.Unmatched);

title = p.Results.title;
outerMargin = p.Results.outerMargin;
panelTitle = p.Results.panelTitle;
panelVerticalMargin = p.Results.panelVerticalMargin;
panelHorizontalMargin = p.Results.panelHorizontalMargin;
boxWidth = p.Results.boxWidth;
boxHeight = p.Results.boxHeight;

%ui creation
dialog_window = dialog('Name', title);

panelOpts = {'title', panelTitle, 'Units', 'normalized', 'Position', [outerMargin, outerMargin, 1 - outerMargin * 2, 1 - outerMargin * 2]};
panel = uipanel(dialog_window, panelOpts{:}, extraOpts{:});

textWidth = boxWidth*2.5;
textHeight = boxHeight;

textDefaultOffset = panelHorizontalMargin + boxWidth + panelHorizontalMargin;

boxPosition = [panelHorizontalMargin, 1 - panelVerticalMargin, boxWidth, boxHeight];
textboxPosition = [textDefaultOffset, 1 - panelVerticalMargin - boxHeight / 4, textWidth, textHeight]; % centred at box

verticalOffset = [0, panelVerticalMargin + boxHeight, 0, 0];

vbox = cell(1, nargout);
textbox = cell(1, nargout);

for k = 1:length(boxValues)
    boxPosition = boxPosition - verticalOffset;
    textboxPosition = textboxPosition - verticalOffset;

    vboxOpts = {'Units', 'normalized', 'Position', boxPosition};
    textboxOpts = {'Style', 'text', 'Value', boxValues{k}, 'String', boxNames{k}, 'FontSize', 10, 'Units', 'normalized', 'Position', textboxPosition};
    laterCallback = @(~)(1); % dummy call
    vbox{k} = numericInputButton(panel, boxValues{k}, boxFuncs{k}, laterCallback, vboxOpts{:});
    textbox{k} = uicontrol(panel, textboxOpts{:});

end

%finish everything when ok is pressed
okOpts = {'String', 'OK', 'Callback', @storeAndCloseCallback, 'Units', 'normalized', 'Position', [1 - boxWidth, 0, boxWidth, 0.1]};
ok_button = uicontrol(panel, okOpts{:});
waitfor(ok_button)

function storeAndCloseCallback(~, ~, ~)

for n = 1:length(vbox)
    result{n} = vbox{n}.uicontrol.Value;
end

close(dialog_window)
end

end
