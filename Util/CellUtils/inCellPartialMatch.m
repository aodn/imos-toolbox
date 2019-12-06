function [is_complete, indexes] = inCellPartialMatch(xcell, ycell, allmatches)
% function [indexes,is_complete] = inCellPartialMatch(xcell, ycell, allmatches)
%
% Compare all substrings of ycell against substrings in xcell
% ignoring whitespaces.
% If all the content of a ycell{n} substring
% is found within the substring of xcell{m}
% the m index is stored.
% Hence, matched indexes indicates a full or partial match
% ignoring whitespace of all the substrings in ycell{n} against a xcell{m}
%
% For simple partial string matching, use the contains function
%
% See examples for usage.
%
% Inputs:
%
% xcell - a cell with items as strings.
%         Items may have spaces,tabs,etc. that will be ignored.
% ycell - a string or a cell with items as strings.
%         As above, items may have any whitespace marker.
% allmatches - a boolean to return all matched indexes in a cell,
%              otherwise only the first indexes are returned
%              in an array.
%              Default: false.
%
% Output:
%
% is_complete - a boolean to indicate that all ycell indexes
%               were matched.
% indexes - If `allmatches` is false, return an array of indexes
%           only for the the first matches in xcell.
%           If `allmatches` is true, return an cell of indexes
%           with all matches in xcell.
%
%
% Example:
% astr = sprintf('a\tb\tc');
% [is_complete,indexes] = inCellPartialMatch({astr,'b','c'},{'a b'});
% assert(is_complete)
% assert(isequal(indexes,[1]))
% % Partial matching
% [is_complete,indexes] = inCellPartialMatch({astr,'b','c'},{'a c'});
% assert(is_complete)
% assert(isequal(indexes,[1]))
% % Partial matching reduced
% [is_complete,indexes] = inCellPartialMatch({astr,'b','c'},{'a c','c'});
% assert(is_complete)
% assert(isequal(indexes,[1;1]))
% % Partial matching complete
% [is_complete,indexes] = inCellPartialMatch({astr,'b','c'},{'a c','c'},true);
% assert(is_complete)
% assert(iscell(indexes))
% assert(isequal(indexes{1},{1}))
% assert(isequal(indexes{2},{1,3}))
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

narginchk(2, 3)

if nargin < 3
    allmatches = false;
end

if ~iscell(ycell)
    ycell = {ycell};
end

cindexes = cell(1, length(ycell));

for k = 1:length(ycell)
    cindexes{k} = {};

    if ~ischar(ycell{k})
        error('The second argument index `ycell{%d}` is not a string', k);
    end

    ysplit = strsplit(ycell{k});

    c = 0;

    for kk = 1:length(xcell)

        if ~ischar(xcell{kk})
            error('The first argument index `xcell{%d}` is not a string', k);
        end

        xsplit = strsplit(xcell{kk});
        [~, is_complete] = whereincell(xsplit, ysplit);

        if is_complete
            c = c + 1;
            cindexes{k}{c} = kk;
        end

    end

end

[incomplete, empty_entries] = inCell(cindexes, cell(0, 0));
is_complete = ~incomplete;

if nargout > 1

    if allmatches
        indexes = cindexes;
    else

        if incomplete && length(empty_entries) == 1 && empty_entries(1) == 1
            indexes = [];
            return
        end

        vind = popFromCell(num2cell(1:length(cindexes)), num2cell(empty_entries));
        asize = length(vind);
        indexes = zeros(asize, 1);

        for ni = 1:length(vind)
            ind = vind{ni};
            indexes(ni) = cindexes{ind}{1};
        end

    end

end

end
