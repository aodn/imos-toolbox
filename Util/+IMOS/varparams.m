function [vparams] = varparams()
% function [vparams] =  varparams()
%
% Load a variable named structure
% containing all IMOS parameters.
%
% Inputs:
%
% Outputs:
%
% vparams [struct] - A struct with the of IMOS parameters.
%
% Example:
%
% %basic
% varinfo = IMOS.varparams();
% assert(isequal(varinfo.VDIR.name,'VDIR'))
% assert(isequal(varinfo.VDIR.is_cf_parameter,true))
% assert(isequal(varinfo.VDIR.long_name,varinfo.VDIR.standard_name))
% assert(isequal(varinfo.VDIR.long_name,'sea_surface_wave_from_direction'))
% assert(isequal(varinfo.VDIR.units,'degree'))
% assert(isequal(varinfo.VDIR.direction_positive,'clockwise'))
% assert(isequal(varinfo.VDIR.reference_datum,'true north'))
% assert(isequal(varinfo.VDIR.data_code,'W'))
% assert(isequal(varinfo.VDIR.fill_value,999999))
% assert(isequal(varinfo.VDIR.valid_min,0))
% assert(isequal(varinfo.VDIR.valid_max,360))
% assert(isequal(varinfo.VDIR.netcdf_ctype,'float'))
%
% % type checking
% assert(isstruct(IMOS.varparams()))
% assert(isstruct(IMOS.varparams().TIME))
% assert(ischar(IMOS.varparams().TIME.name))
% assert(islogical(IMOS.varparams().TIME.is_cf_parameter))
% assert(ischar(IMOS.varparams().TIME.units))
% assert(ischar(IMOS.varparams().TIME.direction_positive))
% assert(ischar(IMOS.varparams().TIME.reference_datum))
% assert(ischar(IMOS.varparams().TIME.data_code))
% assert(isnumeric(IMOS.varparams().TIME.fill_value))
% assert(isnumeric(IMOS.varparams().TIME.valid_min))
% assert(isnumeric(IMOS.varparams().TIME.valid_max))
% assert(ischar(IMOS.varparams().TIME.netcdf_ctype))
%
% % non-cf entry
% assert(~IMOS.varparams().PERG1.is_cf_parameter)
% assert(~isempty(IMOS.varparams().PERG1.long_name))
% assert(isempty(IMOS.varparams().PERG1.standard_name))
%
%
% author: hugo.oliveira@utas.edu.au
%
narginchk(0, 0)

iparams = IMOS.params();

fvalues = struct2cell(iparams);
fnames = fieldnames(iparams);
varnames = iparams.name;

for k = 1:length(varnames)
    varname = varnames{k};

    for kk = 1:length(fnames)
        fname = fnames{kk};
        fvalue = fvalues{kk}{k};
        vparams.(varname).(fname) = fvalue;
    end

    if vparams.(varname).is_cf_parameter
        vparams.(varname).('standard_name') = vparams.(varname).('long_name');
    else
        vparams.(varname).('standard_name') = '';
    end

end

end
