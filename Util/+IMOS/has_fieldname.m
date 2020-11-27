function [bool] = has_fieldname(scell, fieldname)
% function [bool] = has_fieldname(scell,fieldname)
%
% Check if all members in a cell of structs
% contains a certain fieldname.
%
% Inputs:
%
% scell [cell[struct]] - a cell with structs.
% fieldname - a fieldname string.
%
% Outputs:
%
% bool - a boolean/logical array [1,N].
%
%
% Example:
%
% scell = {struct('name','123','id',1),struct('name','456')};
% assert(IMOS.has_fieldname(scell,'name'))
% assert(~IMOS.has_fieldname(scell,'id'))
%
% author: hugo.oliveira@utas.edu.au
%
narginchk(2, 2)

if ~iscellstruct(scell)
    error('First argument `scell` is not a cell of structs')
elseif ~ischar(fieldname)
    error('Second argument `fieldname` is not a char')
end

bool = false;

if ~iscellstruct(scell)
    return
end

try
    got_field = @(x)(isfield(x, fieldname));
    bool = all(cellfun(got_field, scell));
catch
end

end
