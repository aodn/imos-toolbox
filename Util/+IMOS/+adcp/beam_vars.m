function [ibvars] = beam_vars(sample_data, n)
%function [ibvars] = beam_vars(sample_data,n)
%
% Get the available beam variable names
% based on the beam number.
% If beam number is not provided, all variables
% names that are along beams are returned.
%
% Inputs:
%
% sample_data [struct] - the toolbox struct.
% n [double] - the beam number [1-4]
%
% Outputs:
%
% ibvars [cell{str}] - the variable names associated
%                      with the beam number.
%
% Example:
%
% time = (1:100)';
% dab = (1:10)';
% dummy = zeros(100,10);
% type = @double;
% dims = IMOS.gen_dimensions('adcp',2,{'TIME','DIST_ALONG_BEAMS'},{type,type},{time,dab});
% vars = IMOS.gen_variables(dims,{'VEL1','ABSIC1','VEL3','ABSIC3'},{type,type,type,type},{dummy,dummy,dummy,dummy});
% sample_data.dimensions = dims;
% sample_data.variables = vars;
% beam_vars_1 = IMOS.adcp.beam_vars(sample_data,1);
% assert(numel(whereincell(beam_vars_1,{'ABSIC1','VEL1'}))==2)
% assert(numel(whereincell(beam_vars_1,{'VEL3','ABSIC3'}))==0)
%
% %beam 3
% beam_vars_3 = IMOS.adcp.beam_vars(sample_data,3);
% assert(numel(whereincell(beam_vars_3,{'ABSIC1','VEL1'}))==0)
% assert(numel(whereincell(beam_vars_3,{'VEL3','ABSIC3'}))==2)
%
% %all beams available
% all_beams = IMOS.adcp.beam_vars(sample_data);
% assert(numel(whereincell(all_beams,{'VEL1','ABSIC1','ABSIC3','VEL3'}))==4)
%
% %got a beam_variable name but dimensions are not aligned with DIST_ALONG_BEAMS
% dummy = zeros(100,100);
% vars = IMOS.gen_variables(dims,{'VEL1'},{type},{dummy});
% sample_data.dimensions = dims;
% sample_data.variables = vars;
% beam_vars_1 = IMOS.adcp.beam_vars(sample_data,1);
% assert(isempty(beam_vars_1))
%
%
% author: hugo.oliveira@utas.edu.au
%
%
narginchk(1, 2)

if nargin<2
	get_all_beam_vars = true;
	n=inf;
else
	get_all_beam_vars = false;
end


if ~isstruct(sample_data)
    error('Frist argument not a toolbox struct')
end

beam_vars_1 = {'ABSI1', 'ABSIC1', 'CMAG1', 'SNR1', 'VEL1'};
beam_vars_2 = {'ABSI2', 'ABSIC2', 'CMAG2', 'SNR2', 'VEL2'};
beam_vars_3 = {'ABSI3', 'ABSIC3', 'CMAG3', 'SNR3', 'VEL3'};
beam_vars_4 = {'ABSI4', 'ABSIC4', 'CMAG4', 'VEL4'};

switch n
    case 1
        beam_vars = beam_vars_1;
    case 2
        beam_vars = beam_vars_2;
    case 3
        beam_vars = beam_vars_3;
    case 4
        beam_vars = beam_vars_4;
    otherwise
		if get_all_beam_vars
			beam_vars = [beam_vars_1, beam_vars_2, beam_vars_3, beam_vars_4];
		else
   	        errormsg('Second argument not a valid beam number')
		end
end

%double check if dimensions are
ibvars = cell(1, length(beam_vars));
is_a_beam_var = @(sample_data, varname)(IMOS.var_contains_dim(sample_data, varname, 'DIST_ALONG_BEAMS'));

c = 0;

for k = 1:length(beam_vars)

    if is_a_beam_var(sample_data, beam_vars{k})
        c = c + 1;
        ibvars{c} = beam_vars{k};
    end

end

ibvars = ibvars(1:c);
end
