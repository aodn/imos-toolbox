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