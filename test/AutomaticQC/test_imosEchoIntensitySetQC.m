classdef test_imosEchoIntensitySetQC < matlab.unittest.TestCase

    properties (TestParameter)
        zdim = {'HEIGHT_ABOVE_SENSOR', 'DIST_ALONG_BEAMS'}
    end

    methods (TestMethodTeardown)

        function reset_default_options(~)
            file = which('imosEchoIntensitySetQC');
            file(end:end + 2) = 'txt';
            updateMappings(file, 'echo_intensity_threshold', 50);
            updateMappings(file, 'bound_by_depth', 0);
            updateMappings(file, 'bound_by_index', 0);
            updateMappings(file, 'bound_value', 99999);
            updateMappings(file, 'propagate', 0);
        end

    end

    methods (Test)

        function test_simple_detection(~, zdim)
            % only data 500:600,11 is bad.
            sample_data = create_simple_data(zdim);
            new = imosEchoIntensitySetQC(sample_data);
            flag = new.variables{end}.flags;
            assert(all(flag(500:600, 1:13) == 1, 'all'))
            assert(all(flag(500:600, 14) == 4, 'all'))
            assert(all(flag(500:600, 15:end) == 1, 'all'))
        end

        function test_simple_detection_upward_propagate(~, zdim)
            % only data 500:600,11 is bad.
            sample_data = create_simple_data(zdim);
            switch_option('propagate', 1);
            new = imosEchoIntensitySetQC(sample_data);
            flag = new.variables{end}.flags;
            assert(all(flag(500:600, 1:13) == 1, 'all'))
            assert(all(flag(500:600, 14:end) == 4, 'all'))
        end

        function test_simple_detection_downward_propagate(~, zdim)
            % only data 500:600,11 is bad.
            sample_data = create_simple_data(zdim, -1 * (10:10:200)');
            switch_option('propagate', 1);
            new = imosEchoIntensitySetQC(sample_data);
            flag = new.variables{end}.flags;
            assert(all(flag(500:600, 1:13) == 1, 'all'))
            assert(all(flag(500:600, 14:end) == 4, 'all'))
        end

        function test_simple_detection_both_dimensions_mark_only_echo_vars(~)
            sample_data = create_simple_data('HEIGHT_ABOVE_SENSOR');
            hdim = sample_data.dimensions{2};
            new_dim = IMOS.gen_dimensions('', 1, {'DIST_ALONG_BEAMS'}, {@double}, {hdim.data});
            sample_data.dimensions{end + 1} = new_dim{1};
            new_var = sample_data.variables{end};
            new_var.name = 'PERG1';
            new_var.dimensions = [1, 3]; %cant use gen_variables since dimensions are the dubious.
            sample_data.variables{end + 1} = new_var;

            new = imosEchoIntensitySetQC(sample_data);
            v = IMOS.as_named_struct(new.variables);
            flag = v.('ABSIC1').flags;
            assert(all(flag(500:600, 1:13) == 1, 'all'))
            assert(all(flag(500:600, 14) == 4, 'all'))
            assert(all(flag(500:600, 15:end) == 1, 'all'))

            f = fieldnames(v.('PERG1'));
            assert(~inCell(f,'flags'))

        end

        function test_bound_by_depth_upward_clean_marked(~, zdim)
            depth_constraint = 30; %only shallower than 30m is allowed markings.
            site_nominal_depth = 170; % 14th bad bin will be at 30m, so will be clear out
            sample_data = create_simple_data(zdim, (10:10:200)', site_nominal_depth);
            switch_option('bound_by_depth', 1);
            switch_option('bound_value', depth_constraint);
            switch_option('propagate', 0);
            new = imosEchoIntensitySetQC(sample_data);
            flag = new.variables{end}.flags;
            assert(all(flag == 1, 'all'))
        end

        function test_bound_by_depth_downward_clean_marked(~, zdim)
            depth_constraint = 140; %only deeper than 140m is allowed markings.
            site_nominal_depth = 0; % 14th bin will be clear.
            sample_data = create_simple_data(zdim, -1 * (10:10:200)', site_nominal_depth);
            switch_option('bound_by_depth', 1);
            switch_option('bound_value', depth_constraint);
            switch_option('propagate', 0);
            new = imosEchoIntensitySetQC(sample_data);
            flag = new.variables{end}.flags;
            assert(all(flag == 1, 'all'))
        end

        function test_bound_by_depth_upward_simple(~, zdim)
            depth_constraint = 40; %above 40m to be marked.
            site_nominal_depth = 140 + depth_constraint; % bindepth of 14th bin  + constraint
            zrange = 0;
            sample_data = create_simple_data(zdim, (10:10:200)', site_nominal_depth, zrange);
            echo_ind = IMOS.find(sample_data.variables, 'ABSIC1');
            sample_data.variables{echo_ind}.data(500:600, 14) = 205; % increase gradient so 15th bin is also marked.
            % we now unmark all bins deeper than 40m. and keep everything as detected above 40m.
            switch_option('bound_by_depth', 1);
            switch_option('bound_value', depth_constraint);
            switch_option('propagate', 0);
            new = imosEchoIntensitySetQC(sample_data);
            flag = new.variables{end}.flags;
            assert(all(flag(500:600, 1:14) == 1, 'all'))
            assert(all(flag(500:600, 15) == 4, 'all'))
            assert(all(flag(500:600, 16:end) == 1, 'all'))
        end

        function test_bound_by_depth_upward_zeta(~, zdim)
            depth_constraint = 40; %above 40m to be marked.
            site_nominal_depth = 140 + depth_constraint; % bindepth of 14th bin  + constraint
            zrange = 2;
            sample_data = create_simple_data(zdim, (10:10:200)', site_nominal_depth, zrange);
            echo_ind = IMOS.find(sample_data.variables, 'ABSIC1');
            sample_data.variables{echo_ind}.data(500:600, 14) = 205; % increase gradient so 15th bin is also marked.
            % we now unmark some bins deeper than 40m. and keep everything as detected shallower than 40m.
            switch_option('bound_by_depth', 1);
            switch_option('bound_value', depth_constraint);
            switch_option('propagate', 0);
            new = imosEchoIntensitySetQC(sample_data);
            flag = new.variables{end}.flags;
            assert(all(flag(500:600, 1:13) == 1, 'all'))
            assert(any(flag(500:600, 1:14) == 4, 'all'))
            assert(all(flag(500:600, 15) == 4, 'all'))
            assert(all(flag(500:600, 16:end) == 1, 'all'))
            switch_option('propagate', 1)
            new = imosEchoIntensitySetQC(sample_data);
            flag = new.variables{end}.flags;
            assert(all(flag(500:600, 1:13) == 1, 'all'))
            assert(any(flag(500:600, 1:14) == 4, 'all'))
            assert(all(flag(500:600, 15:end) == 4, 'all'))

        end

        function test_bound_by_depth_downward_simple(~, zdim)
            depth_constraint = 140; %only deeper than 600m is allowed markings.
            site_nominal_depth = 300; % bindepth of 14th bin will be 440m
            sample_data = create_simple_data(zdim, -1 * (10:10:200)', site_nominal_depth);
            echo_ind = IMOS.find(sample_data.variables, 'ABSIC1');
            sample_data.variables{echo_ind}.data(500:600, 14) = 205; % increase gradient so 15th bin is also marked.
            % now unmark bins at 440m but keep all detected towards the bottom.
            switch_option('bound_by_depth', 1);
            switch_option('bound_value', depth_constraint);
            switch_option('propagate', 0);
            new = imosEchoIntensitySetQC(sample_data);
            flag = new.variables{end}.flags;
            assert(all(flag(500:600, 1:14) == 1, 'all'))
            assert(all(flag(500:600, 15) == 4, 'all'))
            assert(all(flag(500:600, 16:end) == 1, 'all'))
        end

        function test_bound_by_depth_downward_zeta(~, zdim)
            depth_constraint = 140; %only deeper than 600m is allowed markings.
            site_nominal_depth = 300; % bindepth of 14th bin will be 440m
            zrange = 2;
            sample_data = create_simple_data(zdim, -1 * (10:10:200)', site_nominal_depth, zrange);
            echo_ind = IMOS.find(sample_data.variables, 'ABSIC1');
            sample_data.variables{echo_ind}.data(500:600, 14) = 205; % increase gradient so 15th bin is also marked.
            % now unmark some bins around 40m but keep all beyond 40m to the surface.
            switch_option('bound_by_depth', 1);
            switch_option('bound_value', depth_constraint);
            switch_option('propagate', 0);
            new = imosEchoIntensitySetQC(sample_data);
            flag = new.variables{end}.flags;
            assert(all(flag(500:600, 1:13) == 1, 'all'))
            assert(any(flag(500:600, 1:14) == 4, 'all'))
            assert(all(flag(500:600, 15) == 4, 'all'))
            assert(all(flag(500:600, 16:end) == 1, 'all'))
            switch_option('propagate', 1);
            new = imosEchoIntensitySetQC(sample_data);
            flag = new.variables{end}.flags;
            assert(all(flag(500:600, 1:13) == 1, 'all'))
            assert(any(flag(500:600, 1:14) == 4, 'all'))
            assert(all(flag(500:600, 15:end) == 4, 'all'))
        end

        function test_realdata_bound_index(~)
            % this file is clipped to out of water points.
            % There are several above the threshold at the first bin interface and two points at bin26.
            % We will ignore the first bin interface gradients with a bound index, and match the two bad data.
            adcp_file = fullfile(toolboxRootPath, 'data/testfiles/Teledyne/workhorse/v000/beam/16072000.000.reduced');
            sample_data = load_binmapped_sample_data(adcp_file);
            time = IMOS.get_data(sample_data.dimensions, 'TIME');
            height_above_sensor = IMOS.get_data(sample_data.dimensions, 'HEIGHT_ABOVE_SENSOR');
            beam_height = IMOS.adcp.beam_height(height_above_sensor);
            idepth = transpose(randomBetween(100, 200, numel(time)));
            sdepth = IMOS.gen_variables(sample_data.dimensions, {'DEPTH'}, {@double}, {idepth}, 'positive', 'down');
            sample_data.variables{end + 1} = sdepth{1};
            sample_data.site_nominal_depth = beam_height - mode(idepth);

            new = imosEchoIntensitySetQC(sample_data);
            u_flag = new.variables{IMOS.find(new.variables, 'VEL1')}.flags;
            assert(all(u_flag(:, 1) == 1, 'all'))
            assert(any(u_flag(:, 2) == 4, 'all'))
            assert(all(u_flag(:, 3:25) == 1, 'all'))
            assert(sum(u_flag(:, 26) == 4) == 2)
            assert(all(u_flag(:, 27:end) == 1, 'all'))

            switch_option('bound_by_index', 1)
            switch_option('bound_value', 25); % 1:25 always good.

            new = imosEchoIntensitySetQC(sample_data);
            u_flag = new.variables{IMOS.find(new.variables, 'VEL1')}.flags;
            v_flag = new.variables{IMOS.find(new.variables, 'VEL2')}.flags;
            w_flag = new.variables{IMOS.find(new.variables, 'VEL3')}.flags;
            e_flag = new.variables{IMOS.find(new.variables, 'VEL4')}.flags;
            a1_flag = new.variables{IMOS.find(new.variables, 'ABSIC1')}.flags;
            a2_flag = new.variables{IMOS.find(new.variables, 'ABSIC2')}.flags;
            a3_flag = new.variables{IMOS.find(new.variables, 'ABSIC3')}.flags;
            a4_flag = new.variables{IMOS.find(new.variables, 'ABSIC4')}.flags;
            assert(isequal(u_flag, v_flag, w_flag, e_flag, a1_flag, a2_flag, a3_flag, a4_flag));
            assert(all(u_flag(:, 1:25) == 1, 'all'))
            assert(sum(u_flag(:, 26) == 4) == 2)
            assert(all(u_flag(:, 27:end) == 1, 'all'))

            converted = adcpWorkhorseVelocityBeam2EnuPP({sample_data}, '');
            switch_option('bound_by_index', 1)
            switch_option('bound_value', 26)
            new = imosEchoIntensitySetQC(converted{1});
            u_flag = new.variables{IMOS.find(new.variables, 'UCUR_MAG')}.flags;
            v_flag = new.variables{IMOS.find(new.variables, 'VCUR_MAG')}.flags;
            w_flag = new.variables{IMOS.find(new.variables, 'WCUR')}.flags;
            e_flag = new.variables{IMOS.find(new.variables, 'ECUR')}.flags;
            assert(isequal(u_flag, v_flag, w_flag, e_flag));
            assert(all(u_flag == 1, 'all'))

        end

    end

end

function switch_option(optname, optvalue)
    file = which('imosEchoIntensitySetQC');
    file(end:end + 2) = 'txt';
    updateMappings(file, optname, optvalue);
end

function [binmapped] = load_binmapped_sample_data(file)
    data = workhorseParse({file}, '');
    binmapped = adcpBinMappingPP({data}, '');
    binmapped = binmapped{1};
end

function [sample_data] = create_simple_data(zdim_name, bin_dist, site_nominal_depth, zrange)
% Create a simple test adcp dataset
% The instrument depth is at the bottom for upward looking, and at the surface
% for downward looking.
% The depth is contaminated with oscillations of ~[-zrange,+zrange] dbar,
% and echo intensity is randomized between 100-150 counts.
% A detectable echo intensity count is found between 500-600 timestamps
% at the 14th bin with magnitude == 51 counts, which is above
% the default threshold of the test.
time = (1:1000)';

if nargin < 2
    bin_dist = (10:10:200)';
end

if nargin < 3
    site_nominal_depth = NaN;
end

if nargin < 4
    zrange = 0;
end

dims = IMOS.gen_dimensions('adcp', 2, {'TIME', zdim_name}, {@double, @double}, {time, bin_dist}); %upward looking == positive depth
zeta = randomBetween(-zrange, zrange, numel(time));

if all(bin_dist > 0)
    instrument_depth = transpose(site_nominal_depth + zeta);
else
    instrument_depth = transpose(zeta);
end

vars_0 = randomBetween(100, 150, 1000 * 20);
vars_0 = reshape(vars_0, 1000, 20);
vars_0(500:600, 14) = 201; % default threshold is 50, so fail at index 14.
vars_0(500:600, 15) = 151; %drop off to only actually mark at index 14.
vars_0(500:600, 16) = 141; %as above
vars = IMOS.gen_variables(dims, {'DEPTH', 'UCUR', 'ABSIC1'}, {@double, @double, @double}, {instrument_depth, vars_0, vars_0});
sample_data.dimensions = dims;
sample_data.variables = vars;
sample_data.site_nominal_depth = site_nominal_depth;
sample_data.toolbox_input_file = fullfile(toolboxRootPath, 'tmp', 'testdriven');
end
