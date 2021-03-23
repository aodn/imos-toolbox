function [data] = get_data(tcell, name)
% function [data] = get_data(tcell)
%
% Get the tcell{n}.data field within
% tcell that matches the field{n}.name.
%
%
% Inputs:
%
% tcell - a toolbox structure.
% name - the field.name to be matched.
%
% Outputs:
%
% data - the data field.
%
% Example:
%
% %basic usage
% A = struct('name','A','data',[1,2,3]);
% B = struct('name','B','data',[4,5,6]);
% C = struct('name','C','data',[7,8,9]);
% tcell = {A,B,C};
% assert(isequal(IMOS.get_data(tcell,'A'),[1,2,3]));
% assert(isequal(IMOS.get_data(tcell,'B'),[4,5,6]));
% assert(isequal(IMOS.get_data(tcell,'C'),[7,8,9]));
%
% %toolbox usage
% tcell = IMOS.gen_dimensions('timeSeries',3,{'C','B','A'},{},{[7;8;9],[4;5;6],[1;2;3]});
% assert(isequal(IMOS.get_data(tcell,'A'),[1;2;3]));
% assert(isequal(IMOS.get_data(tcell,'B'),[4;5;6]));
% assert(isequal(IMOS.get_data(tcell,'C'),[7;8;9]));
%
% author: hugo.oliveira@utas.edu.au
%
narginchk(2, 2)

if ~iscellstruct(tcell)
    errormsg('First argument not a toolbox cell of structs')
elseif ~ischar(name)
    errormsg('Second argument not a char')
end

try
    data = tcell{IMOS.find(tcell, name)}.data;
catch
    data = [];
end
