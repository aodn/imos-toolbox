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

