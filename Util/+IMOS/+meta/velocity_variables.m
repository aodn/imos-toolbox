function [vnames] = velocity_variables(sample_data)
% function [vnames] = velocity_variables(sample_data)
%
% Get the velocity variable names (UCUR,VCUR,and variants)
% from a dataset.
%
% Inputs:
%
% sample_data [struct] - the toolbox dataset.
%
% Outputs:
%
% vnames [cell{str}] - A cell with velocity variable names.
%
% Example:
%
% %basic usage
% dims = IMOS.gen_dimensions('adcp');
% vars = IMOS.gen_variables(dims,{'VEL1','VEL2','UCUR','VCUR'});
% x.variables = vars;
% vnames = IMOS.meta.velocity_variables(x);
% assert(isempty(setdiff(vnames,{'UCUR','VCUR','VEL1','VEL2'})));
% x.variables = IMOS.gen_variables(dims,{'UCUR_MAG','VCUR_MAG','WCUR'});
% vnames = IMOS.meta.velocity_variables(x);
% assert(isempty(setdiff(vnames,{'UCUR_MAG','VCUR_MAG','WCUR'})));
%
% % ambiguity is not handled.
% x.variables = IMOS.gen_variables(dims,{'UCUR','UCUR_MAG'});
% vnames = IMOS.meta.velocity_variables(x);
% assert(isempty(setdiff(vnames,{'UCUR','UCUR_MAG'})))
%
%
% author: hugo.oliveira@utas.edu.au
%
narginchk(1,1);
try
	varcell = sample_data.variables;
catch
	errormsg('No variable fieldname available.')
end
avail_variables = IMOS.get(varcell,'name');
allowed_variables = {'UCUR_MAG','UCUR','VCUR_MAG','VCUR','WCUR','WCUR_2','ECUR','VEL1','VEL2','VEL3','VEL4'};
vnames=cell(1,numel(allowed_variables));
c=0;
for k= 1:numel(avail_variables)
	vname = avail_variables{k};
	if inCell(allowed_variables,vname)
		c=c+1;
		vnames{c} = vname;
	end
end
vnames=vnames(1:c);
end
