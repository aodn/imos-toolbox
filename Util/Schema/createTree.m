function [stype, root, nrec] = createTree(arg1, func, stype, name, nrec),
    % function [stype, root, nrec] = createTree(arg1, func, stype, name, nrec),
    %
    % A function to recursively apply a function handler @func,
    % to all fields of an argument.
    % the function generate the exact same type of arg1,
    % visiting/applying @func through all nested structures (cells/structs)
    %
    % Inputs:
    %
    % arg1 - a matlab variable
    % func - a special function handle that consumes a single argument
    %          It should return at least 3 outputs in this order:
    %        fh_type -> a @func.handle that define the type of the argument
    %        is_nested -> a boolean if argument is nested (e.g. struct/cell)
    %        nested_array -> an array of the field/indexes that are nested.
    % stype - the parent structure - internal use - default to struct()
    % name - the name of this walk level - internal use - default to ``root`
    % nrec - the level of this walk level - internal use - default to -1
    %
    % Output:
    %
    % stype - the result structure of the recursive evaluation.
    % root - the result of `func` at the root level of arg1.
    % nrec - is the total number of walk-ins/nested visits.
    %
    % Example:
    % >>> x.a = false
    % >>> x.b = {1,2,{3,4},struct('c',5)}
    % >>> [typetree,rtype,nrec] = createTree(x)
    % >>> assert(nrec==5);
    % >>> assert(isequal(rtype.a,@islogical))
    % >>> assert(isequal(rtype.b,@iscell))
    % >>> assert(isequal(typetree.a,@islogical))
    % >>> assert(iscell(typetree.b))
    % >>> assert(isequal(typetree.b{1},@isdouble))
    % >>> assert(iscell(typetree.b{3}))
    % >>> assert(isequal(typetree.b{3}{1},@isdouble))
    % >>> assert(isequal(typetree.b{4}.c,@isdouble))
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
    narginchk(1, 5)

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
                [stype.(kname), root, nrec] = self(data, func, stype, kname, nrec - 1);
            end

        elseif iscell(stype),

            for k = 1:length(nested_keys),
                data = arg1{k};
                [stype{k}, root, nrec] = self(data, func, stype, iname, nrec - 1);
            end

        end

    end

    %adjust nrec and root
    if strcmpi(iname, 'root'),
        nrec = abs(nrec) - 1;
    end

    root = first_level;

end
