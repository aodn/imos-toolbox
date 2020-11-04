function [bool, ulen, uniq_inds, non_uniq_inds] = isunique(x)
% function [bool, ulen, uniq_inds, non_uniq_inds] = isunique(x)
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
% assert(~isunique([1,2,1]))
%
% author: hugo.oliveira@utas.edu.au
%
if nargout > 1
    [uarray, uniq_inds, non_uniq_inds] = unique(x);
else
    [uarray] = unique(x);
end

ulen = length(uarray);
bool = length(x) == ulen;
end
