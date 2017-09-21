function flags = flagTransectGeneric( ax, sample_data, var )
%FLAGTRANSECTGENERIC Draws overlays on the given transect axis, to 
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
% Author: Paul McCarthy <paul.mccarthy@csiro.au>
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

% get latitude/longitude variables
lat = getVar(sample_data.variables, 'LATITUDE');
lon = getVar(sample_data.variables, 'LONGITUDE');

lat = sample_data.variables{lat};
lon = sample_data.variables{lon};
var = sample_data.variables{var};

% get a list of the different flag types to be graphed
flagTypes = unique(var.flags);

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

% a different line for each flag type
for m = 1:lenFlag

  f = (var.flags == flagTypes(m));

  fc = imosQCFlag(flagTypes(m), qcSet, 'color');

  fx = lat.data(f);
  fy = lon.data(f);

  flags(m) = line(fx, fy,...
    'Parent', ax,...
    'LineStyle', 'none',...
    'Marker', 'o',...
    'MarkerFaceColor', fc,...
    'MarkerEdgeColor', 'none');
end
