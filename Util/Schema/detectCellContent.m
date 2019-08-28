function [itype, is_nested, nested] = detectCellContent(arg1);
    % function [itype, is_nested, nested] = detectCellContent(arg1);
    % This detect the content of a cell at root level
    % `arg1` - a cell variable argument
    % <->
    % `itype` - a cell of the same size of arg1 with the items types
    % `is_nested` - a boolean indicating there are more nested levels within (cell/structs)
    % `nested` - an array of booleans to indicate which items/indexes are cell/structs
    %
    % author: hugo.oliveira@utas.edu.au
    %
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
        obj = arg1{k};

        if isstruct(obj),
            itype{k} = @isstruct;
            is_nested = true;
            nested(k) = true;
        elseif iscell(obj),
            itype{k} = @iscell;
            is_nested = true;
            nested(k) = true;
        else
            itype{k} = detectType(obj);
        end

    end

end
