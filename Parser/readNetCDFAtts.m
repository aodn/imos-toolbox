function atts = readNetCDFAtts(ncid, varid)
%READNETCDFATTS Gets all of the NetCDF attributes from the given file/variable.
%
% This function is able to import an IMOS compliant NetCDF file.
%
% Inputs:
%   atts  - strcut containing data for a given variable.
%
% Outputs:
%   ncid  - netCDF file id.
%
%   varid - variable id in netCDF.
%
% Author:       Paul McCarthy <paul.mccarthy@csiro.au>
% Contributor : Guillaume Galibert <guillaume.galibert@utas.edu.au>

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

  atts = struct;
  k    = 0;

  try 
    while 1
      
      % inqAttName will throw an error when we run out of attributes
      name = netcdf.inqAttName(ncid, varid, k);
      sName = name;
      
      % no-leading-underscore kludge
      if sName(1) == '_', sName = [sName(2:end) '_']; end
      
      atts.(sName) = netcdf.getAtt(ncid, varid, name);
      k = k + 1;
      
    end
  catch e 
  end
end