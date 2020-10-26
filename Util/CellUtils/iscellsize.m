function [bool] = iscellsize(acell)
% function [bool] = iscellsize(acell)
%
% Determine whether input is a cell array of
% numeric size arrays.
%
% Inputs:
%
% acell [cell[array]] - a cell to be verified.
%
% Outputs:
%
% bool - True or False.
%
% Example:
%
% assert(iscellsize({[1,10]}))
% assert(~iscellsize({1,2,[1, 10],[10, 99, 33]}))
% assert(~iscellsize({1,2,'a'}))
%
%
% author: hugo.oliveira@utas.edu.au
%
narginchk(1, 1)
bool = false;

if isempty(acell)
    return
end

try
    bool = all(cellfun(@issize, acell));
catch
end

end
