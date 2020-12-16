function [rtype] = imos_type
% function [rtype] = imos_type
%
% Generate a random imos type function handle
%
% Inputs:
%
% Outputs:
%
% rtype [function_handle] - the function handle of the type.
%
% Example:
%
% assert(isa(IMOS.random.imos_type,'function_handle'))
%
% author: hugo.oliveira@utas.edu.au
%
rtype = str2func(netcdf3ToMatlabType(IMOS.random.get_random_param('netcdf_ctype')));
end
