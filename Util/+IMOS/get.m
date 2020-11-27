function [fcell] = get(icell, fieldname)
% function [fcell] = get(icell,fieldname)
%
% Get a fieldname from a IMOS cell of structs.
%
% Inputs:
%
% icell [cell[struct]] - an IMOS cell of structs.
% fieldname - the struct fieldname.
%
% Outputs:
%
% fcell[Any] - A cell with all fieldnames. If fieldnames
%              are missing, empty entries are included.
%
% Example:
%
% dimcell = {struct('name','TIME','typeCastFunc',@double,'data',[1:10],'comment','')};
% dimcell{end+1} = struct('name','TEST');
% [names] = IMOS.get(dimcell,'name');
% assert(isequal(names,{'TIME','TEST'}));
% [comments] = IMOS.get(dimcell,'comment');
% assert(ischar(comments{1}) && isempty(comments{1}))
% assert(isdouble(comments{2}) && isempty(comments{2}))
%
%
% author: hugo.oliveira@utas.edu.au
%
narginchk(2, 2);

if ~iscellstruct(icell)
    errormsg('First argument `icell` is not a cell of structs')
elseif ~ischar(fieldname)
    errormsg('Second argument `fieldname` is not a string')
end

get_field = @(obj)(resolve_field(obj, fieldname));
fcell = cellfun(get_field, icell, 'UniformOutput', false);
end

function r = resolve_field(obj, fname)

try
    r = obj.(fname);
catch
    r = [];
end

end
