function [is_empty] = isAnyCellItemEmpty(xcell)
    % function is_empty = isAnyCellItemEmpty(xcell)
    %
    % Check if any cell item is empty
    %
    % Input:
    %
    % xcell - a cell
    %
    % Output:
    %
    % is_empty - a boolean indicating
    %            if any index in xcell is empty
    %
    % Example:
    % xcell = cell(4,4);
    % [is_empty] = isAnyCellItemEmpty(xcell);
    % assert(is_empty);
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

    is_empty = false;
    ncell = numel(xcell);

    for k = 1:ncell

        if isempty(xcell{k})
            is_empty = true;
            break
        end

    end

end
