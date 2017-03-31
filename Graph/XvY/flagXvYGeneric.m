function hFlags = flagXvYGeneric( ax, sample_data, var )
%FLAGXVYGENERIC Draws overlays on the given XvY axis, to 
% display QC flag data for the given variable.
%
% Draws a set of line objects on the given axis, to display the QC flags
% for the given variable. 
% 
% Inputs:
%   ax          - The axis on which to draw the QC data.
%   sample_data - Struct containing sample data.
%   var         - Index into sample_data.variables, defining the variable
%                 in question.
%
% Outputs:
%   flags       - Vector of handles to line objects, which are the flag
%                 overlays.
%
% Author:       Paul McCarthy <paul.mccarthy@csiro.au>
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
narginchk(3,3);

if ~ishandle(ax),          error('ax must be a graphics handle'); end
if ~isstruct(sample_data), error('sample_data must be a struct'); end
if ~isnumeric(var),        error('var must be numeric');          end

qcSet = str2double(readProperty('toolbox.qc_set'));
rawFlag = imosQCFlag('raw', qcSet, 'flag');

flags1 = sample_data.variables{var(1)}.flags;
flags2 = sample_data.variables{var(2)}.flags;
flags  = max(flags1, flags2);
dataX  = sample_data.variables{var(1)}.data;
dataY  = sample_data.variables{var(2)}.data;

% get a list of the different flag types to be graphed
flagTypes = unique(flags);

% don't display raw data flags
iRawFlag = (flagTypes == rawFlag);
if any(iRawFlag), flagTypes(iRawFlag) = []; end
  
lenFlag = length(flagTypes);

% if no flags to plot, put a dummy handle in - the 
% caller is responsible for checking and ignoring
hFlags = nan(lenFlag, 1);
if isempty(hFlags)
    hFlags = 0.0;
end

% a different line for each flag type
for m = 1:lenFlag

  f = (flags == flagTypes(m));

  fc = imosQCFlag(flagTypes(m), qcSet, 'color');
  fn = strrep(imosQCFlag(flagTypes(m),  qcSet, 'desc'), '_', ' ');

  fx = dataX(f);
  fy = dataY(f);

  hFlags(m) = line(fx, fy,...
    'Parent', ax,...
    'LineStyle', 'none',...
    'Marker', 'o',...
    'MarkerFaceColor', fc,...
    'MarkerEdgeColor', 'none');

    % Create a UICONTEXTMENU, and assign a UIMENU to it
    hContext = uicontextmenu;
    hMenu = uimenu('parent',hContext);

    % Set the UICONTEXTMENU to the line object
    set(hFlags(m),'uicontextmenu',hContext);

    % Create a WindowButtonDownFcn callback that will update
    % the label on the UICONTEXTMENU's UIMENU
    %     set(gcf,'WindowButtondownFcn', ...
    %         'set(hMenu, ''label'', fn)');
    set(hMenu, 'label', fn);
end
