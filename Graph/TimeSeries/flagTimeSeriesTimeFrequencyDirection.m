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
error(nargchk(3, 3, nargin));

if ~ishandle(ax),          error('ax must be a graphics handle'); end
if ~isstruct(sample_data), error('sample_data must be a struct'); end
if ~isnumeric(var),        error('var must be numeric');          end

qcSet = str2double(readProperty('toolbox.qc_set'));
rawFlag = imosQCFlag('raw', qcSet, 'flag');

freq = sample_data.variables{var}.dimensions(4);
dir  = sample_data.variables{var}.dimensions(5);

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
