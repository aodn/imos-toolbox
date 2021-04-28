function [sample_data, varChecked, paramsLog] = imosEchoIntensitySetQC(sample_data, ~)
%function [sample_data, varChecked, paramsLog] = imosEchoIntensitySetQC(sample_data, ~)
%
% A Echo intensity test for ADCPs using a threshold.
%
% The detection is done by inspecting the ADCP bin profile
% echo amplitude first-order gradient. Everything above the
% `echo_intensity_threshold` option is marked as bad.
%
% Everything beyond the first threshold marking may also be
% marked as bad, if the `propagate` option is true. This is useful
% for surface detection.
%
% As well, if `bound_by_depth` or `bound_by_index` is True, than
% bad markings are bounded by the `bound_value` option.
% This is useful to filter the echo amplitude QC markings to only
% further specific depths or bin indexes.
% 
% See imosEchoIntensitySetQC.txt options.
%
%
% Example:
% % see test_imosEchoIntensitySetQC.m
%
% author: hugo.oliveira@utas.edu.au [refactored from multiple versions of imosSurfaceDetectionQC,imosEchoIntensityVelocitySetQC, and others].
%
%
narginchk(1, 2);
varChecked = {};
paramsLog = [];
currentQCtest = mfilename;
if ~isstruct(sample_data), error('sample_data must be a struct'); end

[valid, reason] = IMOS.validate_dataset(sample_data, currentQCtest);

if ~valid
    %TODO: we may need to include a global verbose flag to avoid pollution here.
    unwrapped_msg = ['Skipping %s. Reasons: ' cell2str(reason,'')];
    dispmsg(unwrapped_msg,sample_data.toolbox_input_file)
    return
end

avail_variables = IMOS.get(sample_data.variables, 'name');
absic_counter = sum(contains(avail_variables, 'ABSIC'));
absic_vars = cell(1, absic_counter);

for k = 1:absic_counter
    absic_vars{k} = ['ABSIC' num2str(k)];
end

if isfield(sample_data, 'history') && ~contains(sample_data.history, 'adcpBinMappingPP.m')
    dispmsg('%s is not using bin-mapped variables.', sample_data.toolbox_input_file)
end

options = IMOS.resolve.function_parameters();
threshold = options('echo_intensity_threshold');
propagate = options('propagate');
bound_by_depth = options('bound_by_depth');
bound_by_index = options('bound_by_index');
bound_value = options('bound_value');

nt = numel(IMOS.get_data(sample_data.dimensions, 'TIME'));

if IMOS.adcp.is_along_beam(sample_data)
    bin_dist = IMOS.get_data(sample_data.dimensions, 'DIST_ALONG_BEAMS');
    dims_tz = {'TIME', 'DIST_ALONG_BEAMS'};
    nbeams = numel(absic_vars);
else
    bin_dist = IMOS.get_data(sample_data.dimensions, 'HEIGHT_ABOVE_SENSOR');
    dims_tz = {'TIME', 'HEIGHT_ABOVE_SENSOR'};
    nbeams = numel(absic_vars);
end

flag_vars = IMOS.variables_with_dimensions(sample_data.dimensions, sample_data.variables, dims_tz);

switch nbeams
    case 3
        non_flag_vars = {'PERG1', 'PERG2', 'PERG3', 'CMAG1', 'CMAG2', 'CMAG3'};
        flag_vars = setdiff(flag_vars, non_flag_vars);
    case 4
        non_flag_vars = {'PERG1', 'PERG2', 'PERG3', 'PERG4', 'CMAG1', 'CMAG2', 'CMAG3', 'CMAG4'};
        flag_vars = setdiff(flag_vars, non_flag_vars);
end

% Now compute threshold and apply mask.
% The order is:
% 1.Compute threshold, 2. Bound detections by index or depth, 3. propagate detections further away in the beam.

nz = numel(bin_dist);
absic_extended = zeros(nt, nz + 1);
beyond_threshold = zeros(nt, nz, 'logical');
first_order_diff = 1;
along_z = 2;

for k = 1:absic_counter
    varname = absic_vars{k};
    absic = IMOS.get_data(sample_data.variables, varname);
    absic_extended(:, 1) = absic(:, 1);
    absic_extended(:, 2:end) = absic;
    echodiff = abs(diff(absic_extended, first_order_diff, along_z));
    beyond_threshold = beyond_threshold | echodiff > threshold;
end

if bound_by_index || bound_by_depth
    do_index_bound = bound_by_index && bound_value > 0 && bound_value <= nz;
    do_depth_bound = ~do_index_bound && bound_value > 0 && bound_by_depth && ~isempty(IMOS.get_data(sample_data.variables, 'DEPTH'));

    invalid_options = ~do_index_bound && ~do_depth_bound;

    if invalid_options
        dispmsg('Bound option invalid in parameter file %s.', [mfilename '.txt']);
    end

else
    do_index_bound = false;
    do_depth_bound = false;
end

if do_index_bound
    beyond_threshold(:,1:bound_value) = 0; %keep further bin as detected.
elseif do_depth_bound
    idepth = IMOS.get_data(sample_data.variables, 'DEPTH');
    [t, z] = find(beyond_threshold);
    bin_depths_at_invalid_points = idepth(t) - bin_dist(z); %TxZ arr
    upward_looking = all(bin_dist > 0);

    if upward_looking
        bins_before_depth = find(bin_depths_at_invalid_points >= bound_value);
    else
        bins_before_depth = find(bin_depths_at_invalid_points <= bound_value);
    end

    rind = sub2ind(size(beyond_threshold), t(bins_before_depth), z(bins_before_depth));
    beyond_threshold(rind) = 0;
end

if propagate
    [t, z] = find(beyond_threshold);

    if ~isempty(t)
        beyond_threshold(t(1), z(1):end) = 1;
        prev_t = t(1);

        for k = 2:numel(t)

            if t(k) == prev_t
                continue
            else
                prev_t = t(k);
                %because array is NTxNZ, z is ordered
                beyond_threshold(t(k), z(k):end) = 1;
            end

        end

    end

end

qcSet = str2double(readProperty('toolbox.qc_set'));
badFlag = imosQCFlag('bad', qcSet, 'flag');
goodFlag = imosQCFlag('good', qcSet, 'flag');

flags = ones(size(beyond_threshold), 'int8') * goodFlag;
flags(beyond_threshold) = badFlag;

flag_vars_inds = IMOS.find(sample_data.variables, flag_vars);
for k = 1:numel(flag_vars_inds)
    vind = flag_vars_inds(k);
    sample_data.variables{vind}.flags = flags;
end

varChecked = flag_vars;
nbadbins = sum(beyond_threshold, 1);
near_bad_bin = find(nbadbins, 1, 'first');
further_bad_bin = find(nbadbins, 1, 'last');

paramsLog = ['echo_intensity_threshold=' threshold, 'propagate=', propagate, 'near_bad_bin=' near_bad_bin, 'further_bad_bin=' further_bad_bin];

writeDatasetParameter(sample_data.toolbox_input_file, currentQCtest, 'echo_intensity_threshold', threshold);

end
