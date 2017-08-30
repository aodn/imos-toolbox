function [graphs, lines, vars] = graphTransect( parent, sample_data, vars, extra_sample_data )
%GRAPHTRANSECT Graphs the given data in a 2D transect manner, using subplot.
%
% Inputs:
%   parent             - handle to the parent container.
%   sample_data        - struct containing sample data.
%   vars               - Indices of variables that should be graphed.
%   extra_sample_data  - struct containing extra sample data.
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
  narginchk(4,4);
  
  if ~ishandle( parent),                error('parent must be a handle');                       end
  if ~isstruct( sample_data),           error('sample_data must be a struct');                  end
  if ~isnumeric(vars),                  error('vars must be a numeric');                        end
  if ~isstruct(extra_sample_data) && ...
          ~isempty(extra_sample_data),  error('extra_sample_data must be a struct or empty');   end
  
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
                   'Color',  'none',...
                   'YGrid',  'on', ...
                   'ZGrid',  'on');
    
    % plot the variable
    plotFunc             = getGraphFunc('Transect', 'graph', name);
    [lines(k,:), labels] = plotFunc(graphs(k), sample_data, vars(k));
    
    % set labels
    set(get(graphs(k), 'XLabel'), 'String', labels{1}, 'Interpreter', 'none');
    set(get(graphs(k), 'YLabel'), 'String', labels{2}, 'Interpreter', 'none');
  end
  
  % link axes for panning/zooming
  try linkaxes(graphs, 'xy');
  catch e
  end
end
