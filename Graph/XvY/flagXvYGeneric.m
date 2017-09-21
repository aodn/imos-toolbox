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
