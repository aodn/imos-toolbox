function sam = addVar(sam, name, data, dimensions, comment, coordinates)
%ADDVAR Adds a new variable to the given data set.
%
% Adds a new variable with the given name, data, dimensions and commment to
% the given data set.
%
% Inputs:
%   sam        - data set to which the new variable is added
%   name       - new variable name
%   data       - variable data
%   dimensions - variable dimensions
%   comment    - variable comment
%   coordinates- variable coordinates
%
% Outputs:
%   sam        - data set  with the new variable added.
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
narginchk(6, 6);

if ~isstruct(sam),          error('sam must be a struct');        end
if ~ischar(name),           error('name must be a string');       end
if ~isnumeric(data),        error('data must be a matrix');       end
if ~isvector(dimensions),   error('dimensions must be a vector'); end
if ~ischar(comment),        error('comment must be a string');    end
if ~ischar(coordinates),    error('coordinates must be a string');end

qcSet   = str2double(readProperty('toolbox.qc_set'));
rawFlag = imosQCFlag('raw', qcSet, 'flag');

% add new variable to data set
sam.variables{end+1}.name           = name;
sam.variables{end  }.typeCastFunc   = str2func(netcdf3ToMatlabType(imosParameters(sam.variables{end}.name, 'type')));
sam.variables{end  }.dimensions     = dimensions;
sam.variables{end  }.data           = sam.variables{end  }.typeCastFunc(data);
clear data;
if ~isempty(coordinates)
    sam.variables{end  }.coordinates = coordinates;
end

% create an empty flags matrix for the new variable
sam.variables{end}.flags(1:numel(sam.variables{end}.data)) = rawFlag;
sam.variables{end}.flags = reshape(...
  sam.variables{end}.flags, size(sam.variables{end}.data));
  
% ensure that the new variable is populated  with all 
% required NetCDF  attributes - all existing fields are 
% left unmodified by the makeNetCDFCompliant function
sam = makeNetCDFCompliant(sam);

if isfield(sam.variables{end  }, 'comment')
    sam.variables{end  }.comment       = comment;
end
  