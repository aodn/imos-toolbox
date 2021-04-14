function [varnames] = variables_with_dimensions(dims, vars, dnamecell)
% function [varnames] = variables_with_dimensions(dims, vars, dnamecell)
%
% Return variable names with certain named dimensions, in order.
%
% Inputs:
%
% dims [cell{struct}] - The toolbox dimensions cell.
% vars [cell{struct}] - The toolbox variables cell.
% dnamecell [cell{str}] - A cell with dimension names.
%
% Outputs:
%
% varnames [cell{str}] - A cell with variable names.
%
% Example:
%
% %basic usage
%
% dims = IMOS.gen_dimensions('timeSeries',3,{'x','y','z'},{@double,@double,@double},{(1:5)',(1:10)',(1:15)'});
% vars = IMOS.gen_variables(dims,{'a','b','c'},{@double,@double,@double},{zeros(5,10),zeros(1,10),zeros(5,15)});
% a = IMOS.variables_with_dimensions(dims,vars,{'x','y'});
% assert(isequal(a,{'a'}))
% b = IMOS.variables_with_dimensions(dims,vars,{'y'});
% assert(isequal(b,{'b'}))
% c = IMOS.variables_with_dimensions(dims,vars,{'x','z'});
% assert(isequal(c,{'c'}))
% none = IMOS.variables_with_dimensions(dims,vars,{'x'});
% assert(isempty(none))
%
%
% author: hugo.oliveira@utas.edu.au
%
narginchk(3, 3)

if ~IMOS.is_toolbox_dimcell(dims)
    errormsg('First argument is not a toolbox dimensions cell')
end

if ~IMOS.is_toolbox_varcell(vars)
    errormsg('Second argument is not a toolbox variables cell')
end

if ~iscellstr(dnamecell)
    errormsg('Third argument is not a cell of strings')
end

allvars = IMOS.get(vars, 'name');
nvars = numel(allvars);
varnames = cell(1, nvars);
c = 0;

for k = 1:numel(allvars)
    vname = allvars{k};
    vdims = IMOS.get_dimension_names(dims, vars, vname);
    contain_dim = isequal(vdims, dnamecell);

    if contain_dim
        c = c + 1;
        varnames{c} = vname;
    end

end

varnames = varnames(1:c);
end
