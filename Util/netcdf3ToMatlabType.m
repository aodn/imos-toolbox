function [ matlabType ] = netcdf3ToMatlabType( netcdfType )
%NETCDF3TOMATLABTYPE gives the equivalent Matlab type to the given NetCDF
%type.
%
% This function translates any NetCDF 3.6.0 C data type into the equivalent
% Matlab data type. 
% See http://www.unidata.ucar.edu/software/netcdf/docs/netcdf-c/Variable-Types.html#Variable-Types
% and http://www.unidata.ucar.edu/software/netcdf/old_docs/docs_3_6_2/netcdf/netCDF-external-data-types.html
% for more information.
%
% Inputs:
%
%   netcdfType  - a netCDF 3.6.0 C data type expressed in a String. Values can be 'char', 'byte',
%               'short', 'int', 'float' or 'double'
%
% Outputs:
%   matlabType  - a Matlab data type expressed in a String.
%
% Author: Guillaume Galibert <guillaume.galibert@utas.edu.au>
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
narginchk(1,1);

if ~ischar(netcdfType),        error('netcdfType must be a string');  end

% see http://www.unidata.ucar.edu/software/netcdf/docs/netcdf-c/Variable-Types.html#Variable-Types
netcdfPossibleValues = {'char', 'byte', 'short', 'int', 'float', 'double'};
if ~any(strcmpi(netcdfType, netcdfPossibleValues))
    error(['netcdfType must be any of these values : ' cellCons(netcdfPossibleValues, ', ') '.']);
end

% see http://www.unidata.ucar.edu/software/netcdf/old_docs/docs_3_6_2/netcdf/netCDF-external-data-types.html
switch netcdfType
    case 'char',    matlabType = 'char';
    case 'byte',    matlabType = 'int8';
    case 'short',   matlabType = 'int16';
    case 'int',     matlabType = 'int32';
    case 'float',   matlabType = 'single';
    case 'double',  matlabType = 'double';
end

end

