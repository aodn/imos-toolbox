function [bool] = iscellnumeric(acell)
% function [bool] = iscellnumeric(acell)
%
% Determine whether input is a cell array of
% numeric arrays.
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
% assert(iscellnumeric({1,2,3}))
% assert(~iscellnumeric({1,2,'a'}))
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
    bool = all(cellfun(@isnumeric, acell));
catch
end

end
