function flags = flagTimeSeriesTimeDepth( ax, sample_data, var )
%FLAGTIMESERIESTIMEDEPTH Adds flag overlays to a time/depth plot.
%
% Adds QC flag overlays to a time/depth plot, highlighting the data points 
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

flags = [];

qcSet = str2double(readProperty('toolbox.qc_set'));
rawFlag = imosQCFlag('raw', qcSet, 'flag');

zTitle = 'DEPTH';

time  = getVar(sample_data.dimensions, 'TIME');
depth = getVar(sample_data.dimensions, zTitle);

% case of sensors on the seabed looking upward like moored ADCPs
if depth == 0
    zTitle = 'HEIGHT_ABOVE_SENSOR';
    depth = getVar(sample_data.dimensions, zTitle);
end

time  = sample_data.dimensions{time};
depth = sample_data.dimensions{depth};

fl    = sample_data.variables{var}.flags;
data  = sample_data.variables{var}.data;

% get a list of the different flag types to be graphed
flagTypes = unique(fl);

% if no flags to plot, put a dummy handle in - the 
% caller is responsible for checking and ignoring
flags = 0.0;

% a different patch for each flag type
for m = 1:length(flagTypes)

  % don't display raw data flags
  if flagTypes(m) == rawFlag, continue; end

  f = find(fl == flagTypes(m));

  fc = imosQCFlag(flagTypes(m), qcSet, 'color');

  fx = mod(f, size(fl,1));
  fx(fx == 0) = size(fl, 1);
  fy = ceil(mod(f / size(fl,1), size(fl,2)));
  fy(fy == 0) = size(fl, 2);
  
  fx = time.data(fx);
  fy = depth.data(fy);
    
  flags(m) = line(fx, fy,...
    'Parent', ax,...
    'LineStyle', 'none',...
    'Marker', 's',...
    'MarkerFaceColor', fc,...
    'MarkerEdgeColor', 'none',...
    'MarkerSize', 3);
end
