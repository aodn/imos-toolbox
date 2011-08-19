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
error (nargchk(3,3,nargin));

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
