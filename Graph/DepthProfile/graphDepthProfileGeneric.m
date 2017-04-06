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
if ~isnumeric(var),        error('var must be a numeric');        end

% get the toolbox execution mode
mode = readProperty('toolbox.mode');

% look for a depth variable
iDepthVar = getVar(sample_data.variables, 'DEPTH');
if iDepthVar ~= 0
    depth = sample_data.variables{iDepthVar};
else
    % look for a depth dimension
    iDepthDim = getVar(sample_data.dimensions, 'DEPTH');
    if iDepthDim ~= 0
        depth = sample_data.dimensions{iDepthDim};
    else
        error('dataset contains no depth data');
    end
end

var  = sample_data.variables{var};

switch mode
    case 'profile'
        h            = line(var.data(:, 1), depth.data(:, 1), 'Parent', ax, 'LineStyle', '-'); % downcast
        if size(var.data, 2) > 1
            h(end+1) = line(var.data(:, 2), depth.data(:, 2), 'Parent', ax, 'LineStyle', '--'); % upcast
        end
        
    case 'timeSeries'
        if size(var.data, 2) > 1
            % ADCP data, we look for vertical dimension
            iVertDim = var.dimensions(2);
            for i=1:size(var.data, 2)
                h(i) = line(var.data(:, i), depth.data - sample_data.dimensions{iVertDim}.data(i), 'Parent', ax, 'LineStyle', '-');
            end
        else
            h        = line(var.data, depth.data, 'Parent', ax, 'LineStyle', '-');
        end
        
end
set(ax, 'Tag', 'axis1D');

% for global/regional range display
mWh = findobj('Tag', 'mainWindow');
sMh = findobj('Tag', 'samplePopUpMenu');
iSample = get(sMh, 'Value');
climatologyRange = get(mWh, 'UserData');
if ~isempty(climatologyRange)
    if isfield(climatologyRange, ['rangeMin' var.name])
        xLim = get(ax, 'XLim');
        line(climatologyRange(iSample).(['rangeMin' var.name]), [depth.data(1); depth.data(end)], 'Parent', ax, 'Color', 'r');
        line(climatologyRange(iSample).(['rangeMax' var.name]), [depth.data(1); depth.data(end)], 'Parent', ax, 'Color', 'r');
        set(ax, 'XLim', xLim);
    end
end

labels = {var.name, 'DEPTH'};

% assume that the depth data is ascending - we want to display 
% it descending though, so reverse the axis orientation
set(ax, 'YDir', 'reverse');
