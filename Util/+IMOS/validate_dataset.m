function [bool, reason] = validate_dataset(sample_data, fname)
% function [bool,reason] = validate_dataset(sample_data,fname)
%
% Validate a toolbox dataset against a function name.
%
% The idea of this function is to execute the associated
% `fname` schema function, which verifies the feasability
% of the sample_data content for use within `fname` function.
%
% Think all the checks you do at a function but wrapped in
% one call.
%
% Inputs:
%
% sample_data [struct] - a toolbox sample data.
% fname [string] = the function name.
%
% Outputs:
%
% bool[logical] - True if dataset is accepted by fname.
% reason [cell{str}] - The reasons why the dataset is invalid for fname.
%
% Example:
%
% %basic usage
%
%
% author: hugo.oliveira@utas.edu.au
%
func = ['IMOS.schemas.' fname];
try
	feval(func)
	missing_schema = true;
catch me
	missing_schema = ~strcmpi(me.message,'Not enough input arguments.');
end

if missing_schema
	errormsg('Schema %s not available',fname);
end

try
    [bool, reason] = feval(func, sample_data);
catch
    bool = false;
    reason{1} = sprintf('%s failed.', func);
end

end
