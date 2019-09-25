function [ccell] = fillEmptyCellIndex(a1, a2)
    % function [ccell] = fillEmptyCellIndex(a1,a2)
    %
    % Fill the empty cell indexes (`{}`) of a cell with the
    % non-empty indexes of the other cell.
    % The second argument index values
    % is kept in any non-empty index.
    %
    % Inputs:
    %
    % a1 - a cell
    % a2 - another cell with same size as `a1`
    %
    % Outputs:
    %
    % ccell - a cell with non-empty entries in `a2`
    %         filled with non-empty entries of `a1`
    %
    % Example:
    % ccell = fillEmptyCellIndex({'a','B','C','D',cell(0,0)},{cell(0,0),'','c','d','e'})
    % assert(strcmpi(ccell{1},'a'))
    % assert(strcmpi(ccell{2},''))
    % assert(strcmpi(ccell{3},'c'))
    % assert(strcmpi(ccell{4},'d'))
    % assert(strcmpi(ccell{5},'e'))
    % % empty check
    % ccell = fillEmptyCellIndex({'',cell(0,0)},{cell(0,0),''})
    % assert(isequal(ccel,'',''}))
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

    a1n = numel(a1);
    a2n = numel(a2);
    argsizediff = ~isequal(a1n, a2n);

    if argsizediff
        error('The cell size or both arguments are different')
    end

    ccell = cell(1, a1n);
    empty = cell(0, 0);

    for k = 1:a1n
        use_a1 = isequal(a2{k},empty);
        if use_a1
            ccell{k} = a1{k};
        else
            ccell{k} = a2{k};
        end

    end

end
