function [bool] = is_imos_name(name)
% function [bool] = is_imos_name(name)
%
% Check if a name is a bool IMOS name.
%
% Inputs:
%
% name - variable/dimension IMOS name
%
% Outputs:
%
% bool - True if a valid IMOS parameter
%
% Example:
%
% assert(IMOS.is_imos_name('TIME'));
% assert(~IMOS.is_imos_name('aBcDeFg'))
%
% author: hugo.oliveira@utas.edu.au
%
narginchk(1, 1)
IMOS.params().name;
bool = false;

if inCell(IMOS.params().name, name)
    bool = true;
end

end
