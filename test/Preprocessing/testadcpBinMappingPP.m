classdef testadcpBinMappingPP < matlab.unittest.TestCase

    % Test adcpBinMappingPP refactored code.
    %
    % The largest code change
    %
    % by hugo.oliveira@utas.edu.au
    %
    properties (TestParameter)
        rdi_file = {[toolboxRootPath 'data/testfiles/Teledyne/workhorse/v000/beam/1759001.000.reduced'], };
        enu_file = {[toolboxRootPath 'data/testfiles/Teledyne/workhorse/v000/enu/16072000.000'], };

    end

    methods (Test)

        function test_dont_remove_dist_along_beams_when_perg_and_data_is_enu(test)
            s = workhorseParse(test.enu_file, '');
            bs = adcpBinMappingPP({s}, '');
            bs = bs{1};
            dims = IMOS.as_named_struct(bs.dimensions);
            vars = IMOS.as_named_struct(bs.variables);
            assert(isfield(dims, 'DIST_ALONG_BEAMS'))
            assert(isfield(dims, 'HEIGHT_ABOVE_SENSOR'))
            expected_coords = 'TIME LATITUDE LONGITUDE DIST_ALONG_BEAMS';

            for k = 1:4
                varname = ['PERG' num2str(k)];
                assert(isfield(vars, varname))
                assert(strcmpi(expected_coords, vars.(varname).coordinates))
            end

        end

        function test_mapping_RDI_beam_velocity(test)
            s = workhorseParse(test.rdi_file, '');
            bs = adcpBinMappingPP({s}, '');
            bs = bs{1};

            bin_mapping_string = 'has been vertically bin-mapped to HEIGHT_ABOVE_SENSOR using tilt information';
            dim_removed_string = 'DIST_ALONG_BEAMS is not used by any variable left and has been removed';

            assert(isfield(bs, 'history'))
            assert(contains(bs.history, bin_mapping_string))
            assert(~contains(bs.history, dim_removed_string))

            vars_to_check = {'VEL1', 'VEL2', 'VEL3', 'VEL4'};
            mapped = IMOS.as_named_struct(bs.variables);
            raw = IMOS.as_named_struct(s.variables);

            for k = 1:length(vars_to_check)
                vname = vars_to_check{k};
                assert(isfield(mapped.(vname), 'comment'))
                assert(contains(mapped.(vname).comment, bin_mapping_string));
                [~, ~, p] = isequal_tol(raw.(vname).data, mapped.(vname).data);
                assert(p < 0.1, 'Data similiary larger than 10% - Data is possible not beam mapped')
            end

        end

        function test_removal_of_dangling_dist_along_beams_dims(test)
            s = workhorseParse(test.rdi_file, '');
            %remove perg variables
            perg1_ind = IMOS.find(s.variables, 'PERG1');
            perg2_ind = IMOS.find(s.variables, 'PERG2');
            perg3_ind = IMOS.find(s.variables, 'PERG3');
            perg4_ind = IMOS.find(s.variables, 'PERG4');
            inds = 1:length(s.variables);
            no_dab_inds = setxor(inds, [perg1_ind, perg2_ind, perg3_ind, perg4_ind]);
            s.variables = s.variables(no_dab_inds);

            bs = adcpBinMappingPP({s}, '');
            bs = bs{1};

            bin_mapping_string = 'has been vertically bin-mapped to HEIGHT_ABOVE_SENSOR using tilt information';
            dim_removed_string = 'DIST_ALONG_BEAMS is not used by any variable left and has been removed';

            assert(isfield(bs, 'history'))
            assert(contains(bs.history, bin_mapping_string))
            assert(contains(bs.history, dim_removed_string))
        end

        function testRDI_old_mapping_to_new_mapping_code(test)
            base_file = load([toolboxRootPath 'data/testfiles/Teledyne/workhorse/v000/beam/1759001.000.reduced.old_mapping.mat']);
            old_struct = base_file.sample_data;
            raw_struct = workhorseParse(test.rdi_file, '');
            new_struct = adcpBinMappingPP({raw_struct}, '');
            new_struct = new_struct{1};
            vars_to_check = {'ABSIC1', 'ABSIC2', 'ABSIC3', 'ABSIC4', 'CMAG1', 'CMAG2', 'CMAG3', 'CMAG4'}; %cant check velocities since old code was not mapping VELs.
            old = IMOS.as_named_struct(old_struct.variables);
            new = IMOS.as_named_struct(new_struct.variables);
            ndecimal = 3;

            for k = 1:length(vars_to_check)
                vname = vars_to_check{k};
                [~, ~, percent_equal] = isequal_tol(old.(vname).data, new.(vname).data, ndecimal);
                assert(percent_equal > .99, 'Data differs by more than 1% of the total number of data points');
            end

        end

    end

end
