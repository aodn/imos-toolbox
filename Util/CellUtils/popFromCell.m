function [newcell, rm_indexes] = popFromCell(xcell, match)
%function [newcell,rm_indexes] = popFromCell(xcell, match)
%
% generate a new cell with an item removed
%
% Inputs:
%
% xcell - the cell
% match - a cell containing the items to remove
%         or a string.
%
% Outputs:
%
% newcell - the cell with `match` removed
% rm_indexes - the indexes where match was found
%
% Examples:
%
% %basic usage
% [newcell] = popFromCell({1,2,3},{2,3});
% assert(isequal(newcell,{1}))
%
% % 2nd arg string
% [newcell] = popFromCell({'a','b'},'b');
% assert(isequal(newcell,{'a'}))
%
% %raise error for empty 2nd arg
% try;popFromCell({'a'},'');catch;r=true;end
% assert(r)
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

flen = numel(xcell);
newcell = cell(1);

not_cell_or_str = not(iscell(match) || ischar(match));

if not_cell_or_str
    error('The second argument `match` need to be a cell or str')
end

if ischar(match)
    matches = cell(1, 1);
    matches{1} = match;
else
    matches = match;
end

mlen = numel(matches);

rm_indexes = [];
c = 0;
r = 0;
include = true;

for k = 1:flen

    for m = 1:mlen

        if ~inCell(xcell, matches{m})
            is_single_match = mlen == 1;

            if is_single_match
                error('Requested item not found in cell');
            else
                error('Requested `match{%d}` not found in cell');
            end

        elseif isequal_ctype(xcell{k}, matches{m})
            include = false;
            r = r + 1;
            break
        end

    end

    if include
        c = c + 1;
        newcell{c} = xcell{k};
    else
        rm_indexes(r) = k;
    end

    include = true;
end

end
