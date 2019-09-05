function [type_as_fh, is_cell_nested, where_nested] = detectCellContent(cellarg);
    % function [type_as_fh, is_cell_nested, where_nested] = detectCellContent(cellarg);
    %
    % Detect the content of a cell at root level.
    %
    % Inputs:
    %
    % cellarg - a cell argument
    %
    % Outputs:
    %
    % type_as_fh - a cell of same size as cellarg containing
    %              function handles that defines the type
    %              of every the item
    %
    % is_cell_nested - a boolean indicating if the cell
    %                  contains cell/structs.
    %
    % where_nested - an array of booleans indicating which
    %                items/indexes are cell/structs
    %
    % Example:
    % >>> x = {false,int8(1),single(1),1.,{},struct()}
    % >>> [types,isnested,where] = detectCellContent(x)
    % >>> assert(isequal(types{1},@islogical))
    % >>> assert(isequal(types{2},@isint8))
    % >>> assert(isequal(types{3},@issingle))
    % >>> assert(isequal(types{4},@isdouble))
    % >>> assert(isequal(types{5},@iscell))
    % >>> assert(isequal(types{6},@isstruct))
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

    csize = size(cellarg);
    n = numel(cellarg);

    if n > 0,
        type_as_fh = cell(csize);
    else
        type_as_fh = cell(0, 0);
    end

    is_cell_nested = false;
    where_nested = logical(zeros(csize));

    for k = 1:n,
        obj = cellarg{k};

        if isstruct(obj),
            type_as_fh{k} = @isstruct;
            is_cell_nested = true;
            where_nested(k) = true;
        elseif iscell(obj),
            type_as_fh{k} = @iscell;
            is_cell_nested = true;
            where_nested(k) = true;
        else
            type_as_fh{k} = detectType(obj);
        end

    end

end
