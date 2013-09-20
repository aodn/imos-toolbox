function dataIdx = getSelectedTimeSeriesTimeFrequencyDirection( ...
  sample_data, var, ax, highlight, click )
%GETSELECTEDTIMESERIESTIMEFREQUENCYDIRECTION Returns the currently selected data on the 
% given time/frequency/direction axis.
%
% Inputs:
%   sample_data - Struct containing the data set.
%   var         - Variable in question (index into sample_data.variables).
%   ax          - Axis in question.
%   highlight   - Handle to the highlight object.
%   click       - Where the user clicked the mouse.
% 
% Outputs:
%   dataIdx     - Vector of indices into the data, defining the indices
%                 which are selected (and which were clicked on).
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
error(nargchk(5, 5, nargin));

if ~isstruct(sample_data), error('sample_data must be a struct');        end
if ~isnumeric(var),        error('var must be numeric');                 end
if ~ishandle(ax),          error('ax must be a graphics handle');        end
if ~ishandle(highlight),   error('highlight must be a graphics handle'); end
if ~isnumeric(click),      error('click must be numeric');               end

dataIdx = [];

freq = sample_data.variables{var}.dimensions(4);
dir  = sample_data.variables{var}.dimensions(5);

varCheckbox = findobj('Tag', ['checkbox' sample_data.variables{var}.name]);
iTime = get(varCheckbox, 'userData');
if isempty(iTime)
    % we choose an arbitrary time to plot
    iTime = 1;
end

dirData  = sample_data.dimensions{dir}.data;
freqData = sample_data.dimensions{freq}.data;

nFreq = length(freqData);
nDir = length(dirData);
r = freqData/max(freqData);
theta = 2*pi*dirData/360;
theta = theta - (theta(2)-theta(1))/2; % we want to centre the angular beam on the actual angular value

X = nan(nFreq, nDir);
Y = nan(nFreq, nDir);
for i=1:nDir
    Y(:, i) = r*cos(theta(i)); % theta is positive clockwise from North
    X(:, i) = r*sin(theta(i));
end

highlightX = get(highlight, 'XData');
highlightY = get(highlight, 'YData');

% was click within highlight range?
if click(1) >= min(highlightX) && click(1) <= max(highlightX)...
&& click(2) >= min(highlightY) && click(2) <= max(highlightY)
  
  % turn the highlight into data indices
  dataIdx = [];
  
  for k = 1:length(highlightX)
    
    % get the indices, on each dimension, of each point in the highlight
    idx = find(X == highlightX(k) & Y == highlightY(k))';
    
    % 'flatten' those indices
    dataIdx = [dataIdx ((iTime - 1) * numel(X) + idx)];
  end
end