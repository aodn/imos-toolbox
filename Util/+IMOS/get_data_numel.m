function [cnumel] = get_data_numel(icell)
% function [cnumel] = get_data_numel(icell)
%
% Get the total number of elements of all
% the `data` fields in an IMOS cell of structs.
%
% If data field is missing, empty is returned.
%
% Inputs:
%
% icell [cell[struct]] - an IMOS cell of structs.
%
% Outputs:
%
% cnumel - the numel of each struct.data array members.
%
% Example:
%
% icell = {struct('name','TIME','typeCastFunc',@double,'data',[1:10])};
% [cnumel] = IMOS.get_data_numel(icell);
% assert(isequal(cnumel{1},[10]));
%
% author: hugo.oliveira@utas.edu.au
%
narginchk(1, 1);

if ~iscellstruct(icell)
    error('First argument is not a cell of structs')
end

get_numel = @(obj)(numel(obj.data));
cnumel = IMOS.cellfun(get_numel, icell);
end
