function [bool, ulen, uniq_inds, non_uniq_inds] = isunique(x),
    % function [bool, ulen, uindex, nonuindex] = isUnique(x)
    %
    % A wrapper that checks if an array is unique. Extra output
    % arguments are commonly used for uniqueness processing.
    %
    % Inputs:
    %
    % x - an array
    %
    % Outputs:
    %
    % bool - a boolean for uniqueness
    % ulen - the length of unique array
    % uniq_inds - the set of indexes that turn x into
    %             a unique array.
    % non_uniq_inds - a non-unique set of indexes that
    %                 creates a non-unique x.
    %
    % Example:
    % assert(isunique([1,2,3]))
    %
    % author: hugo.oliveira@utas.edu.au
    %

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

    [uarray, uniq_inds, non_uniq_inds] = unique(x);
    ulen = length(uarray);
    bool = length(x) == ulen;
end
