function pos = posUi2( hContainer , nLine , nRow , line , row , margin , outUnits )
% POSUI2 - Automatically computes the position of a graphical object in its
% parent's object following a matrix disposition : nLine x nRow
%
% Inputs:
%   hContainer  - graphical component's parent handle
%   nLine       - total number of lines
%   nRow        - total number of rows
%   line        - used line(s)
%   row         - used row(s)
%   margin      - margin (normalized) : percentage of the smallest parent's
%               dimension
%   outUnits    - type of output units (by default 'normalized') for pos
%
% Outputs:
%   pos         - position vector
%
% Example:
%   hFig = figure;
%   uicontrol(...
%     'Parent',            hFig,...
%     'style',            'pushbutton',...
%     'units',            'normalized',...
%     'Position',         posUi2(hFig,4,3,2:3,1:2,0.05));
%
% Remarks:
%  - margin is normalized (percentage of the parent's size)
%  - normalized unit compulsory for the parent and children graphical
%  objects!!!
%
% Author:       Arnaud Gaillot <arnaud.gaillot@ifremer.fr>
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

narginchk(5, 7);
if nargin < 6
    margin = 0;
end
if nargin < 7
    outUnits = 'normalized';
end

% Ascendent sorting
line = sort(line);
row = sort(row);

% lines/rows allocation check
if line(end) > nLine
    warning(sprintf('number of used lines is greater than total number of lines : %d > %d',line(end),nLine));
    line = (line(1):nLine) ;
end
if row(end) > nRow
    warning(sprintf('number of used rows is greater than total number of rows : %d > %d', row(end),nRow));
    row = (row(1):nRow) ;
end

% get container's size
OldUnits = get(hContainer,'units');
if strcmpi(OldUnits,'pixel')
    posContainer = get(hContainer,'position');
else
    set(hContainer,'units','pixel');
    posContainer = get(hContainer,'position');
    set(hContainer,'units',OldUnits);
end
X = posContainer(3);
Y = posContainer(4);

% equalization of X and Y margins
if X/Y > 1
    margX = margin*Y/X;
    margY = margin;
else
    margX = margin;
    margY = margin*X/Y;
end

% dx dy and calculation, 1000th precision
dy = round(1/nLine*1000)/1000;
dx = round(1/nRow*1000)/1000;

% building position vector
if row(1) == 1

    pos(1) = (row(1)-1)*dx + margX ;                       % x0
    if row(end) == nRow
        pos(3) = (row(end)-(row(1)-1))*dx - 2*margX;       % dx
    else
        pos(3) = (row(end)-(row(1)-1))*dx - 3/2*margX;     % dx
    end

else

    pos(1) = (row(1)-1)*dx + margX/2 ;                     % x0
    if row(end) == nRow
        pos(3) = (row(end)-(row(1)-1))*dx - 3/2*margX;     % dx
    else
        pos(3) = (row(end)-(row(1)-1))*dx - margX;         % dx
    end
end


if line(end) == nLine

    pos(2) = 1 - line(end)*dy + margY ;                     % y0

    if line(1) == 1
        pos(4) = (line(end)- (line(1)-1) )*dy - 2*margY ;    % dy
    else
        pos(4) = (line(end)- (line(1)-1) )*dy - 3/2*margY;   % dy
    end

else
    pos(2) = 1 - line(end)*dy + margY/2  ;                  % y0

    if line(1) == 1
        pos(4) = (line(end)- (line(1)-1) )*dy - 3/2*margY ;  % dy
    else
        pos(4) = (line(end)- (line(1)-1) )*dy - margY;       % dy
    end

end

switch outUnits
    case 'pixel'
        pos([1,3]) = floor( pos([1,3]) * X );
        pos([2,4]) = floor( pos([2,4]) * Y );
end



