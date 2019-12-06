function [ritem, repeats, rstart, rend] = findRepeats(arr),
    % function repeats,nr = findRepeats(arr)
    %
    % Find the groups of repeated numbers,
    % the number of repeats, and the index interval
    % they occur.
    %
    % Inputs:
    %
    % arr - a vector numeric array.
    %
    % Outputs:
    %
    % ritem - an array of repeated items.
    % repeats - an array with the respective number of repeats.
    % rstart - the start index of the repeat interval.
    % rend - the end index of the repeat interval.
    %
    % Example:
    % % basic
    % [ritem,repeats,rstart,rend] = findRepeats([1,1,1]);
    % assert(ritem == 1);
    % assert(repeats == 3);
    % assert(rstart == 1);
    % assert(rend == 3);
    %
    % %mix & match
    % x = [.1,.1,.1,.1,.2,.3,.3,.3]
    % [ritem,repeats,rstart,rend] = findRepeats(x);
    % assert(ritem == [0.1,0.3]);
    % assert(repeats == [4,3]);
    % assert(rstart == [1,6]);
    % assert(rend == [4,8]);
    %
    % %repeat only at mid
    % x = [.1,.2,.2,.3]
    % [ritem,repeats,rstart,rend] = findRepeats(x);
    % assert(ritem == 0.2);
    % assert(repeats == 2);
    % assert(rstart == 2);
    % assert(rend == 3);
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

    if ~isvector(arr),
        error('argument not a vector')
    end

    if ~issorted(arr),
        error('vector is not sorted')
    end

    alen = length(arr);
    [uniq, uniq_inds, non_uniq_inds] = unique(arr);
    ni = sum(diff(non_uniq_inds))+1;

    repeats = zeros(ni, 0);
    ritem = zeros(ni, 0);
    rstart = zeros(ni, 0);
    rend = zeros(ni, 0);

    if all(size(uniq) == size(arr)),
        return
    end

    c = 0;
    for k = 2:length(uniq_inds),
        istart = uniq_inds(k - 1);
        iend = uniq_inds(k) - 1;
        ilen = iend - istart + 1;

        if ilen == 1,
            continue
        end

        c = c + 1;
        repeats(c) = ilen;
        ritem(c) = arr(istart);
        rstart(c) = istart;
        rend(c) = iend;
    end

    repeat_at_end = uniq_inds(end) < alen;

    if repeat_at_end,
        istart = uniq_inds(end);
        iend = alen;
        ilen = iend - istart + 1;
        c = c + 1;
        repeats(c) = ilen;
        ritem(c) = arr(istart);
        rstart(c) = istart;
        rend(c) = iend;
    end

end
