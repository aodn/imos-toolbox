classdef test_imosSurfaceDetectionByDepthSetQC < matlab.unittest.TestCase

    methods (Test)

        function test_simple_binmapped_detection_minimal_input(~)
            sample_data = create_simple_data('HEIGHT_ABOVE_SENSOR');
            new = imosSurfaceDetectionByDepthSetQC(sample_data);
            flag = new.variables{1}.flags;
            first_bin_at_surface = find(sum(flag == 1, 1) == 0, 1, 'first');
            assert(first_bin_at_surface == 10);
        end

        function test_simple_raw_detection_minimal_input(~)
            sample_data = create_simple_data('DIST_ALONG_BEAMS');
            new = imosSurfaceDetectionByDepthSetQC(sample_data);
            flag = new.variables{1}.flags;
            first_bin_at_surface = find(sum(flag == 1, 1) == 0, 1, 'first');
            assert(first_bin_at_surface == 10);
        end

        function test_raw_file_downward_adcp_bottom_detection(~)
            adcp_file = fullfile(toolboxRootPath, 'data/testfiles/Teledyne/workhorse/v000/beam/16072000.000.reduced');
            sample_data = workhorseParse({adcp_file},'');
            time = IMOS.get_data(sample_data.dimensions, 'TIME');
            height_above_sensor = IMOS.get_data(sample_data.dimensions, 'DIST_ALONG_BEAMS');
            beam_height = IMOS.adcp.beam_height(height_above_sensor);

            % use a instrument deployment depth between 100~200
            % which is the original file depth range.
            min_allowed_depth = 100;
            max_allowed_depth = 200;
            idepth = transpose(randomBetween(min_allowed_depth, max_allowed_depth, numel(time))); %1d vars are stored as col vectors.
            sdepth = IMOS.gen_variables(sample_data.dimensions, {'DEPTH'}, {@double}, {idepth}, 'positive', 'down');
            sample_data.variables{end + 1} = sdepth{1};
            sample_data.site_nominal_depth = beam_height - mode(idepth);

            new = imosSurfaceDetectionByDepthSetQC(sample_data);

            vars_to_check = IMOS.variables_with_dimensions(new.dimensions, new.variables, {'TIME', 'DIST_ALONG_BEAMS'});
            vars_inds = IMOS.find(new.variables, vars_to_check);

            for k = 1:length(vars_inds)
                assert(isfield(new.variables{k}, 'flags'))
                last_water_bin = find(sum(new.variables{k}.flags == 1, 1), 1, 'last'); % look at good ones
                last_waterbin_depth = abs(height_above_sensor(last_water_bin));
                assert(last_waterbin_depth + min_allowed_depth < sample_data.site_nominal_depth)
                assert(last_waterbin_depth + max_allowed_depth < sample_data.site_nominal_depth)
                first_badbin_depth = abs(height_above_sensor(last_water_bin + 1));
                assert(first_badbin_depth - min_allowed_depth > min_allowed_depth)
            end

        end

        function test_binmapped_file_downward_adcp_bottom_detection(~)
            adcp_file = fullfile(toolboxRootPath, 'data/testfiles/Teledyne/workhorse/v000/beam/16072000.000.reduced');
            sample_data = load_binmapped_sample_data(adcp_file);
            time = IMOS.get_data(sample_data.dimensions, 'TIME');
            height_above_sensor = IMOS.get_data(sample_data.dimensions, 'HEIGHT_ABOVE_SENSOR');
            beam_height = IMOS.adcp.beam_height(height_above_sensor);

            % use a instrument deployment depth between 100~200
            % which is the original file depth range.
            min_allowed_depth = 100;
            max_allowed_depth = 200;
            idepth = transpose(randomBetween(min_allowed_depth, max_allowed_depth, numel(time))); %1d vars are stored as col vectors.
            sdepth = IMOS.gen_variables(sample_data.dimensions, {'DEPTH'}, {@double}, {idepth}, 'positive', 'down');
            sample_data.variables{end + 1} = sdepth{1};
            sample_data.site_nominal_depth = beam_height - mode(idepth);

            new = imosSurfaceDetectionByDepthSetQC(sample_data);

            vars_to_check = IMOS.variables_with_dimensions(new.dimensions, new.variables, {'TIME', 'HEIGHT_ABOVE_SENSOR'});
            vars_inds = IMOS.find(new.variables, vars_to_check);

            for k = 1:length(vars_inds)
                assert(isfield(new.variables{k}, 'flags'))
                last_water_bin = find(sum(new.variables{k}.flags == 1, 1), 1, 'last'); % look at good ones
                last_waterbin_depth = abs(height_above_sensor(last_water_bin));
                assert(last_waterbin_depth + min_allowed_depth < sample_data.site_nominal_depth)
                assert(last_waterbin_depth + max_allowed_depth < sample_data.site_nominal_depth)
                first_badbin_depth = abs(height_above_sensor(last_water_bin + 1));
                assert(first_badbin_depth - min_allowed_depth > min_allowed_depth)
            end

        end

        function test_raw_file_upward_adcp_surface_detection(~)
            adcp_file = fullfile(toolboxRootPath, 'data/testfiles/Teledyne/workhorse/v000/beam/1759001.000.reduced');
            sample_data = workhorseParse({adcp_file},'');
            time = IMOS.get_data(sample_data.dimensions, 'TIME');
            height_above_sensor = IMOS.get_data(sample_data.dimensions, 'DIST_ALONG_BEAMS');
            beam_height = IMOS.adcp.beam_height(height_above_sensor);

            n_bad_at_surface = 3;
            first_bad_bin = length(height_above_sensor) - n_bad_at_surface + 1;
            bin_cell_height = mode(diff(height_above_sensor));

            % use beam height as rigid surface with
            % some oscillations with cell_height modulated magnitudes.
            min_allowed_zeta = -bin_cell_height * n_bad_at_surface;
            max_allowed_zeta = +bin_cell_height * n_bad_at_surface;
            zeta = transpose(randomBetween(min_allowed_zeta, max_allowed_zeta, numel(time))); %1d vars are stored as col vectors.
            idepth = beam_height + zeta;
            sdepth = IMOS.gen_variables(sample_data.dimensions, {'DEPTH'}, {@double}, {idepth}, 'positive', 'down');
            sample_data.variables{end + 1} = sdepth{1};
            sample_data.site_nominal_depth = beam_height;

            new = imosSurfaceDetectionByDepthSetQC(sample_data);

            vars_to_check = IMOS.variables_with_dimensions(new.dimensions, new.variables, {'TIME', 'DIST_ALONG_BEAMS'});
            vars_inds = IMOS.find(new.variables, vars_to_check);

            for k = 1:length(vars_inds)
                assert(isfield(new.variables{k}, 'flags'))
                surface_bins = find(sum(new.variables{k}.flags == 4, 1)); % look at bad ones
                assert(numel(surface_bins) == n_bad_at_surface);
                first_surface_bin = min(surface_bins);
                assert(first_surface_bin == first_bad_bin);
                surface_bin_depth_variation = max(idepth) - beam_height;
                assert(isequal_tol(n_bad_at_surface * bin_cell_height, surface_bin_depth_variation, 1))
            end

        end


        function test_binmapped_file_upward_adcp_surface_detection(~)
            adcp_file = fullfile(toolboxRootPath, 'data/testfiles/Teledyne/workhorse/v000/beam/1759001.000.reduced');
            sample_data = load_binmapped_sample_data(adcp_file);
            time = IMOS.get_data(sample_data.dimensions, 'TIME');
            height_above_sensor = IMOS.get_data(sample_data.dimensions, 'HEIGHT_ABOVE_SENSOR');
            beam_height = IMOS.adcp.beam_height(height_above_sensor);

            n_bad_at_surface = 3;
            first_bad_bin = length(height_above_sensor) - n_bad_at_surface + 1;
            bin_cell_height = mode(diff(height_above_sensor));

            % use beam height as rigid surface with
            % some oscillations with cell_height modulated magnitudes.
            min_allowed_zeta = -bin_cell_height * n_bad_at_surface;
            max_allowed_zeta = +bin_cell_height * n_bad_at_surface;
            zeta = transpose(randomBetween(min_allowed_zeta, max_allowed_zeta, numel(time))); %1d vars are stored as col vectors.
            idepth = beam_height + zeta;
            sdepth = IMOS.gen_variables(sample_data.dimensions, {'DEPTH'}, {@double}, {idepth}, 'positive', 'down');
            sample_data.variables{end + 1} = sdepth{1};
            sample_data.site_nominal_depth = beam_height;

            new = imosSurfaceDetectionByDepthSetQC(sample_data);

            vars_to_check = IMOS.variables_with_dimensions(new.dimensions, new.variables, {'TIME', 'HEIGHT_ABOVE_SENSOR'});
            vars_inds = IMOS.find(new.variables, vars_to_check);

            for k = 1:length(vars_inds)
                assert(isfield(new.variables{k}, 'flags'))
                surface_bins = find(sum(new.variables{k}.flags == 4, 1)); % look at bad ones
                assert(numel(surface_bins) == n_bad_at_surface);
                first_surface_bin = min(surface_bins);
                assert(first_surface_bin == first_bad_bin);
                surface_bin_depth_variation = max(idepth) - beam_height;
                assert(isequal_tol(n_bad_at_surface * bin_cell_height, surface_bin_depth_variation, 1))
            end

        end

    end

end

function [binmapped] = load_binmapped_sample_data(file)
    data = workhorseParse({file}, '');
    binmapped = adcpBinMappingPP({data}, '');
    binmapped = binmapped{1};
end

function [sample_data] = create_simple_data(zdim_name)
    dims = IMOS.gen_dimensions('adcp', 2, {'TIME', zdim_name}, {@double, @double}, {(1:1000)', (10:10:200)'}); %upward looking == positive depth
    site_nominal_depth = 91;
    zeta = randomBetween(-1, 1, 1000);
    instrument_depth = transpose(site_nominal_depth + zeta);
    vars_0 = zeros(1000, 20);
    vars = IMOS.gen_variables(dims, {'UCUR', 'DEPTH'}, {@double, @double}, {vars_0, instrument_depth});
    sample_data.dimensions = dims;
    sample_data.variables = vars;
    sample_data.site_nominal_depth = site_nominal_depth;
end
