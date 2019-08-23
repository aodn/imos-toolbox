function [fhtype, is_nested, nested_array, type_as_string] = detectType(arg1),
    % function [fhtype, is_nested, nested_array, type_as_string] = detectType(arg1),
    % return several useful information about a matlab type
    %
    % `arg1` - any type/variable.
    % <->
    % `fhtype` - a function handle that defines the the type of arg1
    % or a cell/struct with the function handle that defines the items within.
    % `is_nested` - a singleton boolean indicating if the argument is nested
    % `nested_array` - a boolean array indicating which items in the argument are nested
    % `type_as_string` - a string representing the type of the argument.
    %
    % author: hugo.oliveira@utas.edu.au
    is_nested = false;
    nested_array = logical(zeros(0, 0));

    if iscell(arg1),
        type_as_string = 'cell';
        [fhtype, is_nested, nested_array] = detectCellContent(arg1);
    elseif isstruct(arg1),
        type_as_string = 'struct';
        [fhtype, is_nested, nested_array] = detectStructContent(arg1);
    elseif ischar(arg1),
        type_as_string = 'char';
        fhtype = @ischar;
    elseif islogical(arg1),
        type_as_string = 'logical';
        fhtype = @islogical;
    elseif isfunctionhandle(arg1),
        type_as_string = 'function_handle';
        fhtype = @isfunctionhandle;
    elseif isnumeric(arg1),

        if issingle(arg1),
            type_as_string = 'single';
            fhtype = @issingle;
        elseif isdouble(arg1)

            if isnan(arg1),
                type_as_string = 'NaN';
                fhtype = @isnan;
            elseif isinf(arg1),
                type_as_string = 'inf';
                fhtype = @isinf;
            else
                type_as_string = 'double';
                fhtype = @isdouble;
            end

        elseif isint8(arg1),
            type_as_string = 'int8';
            fhtype = @isint8;
        elseif isint16(arg1),
            type_as_string = 'int16';
            fhtype = @isint16;
        elseif isint32(arg1),
            type_as_string = 'int32';
            fhtype = @isint32;
        elseif isint64(arg1),
            type_as_string = 'int64';
            fhtype = @isint64;
        elseif isuint8(arg1),
            type_as_string = 'unit8';
            fhtype = @isuint8;
        elseif isuint16(arg1),
            type_as_string = 'uint16';
            fhtype = @isuint16;
        elseif isuint32(arg1),
            type_as_string = 'uint32';
            fhtype = @isuint32;
        elseif isuint64(arg1),
            type_as_string = 'uint64';
            fhtype = @isuint64;
        end

    else
        error('type of %s not recognized', arg1)
    end

end
