function [depth] = site_bathymetry(sample_data, oper)
%function [depth] = site_bathymetry(sample_data, oper)
%
% Disambiguate the site bathymetry from a sample
%
% Inputs:
%
% sample_data [struct] - the toolbox struct
% oper [function handle] - a function handle to operate on
%                         the different estimates if any.
%                         Default: @min
%
% Outputs:
%
% depth [numeric] - the bathymetry value
%
%
% Example:
% sample_data.site_nominal_depth = [];
% sample_data.site_depth_at_deployment = [];
% assert(isempty(IMOS.meta.get_site_bathymetry(sample_data)))
% sample_data.site_nominal_depth = 20;
% assert(IMOS.meta.get_site_bathymetry(sample_data)==20)
% sample_data.site_depth_at_deployment = 10;
% assert(IMOS.meta.get_site_bathymetry(sample_data)==10)
%
% author: hugo.oliveira@utas.edu.au
%
%
narginchk(1, 2)

if ~isstruct(sample_data)
    errormsg('Not a struct')
end

if nargin == 1
    oper = @min;
else

    if ~isfunctionhandle(oper)
        errormsg('Second argument not a function handle')
    end

end

try
    b1 = sample_data.site_depth_at_deployment;
catch
    b1 = [];
end

try
    b2 = sample_data.site_nominal_depth;
catch
    b2 = [];
end

if isempty(b1)
    b1 = b2;
end

if isempty(b2)
    b2 = b1;
end

depth = oper(b1, b2);

end
