function [bool] = is_toolbox_var(vstruct)
% function [bool] = is_toolbox_var(vstruct)
%
% Check if a struct is a toolbox variable struct.
%
% Inputs:
%
% vstruct - A struct.
%
% Outputs:
%
% bool - True for a toolbox variable struct.
%
% Example:
%
% %true
% vstruct = struct('name','abc','typeCastFunc',@double,'dimensions',[],'data',[]);
% assert(IMOS.is_toolbox_var(vstruct))
%
% %false
% vstruct = struct('name','abc','typeCastFunc',@double,'data',[]);
% assert(~IMOS.is_toolbox_var(vstruct))
%
%
% author: hugo.oliveira@utas.edu.au
%
narginchk(1, 1)

try
    assert(IMOS.is_toolbox_dim(vstruct))
    assert(isindex(vstruct.dimensions) || isempty(vstruct.dimensions))%TODO: reinforce shape
    %TODO: reinforce coordinates for non featuretype values!?
    bool = true;
catch
    bool = false;
end

end
