function [newcell] = joinCell(c1, c2)
    %function [newcell] = joinCell(c1,c2)
    %
    % join two column/vector cell objects if c1|c2 is 1xN or Nx1
    %
    % Inputs:
    %
    % c1 - first cell
    % c2 - second cell
    %
    % Outputs:
    %
    % newcell - the join of c1+c2
    %
    % Example:
    % [newcell] = joincell({'a','b'},{'c','d'})
    % assert(isequal(newcell,{'a','b','c','d'}))
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

    narginchk(2, 2);
    c1s = squeeze(c1);
    c2s = squeeze(c2);
    c1size = size(c1s);
    c2size = size(c2s);

    c1_not_column = c1size(1) ~= 1;
    c1_not_row = c1size(2) ~= 1;
    c2_not_column = c2size(1) ~= 1;
    c2_not_row = c2size(2) ~= 1;

    invalid_c1 = c1_not_column && c1_not_row;
    invalid_c2 = c2_not_column && c2_not_row;
    invalid_input = invalid_c1 || invalid_c2;

    if invalid_input
        error('Cell is not a vector.')
    end

    c1l = length(c1s);
    c2l = length(c2s);
    cnl = c1l + c2l;

    newcell = cell(1, cnl);

    for k = 1:c1l
        newcell{k} = c1s{k};
    end

    c = 0;

    for k = c1l + 1:cnl
        c = c + 1;
        newcell{k} = c2s{c};
    end

end
