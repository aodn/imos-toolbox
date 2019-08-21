function [itype, is_nested, nested] = detectStructContent(arg1);
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
