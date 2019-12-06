function flags = flagTransect( parent, graphs, sample_data, vars )
%FLAGTRANSECT Overlays flags for the given sample data variables on the 
% given transect graphs.
%
% Inputs:
%   parent      - handle to parent figure/uipanel.
%   graphs      - vector handles to axis objects (one for each variable).
%   sample_data - struct containing the sample data.
%   vars        - vector of indices into the sample_data.variables array.
%                 Must be the same length as graphs.
%
% Outputs:
%   flag        - handles to line objects that make up the flag overlays.
%
% Author: Paul McCarthy <paul.mccarthy@csiro.au>
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

if ~ishandle(parent),      error('parent must be a graphic handle');    end
if ~ishandle(graphs),      error('graphs must be a graphic handle(s)'); end
if ~isstruct(sample_data), error('sample_data must be a struct');       end
if ~isnumeric(vars),       error('vars must be a numeric');             end

flags = [];

if isempty(vars), return; end

% fail if there is no latitude/longitude data
lat = getVar(sample_data.variables, 'LATITUDE');
lon = getVar(sample_data.variables, 'LONGITUDE');

if lat == 0 || lon == 0
  error('data set contains no latitude/longitude data'); 
end

vars(vars == lat) = [];
vars(vars == lon) = [];
if isempty(vars), return; end

hold on;

for k = 1:length(vars)
  
  % apply the flag function for this variable
  flagFunc = ...
    getGraphFunc('Transect', 'flag', sample_data.variables{vars(k)}.name);
  f = flagFunc(graphs(k), sample_data, vars(k));
  
  % if the flag function returned nothing, insert a dummy handle 
  if isempty(f), f = 0.0; end
  
  %
  % the following is some ugly code which takes the flag handle(s) returned
  % from the variable-specific flag function, and saves it/them in the 
  % flags matrix, accounting for differences in size.
  %
  
  fl = length(f);
  fs = size(flags,2);
  
  if     fl > fs, flags(:,fs+1:fl) = 0.0;
  elseif fl < fs, f    (  fl+1:fs) = 0.0;
  end
  
  flags(k,:) = f;
end
