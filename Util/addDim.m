function sam = addDim(sam, name, data, comment)
%ADDDIM Adds a new dimension to the given data set.
%
% Adds a new variable with the given name, data and commment to
% the given data set.
%
% Inputs:
%   sam        - data set to which the new dimension is added
%   name       - new dimension name
%   data       - dimension data
%   comment    - dimension comment
%
% Outputs:
%   sam        - data set  with the new dimension added.
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

if ~isstruct( sam),        error('sam must be a struct');        end
if ~ischar(   name),       error('name must be a string');       end
if ~isnumeric(data),       error('data must be a matrix');       end
if ~ischar(   comment),    error('comment must be a string');    end

qcSet   = str2double(readProperty('toolbox.qc_set'));
rawFlag = imosQCFlag('raw', qcSet, 'flag');

% add new dimension to data set
sam.dimensions{end+1}.name           = name;
sam.dimensions{end  }.typeCastFunc   = str2func(netcdf3ToMatlabType(imosParameters(sam.dimensions{end}.name, 'type')));
sam.dimensions{end  }.data           = sam.dimensions{end}.typeCastFunc(data);
clear data;

% create an empty flags matrix for the new dimension
sam.dimensions{end}.flags(1:numel(sam.dimensions{end}.data)) = rawFlag;
sam.dimensions{end}.flags = reshape(...
  sam.dimensions{end}.flags, size(sam.dimensions{end}.data));
  
% ensure that the new dimension is populated  with all 
% required NetCDF  attributes - all existing fields are 
% left unmodified by the makeNetCDFCompliant function
sam = makeNetCDFCompliant(sam);

if isfield(sam.dimensions{end}, 'comment')
    sam.dimensions{end}.comment      = comment;
end
  