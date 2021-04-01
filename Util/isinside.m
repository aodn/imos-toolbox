function [bool] = isinside(obj,items)
% function [bool] = isinside(obj,items)
%
% Check if all items are contained in obj,
% where items are a cell of strings.
%
% Inputs:
%
% obj[cell(str)] - A cell of items.
% items[cell(str)] - All items that should be
%                    within obj.
%
% Outputs:
%
% bool - True if all items in obj.
%
% Example:
%
% %basic usage
% assert(isinside({'a','b','c'},{'a'}))
% assert(isinside({'a','b','c'},{'a','b','c'}))
% assert(~isinside({'a'},{'a','b','c'}))
%
% %ignore matlab inconsistent comparison against cell of different shapes
% assert(isinside({'a','b','c'},{'a','b'}'))
%
% author: hugo.oliveira@utas.edu.au
%
a = unique(intersect(obj,items));
b = unique(items);

if iscell(obj) || iscell(items)
	bool = isequal(a(:),b(:));
else
	bool = isequal(a,b);
end

end
