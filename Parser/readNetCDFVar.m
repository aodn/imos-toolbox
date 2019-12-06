function v = readNetCDFVar(ncid, varid)
%READNETCDFVAR Creates a struct containing data for the given variable id.
%
% This function is able to import an IMOS compliant NetCDF file.
%
% Inputs:
%   v    - struct containing data for a given variable.
%
% Outputs:
%   ncid - netCDF file id.
%
%   varid - variable id in netCDF.
%
% Author:       Paul McCarthy <paul.mccarthy@csiro.au>
% Contributor : Guillaume Galibert <guillaume.galibert@utas.edu.au>
%               Gordon Keith <gordon.keith@csiro.au>

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
  narginchk(2,2);

  [name, xtype, dimids, natts] = netcdf.inqVar(ncid, varid);

  v                 = struct;
  v.name            = name;
  v.typeCastFunc    = str2func(netcdf3ToMatlabType(imosParameters(v.name, 'type')));
  v.dimensions      = dimids; % this is transformed below
  v.data            = netcdf.getVar(ncid, varid);
  
  % multi-dimensional data must be transformed, as matlab-netcdf api 
  % reverse dimensions order in variable when reading
  nDims = length(v.dimensions);
  if nDims > 1
      v.dimensions = fliplr(v.dimensions);
      v.data = permute(v.data, nDims:-1:1); 
  end

  if xtype == netcdf.getConstant('NC_CHAR') && length(dimids) > 1
      v.data = cellstr(v.data);
      v.dimensions(end) = [];
  end
  
  % get variable attributes
  atts = readNetCDFAtts(ncid, varid);
  attnames = fieldnames(atts);
  for k = 1:length(attnames), v.(attnames{k}) = atts.(attnames{k}); end
  
  % replace any fill values with matlab's NaN
  if isfield(atts, 'FillValue_') && iscell(v.data), atts = rmfield(atts, 'FillValue_'); end
  if isfield(atts, 'FillValue_'), v.data(v.data == atts.FillValue_) = v.typeCastFunc(NaN); end
end