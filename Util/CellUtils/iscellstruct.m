function [bool] = iscellstruct(acell)
% function [bool] = iscellstruct(acell)
%
% Determine whether input is a cell array of
% structs.
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
% assert(iscellstruct({struct()}));
% assert(~iscellstruct({struct(),'abc'}))
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
    bool = all(cellfun(@isstruct, acell));
catch
end

end
