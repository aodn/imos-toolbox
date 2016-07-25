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



