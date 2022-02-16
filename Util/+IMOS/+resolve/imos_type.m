function [itype] = imos_type(imos_name)
% function [itype] = imos_type(imos_name)
%
% Resolve an IMOS data type function handle
% based on its name.
%
% If the name is not an IMOS dimension/variable name,
% an error is raised.
%
% Inputs:
%
% imos_name [str] - an IMOS variable name to use
%                 in the resolution of the type.
%
% Outputs:
%
% itype [function_handle] - the resolved function handle.
%
% Example:
%
% %basic
% assert(isequal(IMOS.resolve.imos_type('TIME'),@double));
%
% %imos_name missing
% f=false;try;IMOS.resolve.imos_type('ABC');catch;f=true;end;
% assert(f)
%
%
% author: hugo.oliveira@utas.edu.au
%
narginchk(1, 1)

if ~ischar(imos_name)
    errormsg('First argument is not a valid string')
end

params = IMOS.params();

[is_numbered,base_name] = IMOS.resolve.is_numbered_var(imos_name);

if is_numbered
    imos_name = base_name;
end

[name_exist, name_ind] = inCell(params.name, imos_name);

if ~name_exist
    errormsg('Name %s is missing within the imosParameter table.', imos_name)
else
    itype = str2func(netcdf3ToMatlabType(params.netcdf_ctype{name_ind}));
end

end