function [indexes] = find(icell, names)
% function [indexes] = find(icell, names)
%
% Find named toolbox variables/dimensions
% indexes within a toolbox cell.
%
% Drop-in replacement for getVar if 
% names is a char.
%
% Inputs:
%
% icell[cell{struct}] - the toolbox cell.
% name[ cell{char} | char] - the name of the variable/dimension.
%
% Outputs:
%
% index[int] - The variable index(es). Singleton if name is achar.
%
% Example:
%
% %basic usage
% d1 = struct('name','TIME_at_1','typeCastFunc',@double,'data',[1:10]);
% d2 = struct('name','TIME_at_2','typeCastFunc',@double,'data',[11:20]);
% icell = {d1,d2};
% ind = IMOS.find(icell,'TIME_at_2');
% assert(ind==2)
% ind = IMOS.find(icell,{'TIME_at_2','TIME_at_1'});
% assert(isequal(ind,[2,1]));
%
%
% author: hugo.oliveira@utas.edu.au
%
narginchk(2,2)
if ~iscellstruct(icell)
	errormsg('First argument is not a cell of structs')
end

char_input = ischar(names);

if (~iscellstr(names) && ~char_input)
	errormsg('Second argument must be a char or a cell of chars')
elseif char_input
	names_to_check = {names};
else
	names_to_check = names;
end

try
	available_names = IMOS.get(icell,'name');
catch
	errormsg('First argument is not a valid toolbox variable/dimension cell')
end

indexes = whereincell(available_names,names_to_check);

end
