function [names] = get_dimension_names(dims, vars, vname)
% function [names] = get_dimension_names(dims,vars,vname)
%
% Return the dimensions names associated with a variable name.
%
% Inputs:
%
% dims [cell{struct}] - the toolbox dimensions cell.
% vars [cell{struct}] - the toolbox variables cell.
% vname [str] - the variable name.
%
% Outputs:
%
% names [cell[str]] - The dimension names.
%
% Example:
%
% %basic usage
% dims = IMOS.gen_dimensions('',2,{'TIME','LATITUDE'},{@single,@single},{(1:5)',(10:20)'});
% vars = IMOS.gen_variables(dims,{'time_only','time_and_latitude'},{@double,@double},{ones(5,1),zeros(5,11)});
% assert(isequal(IMOS.get_dimension_names(dims,vars,'time_only'),{'TIME'}))
% assert(isequal(IMOS.get_dimension_names(dims,vars,'time_and_latitude'),{'TIME','LATITUDE'}))
%
%
% author: hugo.oliveira@utas.edu.au
%
[~, vind] = inCell(IMOS.get(vars, 'name'), vname);

if isempty(vind)
    names = {};
else
	vdims = vars{vind}.dimensions;
    dnames = IMOS.get(dims, 'name');
    n = numel(vdims);
    names = cell(1,n);
    for k = 1:n
        names{k} = dnames{vdims(k)};
    end

end

end
