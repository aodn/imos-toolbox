function [bool] = isindex(item)
% function [bool] = isindex(item)
%
% Determine whether input is a valid
% array index - positive integer array
% or logical array.
%
% Inputs:
%
% item - a strictly integer positive array
%        or logical array.
%
% Outputs:
%
% bool - true or false.
%
% Example:
%
% assert(isindex(1))
% assert(isindex([1,2,3]))
% assert(isindex([0,1,0,1]))
% assert(~isindex(0))
% assert(~isindex([0,0,0]))
% assert(~isindex([-1,2,3]))
% assert(~isindex([1.1,2.2]))
% assert(~isindex([NaN,Inf,3]))
% assert(~isindex([1,2,'a']))
%
%
% author: hugo.oliveira@utas.edu.au
%
narginchk(1, 1);
bool = false;

if ~isnumeric(item)
    return
end

try
    i64 = int64(item);
    if isequal(i64, item) && all(i64>-1) && any(logical(item))
        bool = true;
    end
catch
end
end
