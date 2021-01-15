function [variables] = gen_variables(dimensions, v_names, v_types, v_data, varargin)
% function [variables] = gen_variables(dimensions,v_names, v_types,v_data,varargin)
%
% Generate a toolbox variable cell of structs. Empty or incomplete
% arguments will trigger random (names/types) or empty entries (data).
%
% Inputs:
%
% dimensions - a toolbox dimension cell.
% v_names - a cell of variable names. If cell is empty or
%           out-of-bounds, a random entry is used.
% v_types - a cell of MATLAB function handles types.
%           If name of variable is an IMOS parameter name,
%           the respective imos type is used, otherwise
%           a random type is used.
% v_data -  a cell with the variable array values. ditto as in v_names.
% varargin - extra fieldname,fieldvalue to add to each variable.
%            for example: 'comment','test' -> variables.comment = test.
%
% Outputs:
%
% variables - The variable cell.
%
% Example:
% %basic usage
% tsdims = IMOS.gen_dimensions('timeSeries');
% tsvars = IMOS.gen_variables(tsdims);
% assert(iscellstruct(tsvars))
% assert(strcmp(tsvars{1}.name,'TIMESERIES'))
% assert(tsvars{1}.data==1)
% assert(strcmp(tsvars{2}.name,'LATITUDE'))
% assert(strcmp(tsvars{end}.name,'NOMINAL_DEPTH'))
%
% % profile
% pdims = IMOS.gen_dimensions('profile');
% pvars = IMOS.gen_variables(pdims);
% assert(iscellstruct(pvars))
% assert(strcmp(pvars{1}.name,'PROFILE'))
% assert(pvars{1}.data==1)
% assert(strcmp(pvars{2}.name,'TIME'))
% assert(isequal(pvars{2}.typeCastFunc,@double))
% assert(isempty(pvars{2}.dimensions)) %empty by design
% assert(isnan(pvars{2}.data)) %nan by design
% assert(strcmp(pvars{3}.name,'DIRECTION'))
% assert(isequal(pvars{3}.typeCastFunc,@char))
% assert(isequal(pvars{3}.data,{'D'}))
%
% %misc usage
% mydims = IMOS.gen_dimensions('timeSeries',2,{'TIME','X'},{},{zeros(60,1),[1:10]'},'comment','123');
% variables = IMOS.gen_variables(mydims,{'Y','Z','VALID'},{@double,@int32,@logical},{ones(10,1),zeros(60,1),1});
% %one-to-one
% assert(strcmp(variables{1}.name,'Y'))
% assert(isequal(variables{1}.typeCastFunc,@double))
% assert(isequal(variables{1}.data,ones(10,1)))
% assert(isequal(variables{1}.dimensions,2))
% assert(isempty(variables{1}.comment))
% %missing dims of variable vectors are assigned to empty and data is typecast
% assert(strcmp(variables{end}.name,'VALID'))
% assert(isequal(variables{end}.typeCastFunc,@logical))
% assert(isequal(variables{end}.data,true))
% assert(isempty(variables{end}.dimensions))
% assert(isempty(variables{end}.comment))
%
% %missing dimensions on multi-dimensional variable arrays trigger an error
% names = {'INVALID_COLUMN','INVALID_ROW','INVALID_MULTIARRAY'};
% data = {ones(1,3),ones(3,1),ones(33,60)};
% try;IMOS.gen_variables(mydims,names,{},data);catch;r=true;end;
% assert(r)
%
%
% author: hugo.oliveira@utas.edu.au
%
if nargin == 0
    errormsg('Missing toolbox dimensions cell argument')
end

if nargin > 1 && ~IMOS.is_toolbox_dimcell(dimensions)
    errormsg('First argument `dimensions` is not a toolbox dimensions cell')
elseif nargin > 2 && ~iscell(v_names)
    errormsg('Second argument `v_names` is not a cell')
elseif nargin > 3 && ~iscell(v_types)
    errormsg('Third argument `v_types` is not a cell')
elseif nargin > 4 && ~iscell(v_data)
    errormsg('Fourth argument `v_data` is not acell')
end

is_timeseries = getVar(dimensions, 'TIME') == 1;
is_ad_profile = ~is_timeseries && getVar(dimensions, 'MAXZ') && getVar(dimensions, 'PROFILE');
is_single_profile = ~is_timeseries && ~is_ad_profile && getVar(dimensions, 'DEPTH');

if nargin < 2 && is_timeseries
    variables = IMOS.featuretype_variables('timeSeries');
elseif nargin < 2 && is_ad_profile
    variables = IMOS.featuretype_variables('ad_profile');
elseif nargin < 2 && is_single_profile
    variables = IMOS.featuretype_variables('profile');
else
    variables = {};
end

if nargin < 2
    return
end

if isempty(varargin)
    varargin = {'comment', ''};
end

ns = numel(variables);
ndata = numel(v_names);
variables{ndata} = {};

for k = ns + 1:ndata

    try
        name = v_names{k};
    catch
        name = random_names(1);
        name = name{1};
    end

    try
        imos_type = v_types{k};
    catch

        try
            imos_type = IMOS.resolve.imos_type(name);
        catch
            imos_type = IMOS.random.imos_type();
        end

    end

    try
        data = v_data{k};
    catch
        data = [];
    end

    if isstring(data) || iscellstr(data)
        is_profile = strcmp(dimensions{1}.name, 'DEPTH');

        if is_profile
            dim_indexes = [];
        else
            dim_indexes = 2;
        end

        data = {data}; %wrap in double-cell for struct assignment.
        variables{k} = struct('name', name, 'typeCastFunc', imos_type, 'dimensions', dim_indexes, 'data', data, varargin{:});
    else
        dim_indexes = IMOS.discover_data_dimensions(data, dimensions);
        variables{k} = struct('name', name, 'typeCastFunc', imos_type, 'dimensions', dim_indexes, 'data', imos_type(data), varargin{:});
    end

end

end
