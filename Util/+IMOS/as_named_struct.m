function [nstruct] = as_named_struct(tcell)
% function [nstruct] = as_named_struct(tcell)
%
% Transform a toolbox cell to a named struct.
%
% Inputs:
%
% tcell[cell{struct}] - the toolbox cell
%
% Outputs:
%
% nstruct[struct] - a named struct with cell items.
%
% Example:
%
% %basic usage
%
%
% author: hugo.oliveira@utas.edu.au
%
i = IMOS.dinfo(tcell);
nstruct = cell2struct(tcell,IMOS.get(tcell,'name'),i.max_dim_index);
end
