function [ plotH ] = fastScatterMesh( hAx, xdata, ydata, cdata, colLimits, varargin )
%FASTSCATTERMESH fast scatter plot using mesh plot with simple zbuffering
%of markers
%   hAx : axis handle
%   xdata : x data
%   ydata : y data
%   cdata : data used to color markers
%   colLimits : min/max cdata

% Posting by Boris Babic for the mesh method, see 
% http://www.mathworks.com/matlabcentral/newsreader/view_thread/22966
% as referenced in
% http://au.mathworks.com/matlabcentral/fileexchange/47205-fastscatter-m
% http://au.mathworks.com/matlabcentral/fileexchange/53580-fastscatterm

axes(hAx);
cmap = colormap(hAx);

nColors = length(cmap);

minClim = colLimits(1);
maxClim = colLimits(2);

% index of valid data
ix = find(isfinite(cdata + xdata + ydata));
if isempty(ix) || numel(ix) < 2
    return;
end

if mod(length(ix), 2) == 1
    ix(end+1) = ix(end);
end

% normalize cdata
normData = (cdata(ix) - minClim) / ( maxClim - minClim );
[~, idx] = histc(normData, 0: 1/nColors : 1);

% simple zbuffering of markers
% 'ascending', 'descending', 'triangle', 'vee', 'flat', 'parabolic',
% 'hamming', 'hann'
try
    zType =  lower(readProperty('visualQC.zbuffer'));
catch e
    zType = 'triangle';
end

switch zType
    case 'ascending',
        zBuffer = linspace(0, 1, nColors);
    case 'descending',
        zBuffer = linspace(1, 0, nColors) ;
    case 'triangle',
        zBuffer = [linspace(0, 1, nColors/2) linspace(1, 0, nColors/2)];
    case 'vee',
        zBuffer = [linspace(1, 0, nColors/2) linspace(0, 1, nColors/2)];
    case 'flat',
        zBuffer = zeros(size(ix));
    case 'parabolic'
        jj = (0:nColors-1)';
        zBuffer = 1 - (2*jj/nColors - 1).^2;
    case 'hamming'
        thalf=pi/nColors*((1-nColors):2:0)';         % first half sample locations
        hwin=.54+.46*cos(thalf);                       % first half window
        zBuffer=[hwin; hwin(floor(nColors/2):-1:1)];  % full window
    case 'hann'
        thalf=pi/nColors*((1-nColors):2:0)';         % first half sample locations
        hwin=.5+.5*cos(thalf);                         % first half window
        zBuffer=[hwin; hwin(floor(nColors/2):-1:1)];  % full window
    otherwise
        warning('Unknown marker zbuffer method, using flat');
        zBuffer = zeros(size(ix));
end

zBuffer = zBuffer(idx);
if mod(length(ix),2)==1
    zBuffer(:,end+1)=zBuffer(:,end);
end

ix2D=reshape(ix,2,[]);

plotH = mesh(xdata(ix2D),ydata(ix2D),reshape(zBuffer,2,[]),double(cdata(ix2D)),...
    'EdgeColor','none', 'MarkerEdgeColor','flat', 'FaceColor','none',...
    varargin{:});

view(2); %sets the default 2-D view for mesh plot

end

