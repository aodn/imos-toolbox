function [csizes] = get_data_sizes(icell)
% function [csizes] = get_data_sizes(icell)
%
% Get the data size of all the `data`
% fields in an IMOS cell of structs.
%
% Inputs:
%
% icell [cell[struct]] - an IMOS cell of structs.
%
% Outputs:
%
% csizes - the sizes of struct.data array.
%
% Example:
%
% %typical use
% icell = {struct('name','TIME','typeCastFunc',@double,'data',[1:10])};
% [csizes] = IMOS.get_data_sizes(icell);
% assert(isequal(csizes{1},[1,10]));
%
%
% author: hugo.oliveira@utas.edu.au
%
narginchk(1, 1);

if ~iscellstruct(icell)
    error('First argument `icell` is not a cell of structs')
end

get_size = @(obj)(size(obj.data));
csizes = IMOS.cellfun(get_size, icell);
end
