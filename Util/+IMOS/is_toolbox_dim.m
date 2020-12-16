function [bool] = is_toolbox_dim(dstruct)
% function [bool] = is_toolbox_dim(dstruct)
%
% Check if a struct is a toolbox dimension struct.
%
% Inputs:
%
% dstruct[struct] - a toolbox dimension struct
%
% Outputs:
%
% bool - True or False
%
% Example:
%
% %basic
% dstruct = struct('name','TIME','typeCastFunc',@double,'data',[]);
% assert(IMOS.is_toolbox_dim(dstruct))
%
% %false
% dstruct = struct('name','abc');
% assert(~IMOS.is_toolbox_dim(dstruct))
%
%
% author: hugo.oliveira@utas.edu.au
%
narginchk(1, 1)

try
    assert(isstruct(dstruct))
    assert(ischar(dstruct.name))
    assert(isfunctionhandle(dstruct.typeCastFunc))
    dstruct.data; %TODO reinforce shape & numeric !?
    bool = true;
catch
    bool = false;
end

end
