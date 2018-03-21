function fastSaveas( hFig, backgroundColor, fileDestination )
%FASTSAVEAS is a faster alternative to saveas. 
% It is used to save diagnostic plots when exporting netCDF files.
%
% Inputs:
%   hFig            - figure handler.
%
%   backgroundColor - a three-element vector of RGB values for figure
%                   background.
%
%   fileDestination - path to which the figure is printed.
%
% Author: Guillaume Galibert <guillaume.galibert@utas.edu.au>
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

% ensure the printed version is the same whatever the screen used.
set(hFig, ...
    'PaperPositionMode',    'manual', ...
    'PaperType',            'A4', ...
    'PaperOrientation',     'landscape', ...
    'InvertHardcopy',       'off'); % preserve the color scheme

switch computer
    case 'GLNXA64'
        set(hFig, ...
            'Position',         [10 10 1920 1200]); % set static figure resolution (some linux go fullscreen across every screen!)
        
    otherwise
        set(hFig, ...
            'PaperUnits',       'normalized', ...
            'PaperPosition',    [0 0 1 1]); % set figure resolution to full screen (as big as possible to fit the legend)
        
end

drawnow; % Forces GUI to update itself, otherwise colorbar might be missing

% use hgexport to print to file as close as possible as what we see
myStyle = hgexport('factorystyle');
myStyle.Format     = 'png'; % (default is eps)
myStyle.Background = backgroundColor; % (default is white)

hgexport(hFig, fileDestination, myStyle);

end

