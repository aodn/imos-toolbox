function [is_complete, indexes] = inCellPartialMatchString(xcell,ycell,first_match_only)
% function [indexes,is_complete] = inCellPartialMatchString(xcell, ycell,first_match_only)
%
% Check if each string entry in ycell is within any string entry in xcell.
%
% If all the content of a ycell{n} string
% is found within the string of xcell{m}
% the m index is stored.
%
% For simple partial string matching, use the contains function
%
% See examples for usage.
%
% Inputs:
%
% xcell - a cell with items as strings.
% ycell - a string or another cell with items as strings.
% first_match_only - a boolean to skip subsequent matches of ycell in xcell.
%                  - Default: false
%
% Output:
%
% is_complete - a boolean to indicate that all ycell items
%               were matched.
% indexes - a cell of indexes where matches occur in xcell.
%
%
% Example:
% % complete match
% xnames = {'a','ab','abc','123'};
% ynames = {'a','3'};
% [is_complete, indexes] = inCellPartialMatchString(xnames,ynames);
% assert(is_complete)
% assert(isequal({1,2,3,4},indexes))
% [is_complete, indexes] = inCellPartialMatchString(xnames,ynames,true);
% assert(is_complete)
% assert(isequal({1,4},indexes))
%
% % incomplete match
% xnames = {'a','b','c','123'};
% ynames = {'x','y','z','3'};
% [is_complete, indexes] = inCellPartialMatchString(xnames,ynames);
% assert(~is_complete)
% assert(isequal({4},indexes))
%
% % no match
% xnames = {'x','y','z'};
% ynames = {'a','b','c'};
% [is_complete, indexes] = inCellPartialMatchString(xnames,ynames);
% assert(~is_complete)
% assert(isequal({},indexes))

%
% author: hugo.oliveira@utas.edu.au
%
narginchk(2, 3)
if nargin<3
    first_match_only = false;
end

if ~iscell(ycell)
    ycell = {ycell};
end

indexes = cell(1,numel(ycell)*numel(xcell));
ydetection = zeros(1,numel(ycell));

c = 0;
for k = 1:numel(ycell)
    if ~ischar(ycell{k})
        error('The second argument index `ycell{%d}` is not a string', k);
    end
    for kk = 1:length(xcell)
        if ~ischar(xcell{kk})
            error('The first argument index `xcell{%d}` is not a string', k);
        end
        if contains(xcell{kk},ycell{k})
            c = c + 1;
            indexes{c} = kk;
            ydetection(k) = true;
            if first_match_only
                break
            end
        end
    end
end

indexes = indexes(1:c);
if isempty(indexes)
    indexes = {};
end
is_complete = all(ydetection);
end
