function [h labels] = graphDepthProfileGeneric( ax, sample_data, var )
%GRAPHDEPTHPROFILEGENERIC Plots the given variable (x axis) against depth 
% (y axis).
%
% Inputs:
%   ax          - Parent axis.
%   sample_data - The data set.
%   var         - The variable to plot.
%
% Outputs:
%   h           - Handle(s) to the line(s)  which was/were plotted.
%   labels      - Cell array containing x/y labels to use.
%
% Author:       Paul McCarthy <paul.mccarthy@csiro.au>
% Contributor:  Guillaume Galibert <guillaume.galibert@utas.edu.au>
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
error(nargchk(3,3,nargin));

if ~ishandle(ax),          error('ax must be a graphics handle'); end
if ~isstruct(sample_data), error('sample_data must be a struct'); end
if ~isnumeric(var),        error('var must be a numeric');        end

% look for a depth dimension or variable
depth = getVar(sample_data.dimensions, 'DEPTH');
if depth ~= 0 
  
  depth = sample_data.dimensions{depth}; 
else
  
  depth = getVar(sample_data.variables, 'DEPTH');
  
  if depth == 0, error('dataset contains no depth data'); end
  depth = sample_data.variables{depth}; 
end

var  = sample_data.variables {var};

h      = line(var.data, depth.data, 'Parent', ax);
set(ax, 'Tag', 'axis1D');

% test for climatology display
mWh = findobj('Tag', 'mainWindow');
morelloRange = get(mWh, 'UserData');
if strcmpi(var.name, 'TEMP') && ~isempty(morelloRange)
    hRMinT = line(morelloRange.rangeMinT, depth.data, 'Parent', ax);
    hRMaxT = line(morelloRange.rangeMaxT, depth.data, 'Parent', ax);
    set(hRMinT, 'Color', 'r');
    set(hRMaxT, 'Color', 'r');
    set(ax, 'XLim', [min(morelloRange.rangeMinT) - min(morelloRange.rangeMinT)/10, ...
        max(morelloRange.rangeMaxT) + max(morelloRange.rangeMaxT)/10]);
elseif strcmpi(var.name, 'PSAL') && ~isempty(morelloRange)
    hRMinS = line(morelloRange.rangeMinS, depth.data, 'Parent', ax);
    hRMaxS = line(morelloRange.rangeMaxS, depth.data, 'Parent', ax);
    set(hRMinS, 'Color', 'r');
    set(hRMaxS, 'Color', 'r');
    set(ax, 'XLim', [min(morelloRange.rangeMinS) - min(morelloRange.rangeMinS)/10, ...
        max(morelloRange.rangeMaxS) + max(morelloRange.rangeMaxS)/10]);
elseif strcmpi(var.name, 'DOX2') && ~isempty(morelloRange)
    hRMinS = line(morelloRange.rangeMinDO, depth.data, 'Parent', ax);
    hRMaxS = line(morelloRange.rangeMaxDO, depth.data, 'Parent', ax);
    set(hRMinS, 'Color', 'r');
    set(hRMaxS, 'Color', 'r');
    set(ax, 'XLim', [min(morelloRange.rangeMinDO) - min(morelloRange.rangeMinDO)/10, ...
        max(morelloRange.rangeMaxDO + max(morelloRange.rangeMaxDO)/10)]);
end

labels = {var.name, 'DEPTH'};

% assume that the depth data is ascending - we want to display 
% it descending though, so reverse the axis orientation
set(ax, 'YDir', 'reverse');
