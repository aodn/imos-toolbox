function [outcome, root, nrec] = createTree(arg1, func, outcome, name, nrec),
    % function [outcome, root, nrec] = createTree(arg1, func, outcome, name, nrec),
    %
    % A function to recursively apply a function handler @func,
    % to all fields/items/indexes of an argument (arg1).
    % This function generates the exact same type of arg1
    % if arg1 is [cell,struct], applying @func through all
    % nested structures. If the arg1 is not a [cell,struct],
    % the outcome is the first output of `func(arg1)`.
    %
    % Inputs:
    %
    % arg1 - a matlab variable
    % func - a special function handle that consumes a single argument
    %          It should return at least 3 outputs in this order:
    %        outarg1 -> anything, except for [cell,struct] arguments to
    %                   func which should return empty [cell,structs].
    %        is_nested -> a boolean if argument is nested (cell,struct)
    %        nested_array -> an array indicating nested [field,indexes]
    % outcome - the parent structure - internal use
    % name - the name of the nested level - internal use
    % nrec - the maximum nested level - internal use
    %
    % Output:
    %
    % outcome - the result structure of the recursive evaluation.
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
        outcome = struct();
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

    [outcome, is_nested, nested_keys] = func(arg1);
    first_level = outcome;

    if is_nested,

        if isstruct(outcome),
            fnames = fields(outcome);
            nested_names = fnames(nested_keys);

            for k = 1:length(nested_names),

                kname = nested_names{k};
                data = arg1.(kname);
                [outcome.(kname), root, nrec] = self(data, func, outcome, kname, nrec - 1);
            end

        elseif iscell(outcome),

            for k = 1:length(nested_keys),
                data = arg1{k};
                [outcome{k}, root, nrec] = self(data, func, outcome, iname, nrec - 1);
            end

        end

    end

    isroot = strcmpi(iname, 'root');

    if isroot,
        nrec = abs(nrec) - 1;
    end

    root = first_level;

end
