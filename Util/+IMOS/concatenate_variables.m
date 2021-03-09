function [v] = concatenate_variables(vcell,names)
%function [v] = concatenate_variables(vcell,names)
%
% Right most concatenation of toolbox variables.
%
% Inputs:
%
% vcell [cell{struct}] - the toolbox variable cell
% names [cell{str}] - the variable names to be concantenated.
%
% Outputs:
% 
% v [any] - A MxNxO...xC, where the right most dimension
%           `C` is created to store the sequential 
%           matched variables.
%
% Example:
%
% dims = IMOS.gen_dimensions('timeSeries',2,{'TIME','X'},{},{(1:10)',(1:100)'});
% vars = IMOS.gen_variables(dims,{'TEMP','PSAL'},{},{zeros(10,100),ones(10,100)});
% cv = IMOS.concatenate_variables(vars,{'PSAL','TEMP','PSAL'});
% assert(isequal(size(cv),[10,100,3]))
% assert(all(cv(:,:,1)==1,'all'))
% assert(all(cv(:,:,2)==0,'all'))
% assert(all(cv(:,:,3)==1,'all'))
% 
%
% author: hugo.oliveira@utas.edu.au
%

narginchk(2,2)

if ~iscellstruct(vcell)
    errormsg('First argument not a cell of structs')
elseif isempty(vcell)
    errormsg('First argument is empty')
elseif ~iscellstr(names)
    errormsg('Second argument not a cell of chars')
elseif isempty(names)
    errormsg('Second argument is empty')
end

allnames = IMOS.get(vcell,'name');
vnames = allnames(whereincell(allnames,names));
nvars = length(vnames);
data = cell(1,nvars);
for k=1:nvars
    data{k} = IMOS.get_data(vcell,vnames{k});
end
v = cat(length(size(data{k}))+1,data{:});
end
