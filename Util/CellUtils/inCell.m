function [bool, indexes] = inCell(xcell, item)
    % function [bool,indexes] = inCell(xcell,item)
    %
    % Check if item is in Cell and where.
    %
    % Inputs:
    %
    % xcell - a cell
    % item -  an variable.
    %
    % Outputs:
    %
    % bool - a bool marking if item in xcell
    % indexes - an array of where the item is found in xcell
    %
    % Examples:
    % [bool,indexes] = inCell({'a','b','b'},'b')
    % assert(bool,true)
    % assert(indexes,[2,3])
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

    % You should have received a copy of the GNU General Public License
    % along with this program.
    % If not, see <https://www.gnu.org/licenses/gpl-3.0.en.html>.
    %

    exit_at_first = nargout == 1;
    bool = false;
    indexes = zeros(0);
    c = 0;

    for k = 1:numel(xcell)

        if isequal_ctype(xcell{k}, item)
            bool = true;

            if exit_at_first
                return
            end

            c = c + 1;
            indexes(c) = k;
        end

    end

end
