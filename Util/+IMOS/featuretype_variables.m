function [variables] = featuretype_variables(featureType)
% function [variables] = featuretype_variables(featureType)
%
% Create the basic variables for a featureType.
%
% Inputs:
%
% featureType - The IMOS toolbox featureType.
%
% Outputs:
%
% variables - The basic variables required.
%
% Example:
%
% %basic timeSeries templating
% [basic_vars] = IMOS.featuretype_variables('timeSeries');
% assert(strcmp(basic_vars{1}.name,'TIMESERIES'));
% assert(isequal(basic_vars{1}.data,1))
% assert(strcmp(basic_vars{2}.name,'LATITUDE'))
% assert(isnan(basic_vars{2}.data))
% assert(strcmp(basic_vars{3}.name,'LONGITUDE'))
% assert(isnan(basic_vars{3}.data))
% assert(strcmp(basic_vars{4}.name,'NOMINAL_DEPTH'))
% assert(isnan(basic_vars{4}.data))
%
%
% author: hugo.oliveira@utas.edu.au
%
narginchk(1, 1)

if ~ischar(featureType)
    errormsg('First argument `featureType` must be a string')
end

ft = lower(featureType);

switch ft
    case 'timeseries'
        ts_names = {'TIMESERIES', 'LATITUDE', 'LONGITUDE', 'NOMINAL_DEPTH'};
        ts_types = cellfun(@getIMOSType, ts_names, 'UniformOutput', false);
        ts_data = {1, NaN, NaN, NaN};
        variables = IMOS.gen_variables(IMOS.gen_dimensions(ft), ts_names, ts_types, ts_data, 'comments', '');
    case 'ad_profile'
        p_names = {'TIME', 'DIRECTION', 'LATITUDE', 'LONGITUDE', 'BOT_DEPTH'};
        p_types = cellfun(@getIMOSType, p_names, 'UniformOutput', false);
        p_data = {NaN, {'A', 'D'}, [NaN NaN], [NaN NaN], [NaN NaN]};
        variables = IMOS.gen_variables(IMOS.gen_dimensions(ft), p_names, p_types, p_data, 'comments', '');
    case 'profile'
        p_names = {'PROFILE', 'TIME', 'DIRECTION', 'LATITUDE', 'LONGITUDE', 'BOT_DEPTH'};
        p_types = cellfun(@getIMOSType, p_names, 'UniformOutput', false);
        p_data = {1, NaN, {'D'}, NaN, NaN, NaN};
        variables = IMOS.gen_variables(IMOS.gen_dimensions(ft), p_names, p_types, p_data, 'comments', '');
    otherwise
        variables = {};
end

end
