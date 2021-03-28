function [pdata] = params()
% function [pdata] = params()
%
% Load the entire imosParameters
% as a structure of cells.
%
% Inputs:
%
% Outputs:
%
% pdata [struct[cells]] - A struct with the of IMOS parameters
%
% Example:
%
% assert(iscell(IMOS.params().name))
% assert(ischar(IMOS.params().name{1}))
% assert(ischar(IMOS.params().data_code{1}))
% assert(ischar(IMOS.params().netcdf_ctype{1}))
%
% author: hugo.oliveira@utas.edu.au
%
narginchk(0, 0)
persistent params;

if isempty(params)
    param_file = [toolboxRootPath 'IMOS/imosParameters.txt'];
    fid = fopen(param_file, 'rt');

    if fid == -1
        error('Couldn''t read  imosParameters.txt file')
    end

    try
        params = textscan(fid, '%s%d%s%s%s%s%s%f%f%f%s', ...
            'delimiter', ',', 'commentStyle', '%');
        fclose(fid);
    catch e
        error('Invalid entry found in imosParameters.txt')
    end

end

pdata.name = params{1};
pdata.is_cf_parameter = num2cell(logical(params{2}));
pdata.long_name = params{3};

pdata.units = params{4};
is_percent = @(x)(strcmp(x, 'percent'));
ind_percent = find(cellfun(is_percent, params{4}));

for k = 1:numel(ind_percent)
    pdata.units{k} = '%';
end

pdata.direction_positive = params{5};
pdata.reference_datum = params{6};
pdata.data_code = params{7};
pdata.fill_value = num2cell(params{8});
pdata.valid_min = num2cell(params{9});
pdata.valid_max = num2cell(params{10});
pdata.netcdf_ctype = params{11};

end
