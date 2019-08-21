function [itype, is_nested, nested] = detectCellContent(arg1);
    csize = size(arg1);
    n = numel(arg1);
    if n>0,
        itype = cell(csize);
    else
        itype = cell(0,0);
    end
    
    is_nested = false;
    nested = logical(zeros(csize));
    for k = 1:n,
        [t] = detectType(arg1{k});

        if isstruct(t),
            itype{k} = @isstruct;
            is_nested = true;
            nested(k) = true;
        elseif iscell(t),
            itype{k} = @iscell;
            is_nested = true;
            nested(k) = true;
        else
            itype{k} = t;
        end

    end

end
