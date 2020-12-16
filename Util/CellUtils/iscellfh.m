function [bool] = iscellfh(acell)
% function [bool] = iscellfh(acell)
%
% Determine whether input is a cell array of
% function handles
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
% assert(iscellfh({@double}));
% assert(~iscellfh({@double,''}));
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
    bool = all(cellfun(@isfunctionhandle, acell));
catch
end

end
