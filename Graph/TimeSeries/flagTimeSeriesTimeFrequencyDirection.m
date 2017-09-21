function flags = flagTimeSeriesTimeFrequencyDirection( ax, sample_data, var )
%FLAGTIMESERIESTIMEFREQUENCYDIRECTION Adds flag overlays to a time/frequency plot.
%
% Adds QC flag overlays to a time/frequency/direction plot, highlighting the data points 
% which have been flagged. Uses line objects.
%
% Inputs:
%   ax          - Handle to the axes object on which to draw the overlays.
%   sample_data - Struct containing sample data.
%   var         - Index into sample_data.variables, defining the variable
%                 in question.
%
% Outputs:
%   flags       - Vector of handles to line objects, which are the flag
%                 overlays.
%
% Author:       Guillaume Galibert <guillaume.galibert@utas.edu.au>
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
narginchk(3, 3);

if ~ishandle(ax),          error('ax must be a graphics handle'); end
if ~isstruct(sample_data), error('sample_data must be a struct'); end
if ~isnumeric(var),        error('var must be numeric');          end

qcSet = str2double(readProperty('toolbox.qc_set'));
rawFlag = imosQCFlag('raw', qcSet, 'flag');

freq = sample_data.variables{var}.dimensions(2);
dir  = sample_data.variables{var}.dimensions(3);

dirData   = sample_data.dimensions{dir}.data;
freqData  = sample_data.dimensions{freq}.data;

varCheckbox = findobj('Tag', ['checkbox' sample_data.variables{var}.name]);
iTime = get(varCheckbox, 'userData');
if isempty(iTime)
    % we choose an arbitrary time to plot
    iTime = 1;
end

sswvFlags = sample_data.variables{var}.flags(iTime, :, :);

nFreq = length(freqData);
nDir = length(dirData);
r = freqData/max(freqData);
theta = 2*pi*[dirData; 360]/360; % we need to manually add the last angle value to complete the circle
theta = theta - (theta(2)-theta(1))/2; % we want to centre the angular beam on the actual angular value

% get a list of the different flag types to be graphed
flagTypes = unique(sswvFlags);

% don't display raw data flags
iRawFlag = (flagTypes == rawFlag);
if any(iRawFlag), flagTypes(iRawFlag) = []; end
  
lenFlag = length(flagTypes);

% if no flags to plot, put a dummy handle in - the 
% caller is responsible for checking and ignoring
flags = nan(lenFlag, 1);
if isempty(flags)
    flags = 0.0;
end

% a different patch for each flag type
for m = 1:lenFlag
    
    f = (sswvFlags == flagTypes(m));
    
    fc = imosQCFlag(flagTypes(m), qcSet, 'color');
    fn = strrep(imosQCFlag(flagTypes(m),  qcSet, 'desc'), '_', ' ');
    
    fx = nan(nDir+1, nFreq);
    fy = nan(nDir+1, nFreq);
    for i=1:nDir+1
        fy(i, :) = r*cos(theta(i)); % theta is positive clockwise from North
        fx(i, :) = r*sin(theta(i));
    end

    fx = fx(f);
    fy = fy(f);
    
    flags(m) = line(fx, fy,...
        'Parent', ax,...
        'LineStyle', 'none',...
        'Marker', 's',...
        'MarkerFaceColor', fc,...
        'MarkerEdgeColor', 'none',...
        'MarkerSize', 3);
    
    % Create a UICONTEXTMENU, and assign a UIMENU to it
    hContext = uicontextmenu;
    hMenu = uimenu('parent',hContext);
    
    % Set the UICONTEXTMENU to the line object
    set(flags(m),'uicontextmenu',hContext);
    
    % Create a WindowButtonDownFcn callback that will update
    % the label on the UICONTEXTMENU's UIMENU
%     set(gcf,'WindowButtondownFcn', ...
%         'set(hMenu, ''label'', fn)');
    set(hMenu, 'label', fn);
end
