function [param] = get_random_param(param_name)
% function [param] = get_random_param(param_name)
%
% Get a random IMOS parameter index.
%
% Inputs:
%
% param_name - the parameter name. See IMOS.param.
%
% Outputs:
%
% param - A random item.
%
% Example:
%
% valid_entry = @(x)(~isempty(x) && ischar(x));
% assert(valid_entry(IMOS.random.get_random_param('name')))
% assert(valid_entry(IMOS.random.get_random_param('long_name')))
% assert(valid_entry(IMOS.random.get_random_param('netcdf_ctype')))
%
% author: hugo.oliveira@utas.edu.au
%
narginchk(1, 1)

if ~ischar(param_name)
    error('First argument is not a char')
end

imosparams = IMOS.params();
available_names = fieldnames(imosparams);

if ~inCell(available_names, param_name)
    errormsg('IMOS parameter %s does not exist', param_name)
end

all_values = unique(imosparams.(param_name));
rind = random_between(1, numel(all_values), 1, 'int');
param = all_values{rind};
end
