function [rname] = name(cnames, rindex)
% function [rname] = name(cnames,rindex)
%
% Return cnames{rindex} if cnames is a cell
% of strings and rindex<numel(cnames).
% If out-of-bounds, returns an empty string.
%
% This function will type check the arguments.
%
% Inputs:
%
% cnames [cell[str]] - a cell of strings.
% rindex [integer] -  an integer index.
%
% Outputs:
%
% rname [str] - cnames{index} or empty string.
%
% Example:
%
% [rname] = IMOS.resolve.name({'A'},1);
% assert(rname=='A');
% [rname] = IMOS.resolve.name({'A'},10);
% assert(isempty(rname));
%
% author: hugo.oliveira@utas.edu.au
%
narginchk(2, 2)

if ~iscellstr(cnames)
    errormsg('First argument `cnames` is not a cell of strings.')
elseif (~isindex(rindex) || numel(rindex) > 1)
    errormsg('Second argument `rindex` is not a singleton valid index.')
end

rname = IMOS.getitem(cnames, rindex);
end
