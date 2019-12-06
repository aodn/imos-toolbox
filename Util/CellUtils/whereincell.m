function [indexes, is_complete] = whereincell(xcell, ycell)
    % function indexes,is_complete = whereincell(xcell,ycell)
    %
    % Locate the indexes of items in ycell within xcell.
    %
    % Inputs:
    %
    % xcell - a cell with items to compare with
    % ycell - a cell with items to compare to
    %
    % Outputs:
    %
    % indexes - the indexes of the items in ycell located in xcell
    % is_complete - if all indexes in ycell are found in xcell.
    %
    % Example:
    % [indexes,is_complete] = whereincell({'a','b','c'},{'a'})
    % assert(indexes,[1])
    % assert(is_complete)
    %
    % [indexes,is_complete] = whereincell({'a','b'},{'a','b',''})
    % assert(indexes,[1,2])
    % assert(~is_complete)
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

    indexes = zeros(0);

    c = 0;

    if ~iscell(ycell)
        ycell = {ycell};
    end

    for k = 1:length(ycell)
        [is_inside, where_indexes] = inCell(xcell, ycell{k});

        if is_inside
            c = c + 1;
            indexes(c) = where_indexes(1);
        end

    end

    is_complete = all(size(unique(indexes)) == size(1:length(ycell)));
end
