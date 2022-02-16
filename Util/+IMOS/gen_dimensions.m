function dimensions = gen_dimensions(mode, ndims, d_names, d_types, d_datac, varargin)
%function dimensions = gen_dimensions(mode, ndims, d_names, d_types, d_datac, varargin)
%
% Generate a toolbox dimension cell of structs. Empty or incomplete
% arguments will trigger random (names/types) or empty entries (data).
%
% Inputs:
%
%  mode [str] - ['timeSeries','profile','adcp'].
%  If empty, 'timeSeries' is used.
%
%  ndims [int] - number of dimensions.
%  If empty, 1 is used.
%
%  d_names [cell{str}] - dimension names.
%  If empty, randomized named.
%
%  d_types [cell{@funciton_handle}] - dimension types
%  If d_names matches a toolbox variable, the variable type
%  will be used, othewise randomized type is used.
%
%  d_datac [cell{any}] - dimension data. Ditto as in d_names.
%
%  varargin - extra parameters are cast to all structure fieldnames.
%
% Outputs:
%
%  d - a cell with dimensions structs.
%
% Example:
%
% %basic construct
% dimensions = IMOS.gen_dimensions('timeSeries',1,{'TIME'},{@double},{[1:10]'},'calendar','gregorian','start_offset',10);
% tdim = dimensions{1};
% assert(isequal(tdim.name,'TIME'))
% assert(isequal(tdim.typeCastFunc,@double))
% assert(all(isequal(tdim.data,[1:10]')));
% assert(strcmp(tdim.calendar,'gregorian'));
% assert(tdim.start_offset==10);
%
% %fill missing dimension spec with random stuff
% dimensions = IMOS.gen_dimensions('timeSeries',2,{'TIME'},{},{[1:100]'},'calendar','xxx');
% tdim = dimensions{1};
% assert(isequal(tdim.data,[1:100]'))
% newdim = dimensions{2};
% assert(ischar(newdim.name));
% assert(isfunctionhandle(newdim.typeCastFunc))
% assert(isequal(newdim.data,[]));
%
% %raise error when same dimension name is used
% try;IMOS.gen_dimensions('timeSeries',3,{'A','B','A'});catch;r=true;end;
% assert(r);
%
%
% author: hugo.oliveira@utas.edu.au
%
if nargin == 0
    mode = 'timeSeries';
elseif nargin > 1 && ~ischar(mode)
    errormsg('First argument `mode` must be the toolbox mode.')
elseif nargin > 2 && ~isindex(ndims)
    errormsg('Second argument `ndims` must be a valid number of dimensions.')
elseif nargin > 3 && ~iscell(d_names)
    errormsg('Third argument `d_names` must be a cell.')
elseif nargin > 4 && ~iscell(d_types)
    errormsg('Fourth argument `d_types` must be a cell.')
elseif nargin > 5 && ~iscell(d_datac)
    errormsg('Fifth argument `d_datac` must be a cell.')
end

try
    got_any_name = numel(d_names) > 0;
catch
    got_any_name = false;
end

if got_any_name
    unames = union(d_names, d_names);
    names_not_unique = ~isequal(unames, sort(d_names));
    if names_not_unique
        repeat_indexes = allrepeats(whereincell(unames, d_names));
        repeated_names = d_names(repeat_indexes);
        repeated_names = union(repeated_names, repeated_names);
        rfmt = repmat('`%s`,', 1, numel(repeated_names));
        rfmt(end) = '.';
        errormsg(['Invalid dimensions content. Dimensions not unique: ' rfmt], repeated_names{:});
    end

end

if nargin < 2
    try
        dimensions = IMOS.templates.dimensions.(mode);
        return
    catch
        ndims = 1;
        d_names = randomNames();
        d_types = randomNumericTypefun();
        typecast = d_types{1};
        d_datac = {typecast(randn(1, 100))};
    end

end

dimensions = cell(1, ndims);

for k = 1:ndims

    try
        name = d_names{k};
    catch

        try
            dimensions{k} = IMOS.templates.dimensions.(mode){k};
            continue;
        catch
            name = randomNames(1);
            name = name{1};
        end

    end

    try
        type = d_types{k};
    catch

        try
            type = IMOS.resolve.imos_type(name);
        catch
            type = IMOS.random.imos_type();
        end

    end

    try
        data = d_datac{k};
    catch
        data = [];
    end

    if ~isnumeric(data)
        errormsg('%s dimension data is not numeric.', name)
    end

    if ~isempty(data) && ~isscalar(data)

        if isrow(data)
            fprintf('IMOS.%s: Transposing %s dimension at index=%d from row to column vector\n', mfilename, name, k);
            data = data';
        elseif ~iscolumn(data)
            errormsg('%s dimension data at index=%d is not a vector.', name, k);
        end

    end

    dimensions{k} = struct('name', name, 'typeCastFunc', type, 'data', data, varargin{:});
end

end
