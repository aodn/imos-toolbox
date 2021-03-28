function [bool, n] = var_contains_dim(dataset, vname, dname)
% function [bool,n] = var_contains_dim(dataset,vname,dname)
%
% Detect if a variable in a dataset contains a dimension name,
% and which dimension index it is.
%
% Inputs:
%
% dataset [struct] - the toolbox dataset.
% vname [char | cell ] - the variable name (or names if cell).
% dname [char] - the dimension name.
%
% Outputs:
%
% bool [logical] [1xN]- True if vname(vname{ind}) is along `dname`.
%                       False otherwise. N = length(vname),
%                       if vname is a cell.
%
% n  [double | cell{double}] - the dimension index of
%                              vname(vname{ind}) array.
%
% Example:
%
% %basic usage
% dims = IMOS.gen_dimensions('timeSeries',3,{'TIME','X','Y'},{},{(1:5)', (1:10)', (1:20)'});
% vars = IMOS.gen_variables(dims,{'A_TXY','B_TX','C_TY','D_XY','E_T'},{},{zeros(5,10,20),zeros(5,10),zeros(20,5),zeros(10,20),zeros(1,5)});
% dataset.dimensions = dims;
% dataset.variables = vars;
% assert(all(IMOS.var_contains_dim(dataset,{'A_TXY','C_TY','E_T'},'TIME')))
% assert(all(IMOS.var_contains_dim(dataset,{'A_TXY','B_TX','D_XY'},'X')))
% assert(all(IMOS.var_contains_dim(dataset,{'A_TXY','C_TY','D_XY'},'Y')));
% assert(~IMOS.var_contains_dim(dataset,'E_T','X'));
% assert(~IMOS.var_contains_dim(dataset,'E_T','Y'));
%
%
% author: hugo.oliveira@utas.edu.au
%
narginchk(3, 3)

if ~isstruct(dataset) || ~isfield(dataset, 'dimensions') || ~IMOS.is_toolbox_dimcell(dataset.dimensions) || ~isfield(dataset, 'variables') || ~IMOS.is_toolbox_varcell(dataset.variables)
    errormsg('First argument not a toolbox struct')
elseif isempty(vname) || (~ischar(vname) && ~iscellstr(vname))
    errormsg('Second argument not a valid char or a cell of chars')
elseif isempty(dname) || ~ischar(dname)
    errormsg('Third argument not a valid char')
end

if iscell(vname)
    l = numel(vname);
else
    l = 1;
end

vardimnames = cell(1, l);
bool = zeros(1, l);
n = zeros(1, l);

if l == 1
    vardimnames = IMOS.get_dimension_names(dataset.dimensions, dataset.variables, vname);
    [bool, n] = inCell(vardimnames, dname);
else

    for k = 1:numel(vname)
        vardimnames{k} = IMOS.get_dimension_names(dataset.dimensions, dataset.variables, vname{k});
        [bool(k), n(k)] = inCell(vardimnames{k}, dname);
    end

end
