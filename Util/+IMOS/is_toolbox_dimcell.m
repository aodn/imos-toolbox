function [bool] = is_toolbox_dimcell(tcell)
% function [bool] = is_toolbox_dimcell(tcell)
%
% Check if all items in the cell are toolbox dimensions
%
% Inputs:
%
% tcell - a cell of structs.
%
% Outputs:
%
% bool - True or False.
%
% Example:
%
% %basic usage
% dims = IMOS.gen_dimensions();
% assert(IMOS.is_toolbox_dimcell(dims));
% f=false;try;IMOS.is_toolbox_dimcell(dims{1});catch;f=true;end
% assert(f)
%
%
% author: hugo.oliveira@utas.edu.au
%
narginchk(1, 1)
bool = all(cellfun(@IMOS.is_toolbox_dim, tcell));
end
