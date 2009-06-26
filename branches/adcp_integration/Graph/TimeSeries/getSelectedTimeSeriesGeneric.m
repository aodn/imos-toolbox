function dataIdx = getSelectedTimeSeriesGeneric( ...
  sample_data, ax, highlight, click )
%GETSELECTEDTIMESERIESGENERIC Returns the indices of the currently 
% highlighted data on the given axis.
%
%
%
% Inputs:
%   sample_data -
%   ax          -
%   highlight   -
%   click       -
%   
%
% Outputs:
%   dataIdx     -
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
dataIdx = [];

time = getVar(sample_data.dimensions, 'TIME');
time = sample_data.dimensions{time};

highlightX = get(highlight, 'XData');
highlightY = get(highlight, 'YData');

% figure out if the click was anywhere near the highlight 
% (within 1% of the current visible range on x and y)
xError = get(ax, 'XLim');
xError = abs(xError(1) - xError(2));
yError = get(ax, 'YLim');
yError = abs(yError(1) - yError(2));

% was click near highlight?
if any(abs(click(1)-highlightX) <= xError*0.01)...
&& any(abs(click(2)-highlightY) <= yError*0.01)

  % find the indices of the selected points
  dataIdx = find(ismember(time.data, highlightX));
end
