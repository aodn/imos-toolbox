function [itype, is_nested, nested] = detectStructContent(arg1);
    % function [itype, is_nested, nested] = detectStructContent(arg1);
    % This detect the content of a struct at root level
    % `arg1` - a struct variable argument
    % <->
    % `itype` - a struct of the same size of arg1 with the field types
    % `is_nested` - a boolean indicating there are more nested levels within (cell/structs)
    % `nested` - an array of booleans to indicate which fields are cell/struct
    %
    % author: hugo.oliveira@utas.edu.au
    %

    is_nested = false;
    names = fields(arg1);
    n = numel(arg1);
    if n == 1,
        itype = struct();
    else
        % `abc(size) = struct()` doesn't work for len(size)>2;
        itype(n) = struct();
        itype = reshape(itype,size(arg1));
    end
    m = length(names);
    itype = struct();

    nested = logical(zeros(0, 0));

    for k = 1:n
        for kk = 1:m,
            name = names{kk};
            [t] = detectType(arg1.(name));

            if isstruct(t),
                itype(k).(name) = @isstruct;
                is_nested = true;
                nested(k,kk) = true;
            elseif iscell(t),
                itype(k).(name) = @iscell;
                is_nested = true;
                nested(k,kk) = true;
            else
                itype(k).(name) = t;
            end

        end
    end

end
