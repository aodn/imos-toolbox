classdef testworkhorseParse < matlab.unittest.TestCase

    % Test Reading Workhorse Signature files with the workhorseParse
    % function.
    %
    % author: hugo.oliveira@utas.edu.au
    %

    properties (TestParameter)
        enu_file = FilesInFolder(fpath('v000/enu'), {'.mat', '.ppp', '.pqc'});
        beam_file = FilesInFolder(fpath('v000/beam'), {'.mat', '.ppp', '.pqc'});

        quartermaster_file = {fpath('v000/enu/16413000.000'), ...
                            fpath('v000/enu/16923000.000'), ...
                            fpath('v000/beam/1759001.000.reduced'), ...
                            };

        longranger_file = {fpath('v000/enu/16072000.000'), ...
                            fpath('/v000/enu/16374000.000'), ...
                            fpath('/v000/enu/16429000.000'), ...
                            fpath('/v000/enu/20814000.000'), ...
                            };

        sentinel_file = {fpath('/v000/enu/16679000.000')};
        %TODO: search for dvs files
        %dvs = {};

        %TODO: search for wave files
        %wave = {};

    end

    methods (Test)

        function testReadingENU_version_regression(~)
            %This test regression/issue #741
            %https://github.com/aodn/imos-toolbox/issues/741
            %by comparing UVEL and VVEL in a sentinel file
            %data loaded with the toolbox version 2.6.9

            sentinel_file = fpath('/v000/enu/16679000.000');
            sentinel_mat_file = fpath('/v000/mat/16679000.000_v2.6.9.mat');

            previous_data = load(sentinel_mat_file);
            pvars = IMOS.as_named_struct(previous_data.sample_data.variables);

            new_data = workhorseParse({sentinel_file},'');
            nvars = IMOS.as_named_struct(new_data.variables);

            p_ucur = pvars.UCUR_MAG.data;
            n_ucur = nvars.UCUR_MAG.data;
            assert(isequal_tol(p_ucur,n_ucur)); 

            p_vcur = pvars.VCUR_MAG.data;
            n_vcur = nvars.VCUR_MAG.data;
            assert(isequal_tol(p_vcur,n_vcur));

            p_heading = pvars.HEADING_MAG.data;
            n_heading = nvars.HEADING_MAG.data;
            assert(isequal_tol(p_heading,n_heading)) % this pass

        end

        function testReadingENU(~, enu_file)
            data = workhorseParse({enu_file}, '');
            check_metadata_consistency(data);
            is_enu_dataset = strcmpi(data.meta.adcp_info.coords.frame_of_reference, 'earth');
            assert(is_enu_dataset);
            check_dimensions_consistency(data, is_enu_dataset);
            check_timeseries_variables(data);
            assert(is_enu_dataset)
            check_v2d_consistency(data, is_enu_dataset);
            check_vel_names(data, is_enu_dataset);
        end

    end

    methods (Test)

        function testReadingBEAM(~, beam_file)
            data = workhorseParse({beam_file}, '');
            check_metadata_consistency(data);
            is_enu_dataset = false;
            assert(strcmpi(data.meta.adcp_info.coords.frame_of_reference, 'beam'));
            check_dimensions_consistency(data, is_enu_dataset);
            check_timeseries_variables(data);
            check_v2d_consistency(data, is_enu_dataset);
            check_vel_names(data, is_enu_dataset);
        end

        function testLongRangerMeta(~, longranger_file)
            data = workhorseParse({longranger_file}, '');
            assert(strcmpi(data.meta.adcp_info.model_name, 'Long Ranger'))
            assert(isequal(int64(data.meta.adcp_info.system_freq), int64(75)))
            assert(isequal(int64(data.meta.adcp_info.xmit_voltage_scale), int64(2092719)))
        end

        function testQuartermasterMeta(~, quartermaster_file)
            data = workhorseParse({quartermaster_file}, '');
            assert(strcmpi(data.meta.adcp_info.model_name, 'Quartermaster'))
            assert(isequal(int64(data.meta.adcp_info.system_freq), int64(150)))
            assert(isequal(int64(data.meta.adcp_info.xmit_voltage_scale), int64(592157)))

        end

        function testSentinelMeta(~, sentinel_file)
            data = workhorseParse({sentinel_file}, '');
            assert(strcmpi(data.meta.adcp_info.model_name, 'Sentinel or Monitor'))

            try
                assert(isequal(int64(data.meta.adcp_info.system_freq), int64(300)))
                assert(isequal(int64(data.meta.adcp_info.xmit_voltage_scale), int64(592157)))
            catch

                try
                    assert(isequal(int64(data.meta.adcp_info.system_freq), int64(600)))
                    assert(isequal(int64(data.meta.adcp_info.xmit_voltage_scale), int64(380667)))

                catch
                    assert(isequal(int64(data.meta.adcp_info.system_freq), int64(1200)))
                    assert(isequal(int64(data.meta.adcp_info.xmit_voltage_scale), int64(253765)))

                end

            end

        end

    end

end

function [path] = fpath(arg)
    path = [toolboxRootPath 'data/testfiles/Teledyne/workhorse/' arg];
end

function check_metadata_consistency(data)
    assert(isfield(data, 'toolbox_input_file'))
    assert(isempty(data.meta.featureType))
    assert(strcmpi(data.meta.instrument_make, 'Teledyne RDI'))
    assert(contains(data.meta.instrument_model, 'Workhorse ADCP'))
    assert(isequal(data.meta.beam_angle, 20.))
    assert(isfield(data.meta, 'adcp_info'))
    assert(strcmpi(data.meta.adcp_info.beam_pattern, 'convex'))
    assert(strcmpi(data.meta.adcp_info.beam_config, '4-BEAM JANUS CONFIG'))
end

function check_dimensions_consistency(data, is_enu_dataset)

    if is_enu_dataset
        assert(length(data.dimensions) == 3)
    else
        assert(length(data.dimensions) == 2)
    end

    dim_names = IMOS.get(data.dimensions, 'name');

    assert(inCell(dim_names, 'TIME'))
    assert(inCell(dim_names, 'DIST_ALONG_BEAMS'))

    if is_enu_dataset
        assert(inCell(dim_names, 'HEIGHT_ABOVE_SENSOR'))
    end

    for k = 1:numel(data.dimensions)
        assert(IMOS.dinfo(data.dimensions{k}).isvector)
    end

    upward_looking = strcmpi(data.meta.adcp_info.beam_face_config, 'up');

    if upward_looking
        assert(all(sign(data.dimensions{2}.data) > 0))

        if is_enu_dataset
            assert(all(sign(data.dimensions{3}.data) > 0))
        end

    else
        assert(all(sign(data.dimensions{2}.data) < 0))

        if is_enu_dataset
            assert(all(sign(data.dimensions{3}.data) < 0))
        end

    end

end

function check_timeseries_variables(data)
    dims = IMOS.as_named_struct(data.dimensions);
    size_to_match = size(dims.('TIME').data);
    is_ts_var = @(x)(~isempty(x) & isequal(x, 1));
    indexes = find(cellfun(is_ts_var, IMOS.get(data.variables, 'dimensions')));

    for k = 1:numel(indexes)
        vdata = data.variables{indexes(k)}.data;
        vcoords = data.variables{indexes(k)}.coordinates;
        assert(isequal(size(vdata), size_to_match))
        assert(contains(vcoords, 'TIME'))
        assert(contains(vcoords, 'NOMINAL_DEPTH'))
    end

end

function bool = is_enu_variable(vname)
    allowed_enu_variables = {'UCUR', 'VCUR', 'WCUR', 'ECUR', 'CSPD', 'CDIR', 'UCUR_MAG', 'VCUR_MAG', 'CDIR_MAG'};
    bool = ~isempty(intersect(vname, allowed_enu_variables));
end

function bool = is_beam_variable(vname)
    allowed_beam_variables = {'VEL1', 'VEL2', 'VEL3', 'VEL4'};
    bool = ~isempty(intersect(vname, allowed_beam_variables));
end

function check_v2d_consistency(data, is_enu_dataset)
    dims = IMOS.as_named_struct(data.dimensions);

    is_2d_var = @(x)(~isempty(x) && isequal(size(x), [1, 2]));
    indexes = find(cellfun(is_2d_var, IMOS.get(data.variables, 'dimensions')));

    nbeams = 0;

    for k = 1:numel(indexes)
        var = data.variables{indexes(k)};
        vdnames = IMOS.get_dimension_names(data.dimensions, data.variables, var.name);

        if is_enu_variable(var.name) && is_enu_dataset
            size_to_match = [numel(dims.('TIME').data), numel(dims.('HEIGHT_ABOVE_SENSOR').data)];
            assert(isequal(size(var.data), size_to_match))
            assert(isequal(vdnames, {'TIME', 'HEIGHT_ABOVE_SENSOR'}))
            assert(contains(var.coordinates, 'HEIGHT_ABOVE_SENSOR'))
        else
            size_to_match = [numel(dims.('TIME').data), numel(dims.('DIST_ALONG_BEAMS').data)];
            assert(isequal(size(var.data), size_to_match))
            assert(isequal(vdnames, {'TIME', 'DIST_ALONG_BEAMS'}))
            assert(contains(var.coordinates, 'DIST_ALONG_BEAMS'))
        end

    end

end

function check_vel_names(data, is_enu_dataset)
    vnames = IMOS.get(data.variables, 'name');

    enu_with_mag = is_enu_dataset && data.meta.compass_correction_applied ~= 0;
    enu_without_mag = is_enu_dataset && data.meta.compass_correction_applied == 0;

    if enu_with_mag
        name0 = 'UCUR';
        name1 = 'VCUR';
        name2 = 'WCUR';
        name3 = 'ECUR';
    elseif enu_without_mag
        name0 = 'UCUR_MAG';
        name1 = 'VCUR_MAG';
        name2 = 'WCUR';
        name3 = 'ECUR';
    else
        name0 = 'VEL1';
        name1 = 'VEL2';
        name2 = 'VEL3';
        name3 = 'VEL4';

    end

    assert(inCell(vnames, name0));
    assert(inCell(vnames, name1));
    assert(inCell(vnames, name2));

    if data.meta.adcp_info.number_of_beams > 3
        assert(inCell(vnames, name3));
    end

end
