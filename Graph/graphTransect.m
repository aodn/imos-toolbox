function [graphs lines vars] = graphTransect( parent, sample_data, vars )
%GRAPHTRANSECT Graphs the given data in a 2D transect manner, using subplot.
%
% Inputs:
%   parent             - handle to the parent container.
%   sample_data        - struct containing sample data.
%   vars               - Indices of variables that should be graphed..
%
% Outputs:
%   graphs             - A vector of handles to axes on which the data has 
%                        been graphed.
%   lines              - A matrix of handles to line or surface (or other) 
%                        handles which have been drawn, the same length as 
%                        graphs.
%   vars               - Indices of variables which were graphed.
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
  narginchk(3,3);
  
  if ~ishandle( parent),       error('parent must be a handle');      end
  if ~isstruct( sample_data),  error('sample_data must be a struct'); end
  if ~isnumeric(vars),         error('vars must be a numeric');       end
  
  graphs = [];
  lines  = [];
    
  if isempty(vars)
    warning('no variables to graph');
    return; 
  end
  
  % make sure the data set contains latitude and longitude data
  lat = getVar(sample_data.variables, 'LATITUDE');
  lon = getVar(sample_data.variables, 'LONGITUDE');
  
  if lat == 0 || lon == 0
    error('data set contains no latitude/longitude data'); 
  end
  
  % ignore request to plot lat/lon against themselves
  iLat = vars == lat;
  iLon = vars == lon;
  if any(iLat), vars(iLat) = []; end
  if any(iLon), vars(iLon) = []; end
  
  if isempty(vars)
    warning('no variables to graph');
    return; 
  end
  
  for k = 1:length(vars)
    
    name = sample_data.variables{vars(k)}.name;
    
    % create the axes
    graphs(k) = subplot(1, length(vars), k);
    
    set(graphs(k), 'Parent', parent,...
                   'XGrid',  'on',...
                   'Color', 'none',...
                   'YGrid',  'on', ...
                   'ZGrid',  'on');
    
    % plot the variable
    plotFunc            = getGraphFunc('Transect', 'graph', name);
    [lines(k,:) labels] = plotFunc(   graphs(k), sample_data, vars(k));
    
    % set labels
    set(get(graphs(k), 'XLabel'), 'String', labels{1}, 'Interpreter', 'none');
    set(get(graphs(k), 'YLabel'), 'String', labels{2}, 'Interpreter', 'none');
  end
  
  % link axes for panning/zooming
  try linkaxes(graphs, 'xy');
  catch e
  end
end
