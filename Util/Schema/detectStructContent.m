function [types_as_fh, is_struct_nested, where_nested] = detectStructContent(structarg);
    % function [types_as_fh, is_struct_nested, where_nested] = detectStructContent(structarg);
    %
    % Detect the content of a struct at root level.
    %
    % Inputs:
    %
    % structarg - a struct variable argument
    %
    % Outputs:
    %
    % types_as_fh - a struct of the same size as structarg containing
    %              function handles that defines the type of every
    %              field
    % is_struct_nested - a boolean indicating if the struct
    %                    contains cell/structs.
    % where_nested - an array of booleans indicating which
    %                items/indexes are cell/structs
    %
    % Example:
    % >>> x = struct('a',false,'b',int8(1),'c',single(1),'d',1.)
    % >>> x.e={},x.f=struct()
    % >>> [types,isnested,where] = detectStructContent(x)
    % >>> assert(isequal(types.a,@islogical))
    % >>> assert(isequal(types.b,@isint8))
    % >>> assert(isequal(types.c,@issingle))
    % >>> assert(isequal(types.d,@isdouble))
    % >>> assert(isequal(types.e,@iscell))
    % >>> assert(isequal(types.f,@isstruct))
    % >>> assert(isnested)
    % >>> assert(all(where==[0,0,0,0,1,1])
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

    is_struct_nested = false;
    names = fields(structarg);
    n = numel(structarg);

    if n == 1,
        types_as_fh = struct();
    else
        % `abc(size) = struct()` doesn't work for len(size)>2;
        types_as_fh(n) = struct();
        types_as_fh = reshape(types_as_fh, size(structarg));
    end

    m = length(names);
    types_as_fh = struct();

    where_nested = logical(zeros(0, 0));

    for k = 1:n

        for kk = 1:m,
            name = names{kk};
            obj = structarg(k).(name);

            if isstruct(obj),
                types_as_fh(k).(name) = @isstruct;
                is_struct_nested = true;
                where_nested(k, kk) = true;
            elseif iscell(obj),
                types_as_fh(k).(name) = @iscell;
                is_struct_nested = true;
                where_nested(k, kk) = true;
            else
                types_as_fh(k).(name) = detectType(obj);
            end

        end

    end

end
