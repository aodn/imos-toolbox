function [item] = getitem(carray, rindex)
% function [item] = getitem(carray,rindex)
%
% Resolve access to a cell item.
%
% Empty data is returned when the function is called
% without arguments or when the requested index is out of 
% bounds.
%
% If the index is not provided, selects randomly from
% the cell.
%
% Inputs:
%
% carray [cell[any]] - a cell with items.
% rindex [integer] - an integer index. Optional.
%
% Outputs:
%
% item - an array.
%
% Example:
%
% %empty cases
% [item] = IMOS.getitem();
% assert(isempty(item))
% [item] = IMOS.getitem({});
% assert(isempty(item))
%
% %out-of-bounds resolution
% [item] = IMOS.getitem({'a'},2);
% assert(isempty(item))
%
% % errors
% try;IMOS.getitem('a');catch;r=true;end;
% assert(r)
% try;IMOS.getitem({'a'});catch;r2=true;end;
% assert(r2)
%
% %resolve in-bounds
% [item] = IMOS.getitem({[1],[2],[3]},1);
% assert(item==1)
%
%
% author: hugo.oliveira@utas.edu.au
%
narginchk(0,2)
if nargin==0 || (nargin == 1 && iscell(carray) && isempty(carray))
    item = [];
    return
elseif ~iscell(carray)
    error('First argument `carray` must be a cell')
elseif ~isindex(rindex)
    error('Second argument `rindex` must be an integer/logical index')
end

try
    item = carray{rindex};
catch
    item = [];
end

end
