function [itype, is_nested, nested_keys, rtype] = detectType(arg1),
    % function [itype, is_nested, nested_keys, rtype] = detectType(arg1),
    % return several useful information about a matlab type
    %  
    % `arg1` - any type/variable.
    % <->
    % `itype` - a function handle that defines the the type of arg1
    % or a cell/struct with the function handle that defines the items within.
    % `is_nested` - a singleton boolean indicating if the argument is nested
    % `nested_keys` - a boolean array indicating which items in the argument are nested
    % `rtype` - the actual type of the argument
    %
    % author: hugo.oliveira@utas.edu.au
    is_nested = false;
    nested_keys = logical(zeros(0, 0));

    if iscell(arg1),
        rtype = 'cell';
        [itype, is_nested, nested_keys] = detectCellContent(arg1);
    elseif isstruct(arg1),
        rtype = 'struct';
        [itype, is_nested, nested_keys] = detectStructContent(arg1);
    elseif ischar(arg1),
        rtype = 'char';
        itype = @ischar;
    elseif islogical(arg1),
        rtype = 'logical';
        itype = @islogical;
    elseif isfunctionhandle(arg1),
        rtype = 'function_handle';
        itype = @isfunctionhandle;
    elseif isnumeric(arg1),

        if issingle(arg1),
            rtype = 'single';
            itype = @issingle;
        elseif isdouble(arg1)
            rtype = 'double';
            itype = @isdouble;
        elseif isint8(arg1),
            rtype = 'int8';
            itype = @isint8;
        elseif isint16(arg1),
            rtype = 'int16';
            itype = @isint16;
        elseif isint32(arg1),
            rtype = 'int32';
            itype = @isint32;
        elseif isint64(arg1),
            rtype = 'int64';
            itype = @isint64;
        elseif isuint8(arg1),
            rtype = 'unit8';
            itype = @isuint8;
        elseif isuint16(arg1),
            rtype = 'uint16';
            itype = @isuint16;
        elseif isuint32(arg1),
            rtype = 'uint32';
            itype = @isuint32;
        elseif isuint64(arg1),
            rtype = 'uint64';
            itype = @isuint64;
        end

    else
        error('type of %s not recognized', arg1)
    end

end
