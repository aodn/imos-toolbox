function [stype, root, nrec] = createTree(arg1, stype, name, nrec, func),
    % function [stype, root, nrec] = createTree(arg1, stype, name, nrec, func),
    % A function to recursively apply a function handler @func,
    % to all fields of an argument.
    % the function generate the exact same type of arg1,
    % visiting/applying @func through all nested structures (cells/structs)
    %
    % `arg1` = a matlab variable
    % stype = the parent structure - internal use
    % name = the name of this walk level - internal use
    % nrec = the level of this walk level - internal use
    % func = a special function handle that return 3 outputs - see DetectType
    % <->
    % stype = the result structure with follow-up nests/walks.
    % root = is the result of @func for the root level of arg1.
    % nrec = is the number of children visits.
    %
    % author: hugo.oliveira@utas.edu.au
    if nargin < 2,
        stype = struct();
        name = 'root';
        nrec = -1;
        func = @detectType;
    elseif nargin < 3,
        name = 'root';
        nrec = -1;
        func = @detectType;
    elseif nargin < 4,
        nrec = -1;
        func = @detectType;
    elseif nargin < 5,
        func = @detectType;
    end

    stack = dbstack;
    selfname = stack.name;
    self = str2func(selfname);

    iname = name;

    [stype, is_nested, nested_keys] = func(arg1);
    first_level = stype;

    if is_nested,

        if isstruct(stype),
            fnames = fields(stype);
            nested_names = fnames(nested_keys);

            for k = 1:length(nested_names),

                kname = nested_names{k};
                data = arg1.(kname);
                [stype.(kname), root, nrec] = self(data, stype, kname, nrec - 1, func);
            end

        elseif iscell(stype),

            for k = 1:length(nested_keys),
                data = arg1{k};
                [stype{k}, root, nrec] = self(data, stype, iname, nrec - 1, func);
            end

        end

    end

    %adjust nrec and root
    if strcmpi(iname, 'root'),
        nrec = abs(nrec) - 1;
    end
    root = first_level;

end
