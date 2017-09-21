function dataIdx = getSelectedTimeSeriesTimeFrequencyDirection( ...
  sample_data, var, ax, highlight )
%GETSELECTEDTIMESERIESTIMEFREQUENCYDIRECTION Returns the currently selected data on the 
% given time/frequency/direction axis.
%
% Inputs:
%   sample_data - Struct containing the data set.
%   var         - Variable in question (index into sample_data.variables).
%   ax          - Axis in question.
%   highlight   - Handle to the highlight object.
% 
% Outputs:
%   dataIdx     - Vector of indices into the data, defining the indices
%                 which are selected (and which were clicked on).
%
% Author:       Guillaume Galibert <guillaume.galibert@utas.edu.au>
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
narginchk(4, 4);

if ~isstruct(sample_data), error('sample_data must be a struct');        end
if ~isnumeric(var),        error('var must be numeric');                 end
if ~ishandle(ax),          error('ax must be a graphics handle');        end
if ~ishandle(highlight),   error('highlight must be a graphics handle'); end

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

% turn the highlight into data indices
for k = 1:length(highlightX)
    % get the indices, on each dimension, of each point in the highlight
    idx = find(X == highlightX(k) & Y == highlightY(k))';
    
    % 'flatten' those indices
    dataIdx = [dataIdx ((iTime - 1) * numel(X) + idx)];
end