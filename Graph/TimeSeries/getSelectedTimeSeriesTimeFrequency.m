function dataIdx = getSelectedTimeSeriesTimeFrequency( ...
  sample_data, var, ax, highlight, click )
%GETSELECTEDTIMESERIESTIMEFREQUENCY Returns the currently selected data on the 
% given time/frequency axis.
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
error(nargchk(5, 5, nargin));

if ~isstruct(sample_data), error('sample_data must be a struct');        end
if ~isnumeric(var),        error('var must be numeric');                 end
if ~ishandle(ax),          error('ax must be a graphics handle');        end
if ~ishandle(highlight),   error('highlight must be a graphics handle'); end
if ~isnumeric(click),      error('click must be numeric');               end

dataIdx = [];

time = sample_data.variables{var}.dimensions(1);
freq = sample_data.variables{var}.dimensions(4);

time = sample_data.dimensions{time}.data;
freq = sample_data.dimensions{freq}.data;

highlightX = get(highlight, 'XData');
highlightY = get(highlight, 'YData');

% was click within highlight range?
if click(1) >= min(highlightX) && click(1) <= max(highlightX)...
&& click(2) >= min(highlightY) && click(2) <= max(highlightY)
  
  % turn the highlight into data indices
  dataIdx = [];
  
  for k = 1:length(highlightX)
    
    % get the indices, on each dimension, of each point in the highlight
    timeIdx = find(time == highlightX(k));
    freqIdx = find(freq == highlightY(k));
    
    % 'flatten' those indices
    dataIdx = [dataIdx ((freqIdx - 1) * length(time) + timeIdx)];
  end
end