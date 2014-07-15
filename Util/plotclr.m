function h = plotclr(hAx, x, y, v, marker, vlim)
% plots the values of v colour coded
% at the positions specified by x and y.
% A colourbar is added on the right side of the figure.
%
% The colourbar strectches from the minimum value of v to its
% maximum.
%
% 'marker' is optional to define the marker being used. The
% default is a point. To use a different marker (such as circles, ...) send
% its symbol to the function (which must be enclosed in '; see example).
%
% 'vlim' is optional, to define the limits of the colourbar.
% v values outside vlim are not plotted
%
% modified by Guillaume Galibert, UTAS, 2014
% from 'plotclr' by Stephanie Contardo, CSIRO, 2009
%
% Copyright (c) 2010, Stephanie Contardo
% All rights reserved.
% 
% Redistribution and use in source and binary forms, with or without
% modification, are permitted provided that the following conditions are
% met:
% 
%     * Redistributions of source code must retain the above copyright
%       notice, this list of conditions and the following disclaimer.
%     * Redistributions in binary form must reproduce the above copyright
%       notice, this list of conditions and the following disclaimer in
%       the documentation and/or other materials provided with the distribution
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
h=[];

if nargin < 5
    marker = '.';
end

map = colormap(hAx);
if nargin > 5
    miv = vlim(1);
    mav = vlim(2);
else
    miv = min(v);
    mav = max(v);
end
nMap = size(map, 1);
clrstep = (mav - miv)/nMap;

% Plot the points
hold(hAx, 'on');
for i=1:nMap/2
    % for each color value from the colormap we identify the data that
    % falls in this range and we plot it with a different color. 
    
    % !!! The result is such that the overlapping of points is dictated by 
    % the order of plotting the colors and not by the X axis order (from 
    % first to last) of the total points given.
    % A color ordering from middle to high/low ends on the colormap enables
    % to better see most of the variability. An ordering from low to high
    % would for example generate an image with higher color values being 
    % more likely to be on top of and hence cover lower values colors.
    
    % plot from the middle to high
    nc = nMap/2 + i;
    if nc == nMap
        % otherwise highest color values may not be plotted!
        iv = (v > miv+(nc-1)*clrstep);
    else
        iv = (v > miv+(nc-1)*clrstep) & (v <= miv+nc*clrstep);
    end
    
    htmp = plot(hAx, x(iv), y(iv), marker, ...
        'Color', map(nc,:), ...
        'MarkerSize', sqrt(5));
    
    if ~isempty(htmp), h = htmp; end
    
    % plot from the middle to low
    nc = nMap/2 + 1 - i;
    if nc == 1
        % otherwise lowest color values may not be plotted!
        iv = (v <= miv+nc*clrstep);
    else
        iv = (v > miv+(nc-1)*clrstep) & (v <= miv+nc*clrstep);
    end
    
    htmp = plot(hAx, x(iv), y(iv), marker, ...
        'Color', map(nc,:), ...
        'MarkerSize', sqrt(5));
    
    if ~isempty(htmp), h = htmp; end
end
hold(hAx, 'off');
