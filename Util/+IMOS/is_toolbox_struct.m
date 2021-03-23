function [bool] = is_toolbox_struct(sample_data)
% function [bool] = is_toolbox_struct(sample_data)
%
% Check if a struct is a toolbox struct.
% A toolbox struct contains:
% non-empty toolbox_input_file field of type [char].
% non-empty meta field of type [struct] with generic fields.
% non-empty toolbox dimensions cell.
% non-empty toolbox variable cell.
%
% Inputs:
%
% sample_data[struct | of cell{struct}] - a struct (cell of) to be checked.
%
% Outputs:
%
% bool - False if not a toolbox structure. True otherwise.
%
% Example:
%
% %basic usage
% meta = struct('a','a');
% dims = IMOS.gen_dimensions();
% vars =IMOS.gen_variables(dims);
% s.toolbox_input_file = 'a';
% s.meta = meta;
% s.dimensions = dims;
% s.variables = vars;
% assert(IMOS.is_toolbox_struct(s))
%
% %wrong dim
% s2 = s;
% s2.dimensions{end} = struct();
% assert(~IMOS.is_toolbox_struct(s2));
%
% %wrong var
% s3 = s;
% s3.variables{end} = struct();
% assert(~IMOS.is_toolbox_struct(s3));
%
% %multi structs
% assert(all(IMOS.is_toolbox_struct({s,s,s})))
% assert(~all(IMOS.is_toolbox_struct({s,s,1})))
%
%
% author: hugo.oliveira@utas.edu.au
%
narginchk(1, 1)

n = numel(sample_data);
bool = zeros(1, n, 'logical');

if (~isstruct(sample_data) && ~iscellstruct(sample_data)) || isempty(sample_data)
	return
end

for k = 1:n

	if n>1
		s = sample_data{k};
	else
		s = sample_data;
	end

    invalid_input_file_field = ~isfield(s, 'toolbox_input_file') || ~ischar(s.toolbox_input_file) || isempty(s.toolbox_input_file);

    if invalid_input_file_field
        continue
    end

    invalid_meta = ~isfield(s, 'meta') || ~isstruct(s.meta) || isempty(s.meta);

    if invalid_meta
        continue
    end

    invalid_dimensions = ~isfield(s, 'dimensions') || ~iscellstruct(s.dimensions) || isempty(s.dimensions) || ~IMOS.is_toolbox_dimcell(s.dimensions);

    if invalid_dimensions
        continue
    end

    invalid_variables = ~isfield(s, 'variables') || ~iscellstruct(s.variables) || isempty(s.variables) || ~IMOS.is_toolbox_varcell(s.variables);

    if invalid_variables
        continue
    end

    bool(k) = true;
end
