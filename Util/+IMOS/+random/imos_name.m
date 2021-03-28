function [name] = imos_name
% function [name] = imos_name
%
% Generate a random IMOS name
%
% Inputs:
%
% Outputs:
%
% name [string] - an IMOS name from imosParameters.txt
%
% Example:
%
% [name] = IMOS.random.imos_name();
% assert(~isempty(name))
% assert(all(isstrprop(name,'print')))
%
% author: hugo.oliveira@utas.edu.au
%
name = IMOS.random.get_random_param('name');
end
