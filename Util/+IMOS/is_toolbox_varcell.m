function [bool] = is_toolbox_varcell(tcell)
% function [bool] = is_toolbox_varcell(tcell)
%
% Check if all items in a cell of structs are
% toolbox variables.
%
% Inputs:
%
% tcell [cell[structs]] - a cell of structs.
%
% Outputs:
%
% bool - True or False.
%
% Example:
%
% %basic usage
% d = IMOS.gen_dimensions();
% v = IMOS.gen_variables(d);
% assert(IMOS.is_toolbox_varcell(v));
% f=false;try;IMOS.is_toolbox_varcell(v{1});catch;f=true;end
% assert(f)
%
% author: hugo.oliveira@utas.edu.au
%
narginchk(1, 1)
bool = all(cellfun(@IMOS.is_toolbox_var, tcell));
end
