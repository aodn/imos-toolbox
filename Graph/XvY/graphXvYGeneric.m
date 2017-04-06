function [h, labels] = graphXvYGeneric( ax, sample_data, vars )
%GRAPHXVYGENERIC Plots the given variable (x axis) against another 
% (y axis).
%
% Inputs:
%   ax          - Parent axis.
%   sample_data - The data set.
%   vars        - The variables to plot.
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
if ~isnumeric(vars),       error('var must be a numeric');        end

xdata = sample_data.variables{vars(1)}.data;
ydata = sample_data.variables{vars(2)}.data;

h = line(xdata, ydata);
set(ax, 'Tag', 'axis1D');

% for global/regional range display
mWh = findobj('Tag', 'mainWindow');
sMh = findobj('Tag', 'samplePopUpMenu');
iSample = get(sMh, 'Value');
climatologyRange = get(mWh, 'UserData');
if ~isempty(climatologyRange)
    if isfield(climatologyRange, ['rangeMin' sample_data.variables{vars(1)}.name])
        xLim = get(ax, 'XLim');
        line(climatologyRange(iSample).(['rangeMin' sample_data.variables{vars(1)}.name]), [sample_data.variables{vars(2)}.data(1); sample_data.variables{vars(2)}.data(end)], 'Parent', ax, 'Color', 'r');
        line(climatologyRange(iSample).(['rangeMax' sample_data.variables{vars(1)}.name]), [sample_data.variables{vars(2)}.data(1); sample_data.variables{vars(2)}.data(end)], 'Parent', ax, 'Color', 'r');
        set(ax, 'XLim', xLim);
    end
    if isfield(climatologyRange, ['rangeMin' sample_data.variables{vars(2)}.name])
        yLim = get(ax, 'YLim');
        line([sample_data.variables{vars(1)}.data(1); sample_data.variables{vars(1)}.data(end)], climatologyRange(iSample).(['rangeMin' sample_data.variables{vars(2)}.name]), 'Parent', ax, 'Color', 'r');
        line([sample_data.variables{vars(1)}.data(1); sample_data.variables{vars(1)}.data(end)], climatologyRange(iSample).(['rangeMax' sample_data.variables{vars(2)}.name]), 'Parent', ax, 'Color', 'r');
        set(ax, 'YLim', yLim);
    end
end

labels = {sample_data.variables{vars(1)}.name, sample_data.variables{vars(2)}.name};