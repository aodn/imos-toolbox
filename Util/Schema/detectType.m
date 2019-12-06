function [fhtype, is_nested, nested_array, type_as_string] = detectType(arg1),
    % function [fhtype, is_nested, nested_array, type_as_string] = detectType(arg1),
    %
    % Detect several information regarding the type of arg1, such as
    % the type as function handler, if argument is nested,
    % where nesting occurs and a string representation of the type.
    %
    % Inputs:
    %
    % arg1 - any type/variable, except classes.
    %
    % Outputs:
    %
    % fhtype - If (arg1) is [cell,struct], this is a [cell,struct]
    %          with the [indexes,fieldnames] filled with typewise
    %          func.handlers. Otherwise, fhtype is just
    %          the typewise func.handler.
    % is_nested - a singleton boolean to indicate if
    %             arg1 is [cell,struct]
    % nested_array - a boolean array indicating which items in
    %                the argument are nested. If arg1 is struct,
    %                the array follows the order of fieldnames(arg1),
    %                otherwise it follows the vector indexing order
    %                of the cell
    % type_as_string - a string representing the type of the argument.
    %
    % Example:
    % >>> x.a = false
    % >>> x.b = {'',int8(1),{single(2)},struct('c',3.)}
    % >>> [fhtypes,is_nested,na,xtype] = detectType(x)
    % >>> assert(isequal(fhtypes.a,@islogical))
    % >>> assert(isequal(fhtypes.b{1},@isstr))
    % >>> assert(isequal(fhtypes.b{2},@isint8))
    % >>> assert(isequal(fhtypes.b{3}{1},@issingle))
    % >>> assert(isequal(fhtypes.b{4}.c, @isdouble))
    % >>> assert(is_nested)
    % >>> assert(all(na==[0,1]))
    % >>> assert(strcmp(xtype,'struct'))
    %
    % author: hugo.oliveira@utas.edu.au
    %

    % Copyright (C) 2019, Australian Ocean Data Network (AODN) and Integrated
    % Marine Observing System (IMOS).
    %
    % This program is free software: you can redistribute it and/or modify
    % it under the terms of the GNU General Public License as published by
    % the Free Software Foundation version 3 of the License.
    %
    % This program is distributed in the hope that it will be useful,
    % but WITHOUT ANY WARRANTY; without even the implied warranty of
    % MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    % GNU General Public License for more details.
    %
    % You should have received a copy of the GNU General Public License
    % along with this program.
    % If not, see <https://www.gnu.org/licenses/gpl-3.0.en.html>.
    %

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
