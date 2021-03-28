function [mib] = memuse(asize, atype)
%function [mib] = memuse(asize, atype)
%
% Estimate memory usage given a size and type.
%
% Inputs:
%
% asize [double] NxN - an array of sizes.
% atype [string] - a class string.
%
% Ouputs:
%
% mib [double] - the size in mebibytes.
%
%
% Example:
%
% x = memuse(1048576,'logical')
% assert(x==1)
% x = memuse(1048576,'double')
% assert(x==8)
% x = memuse(1048576,'single')
% assert(x==4)
%
% %we dont introspect content for cells/struct
% x = memuse(1,'struct')
% assert(isinf(x))
% x = memuse(1,'cell')
% assert(isinf(x))
%
%
% author: hugo.oliveira@utas.edu.au
%
%
if nargin < 2
    atype = 'double';
end

switch atype
    case 'single'
        n = 4;
    case 'logical'
        n = 1;
    case 'double'
        n = 8;
    otherwise
        n = Inf;
end

mib = n * prod(asize) / 1048576;
end
