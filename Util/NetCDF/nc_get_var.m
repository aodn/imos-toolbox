function [var] = nc_get_var(id,varname,varargin)
% function [var] = nc_get_var(id,varname,varargin)
%
% A wrapper to read a variable by its name
% with the netcdf matlab library.
%
% Inputs:
% 
% id [int] - the netcdf file id.
% varname [str] - the variable name.
% varargin [int] - Other netcdf.getVar args, like
%                  start,count,stride.
%
% Outputs:
% 
% var - the array.
%
%
% author: hugo.oliveira@utas.edu.au
%
try
	varid = netcdf.inqVarID(id,varname);
catch err
	err = addCause(err,MException(err.identifier,'%s: %s Variable name not found.',mfilename,varname));
	throw(err);
end

try
	var = netcdf.getVar(id,varid,varargin{:});
catch err
	err = addCause(err,MException(err.identifier,'%s: invalid getVar arguments for %s Variable',mfilename,varname));
	throw(err);
end

end
