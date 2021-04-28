function [bool, reason] = imosEchoIntensitySetQC(sample_data)
% function [bool,reason] = imosEchoIntensitySetQC(sample_data)
%
% Check if sample_data is a valid input for SurfaceDetectionByEchoIntensityQC.
%
% Inputs:
%
% sample_data [struct] - A toolbox dataset.
%
% Outputs:
%
% bool - True if dataset is valid. False otherwise.
% reason - The reasons why the dataset is invalid.
%
% Example:
%
% %see test_imosEchoIntensitySetQC.
%
% author: hugo.oliveira@utas.edu.au
%
narginchk(1,1)
reason = {};

if ~IMOS.adcp.contains_adcp_dimensions(sample_data)
    reason{1} = 'Not an adcp file.';
end

avail_variables = IMOS.get(sample_data.variables,'name');
absic_counter = sum(contains(avail_variables,'ABSIC'));
if absic_counter == 0
    reason{end+1} = 'Missing ABSIC variables.';
end

vel_vars = IMOS.meta.velocity_variables(sample_data);
if numel(vel_vars) == 0
    reason{end+1} = 'Missing at leat one velocity variable to flag.';
end


if absic_counter > 4
    reason{end+1} = 'Number of ABSIC variables is invalid';
end

if isempty(reason)
    bool = true;
else
    bool = false;
end

end
