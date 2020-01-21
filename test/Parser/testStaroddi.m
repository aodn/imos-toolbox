classdef testStaroddi < matlab.unittest.TestCase

    properties (TestParameter)
        mode = struct('timeSeries', 'timeSeries'); %, 'profile', 'profile');
        starmon_mini_v000_param = get_testfiles('Star_oddi', 'mini', 'v000');
        starmon_mini_v000_folder = {get_folder('Star_oddi', 'mini', 'v000')};

        starmon_mini_v001_param = get_testfiles('Star_oddi', 'mini', 'v001');
        starmon_mini_v001_folder = {get_folder('Star_oddi', 'mini', 'v001')};

        starmon_dsttilt_v000_param = get_testfiles('Star_oddi', 'dst_tilt', 'v000');
        starmon_dsttilt_v000_folder = {get_folder('Star_oddi', 'dst_tilt', 'v000')};

        starmon_dstctd_v000_param = get_testfiles('Star_oddi', 'dst_ctd', 'v000');
        starmon_dstctd_v000_folder = {get_folder('Star_oddi', 'dst_ctd', 'v000')};

    end

    methods (Test)
        %%TODO REMOVE after old parsers are deprecated.
        % function testCreateMatfilesMiniv000(~, starmon_mini_v000_param, starmon_mini_v000_folder, mode)
        %     save_mat(StarmonMiniParse({starmon_mini_v000_param}, mode), starmon_mini_v000_param, fullfile(starmon_mini_v000_folder, 'mat'))
        % end

        %%TODO REMOVE after old parsers are deprecated.
        % function testCreateMatfilesDSTTiltv000(~, starmon_dsttilt_v000_param, starmon_dsttilt_v000_folder, mode)
        %     save_mat(StarmonDSTParse({starmon_dsttilt_v000_param}, mode), starmon_dsttilt_v000_param, fullfile(starmon_dsttilt_v000_folder, 'mat'));
        % end

        %%TODO REMOVE after old parsers are deprecated.
        % function testCreateMatfilesDSTCTDv000(~, starmon_dstctd_v000_param, starmon_dstctd_v000_folder, mode)
        %     save_mat(StarmonDSTParse({starmon_dstctd_v000_param}, mode), starmon_dstctd_v000_param, fullfile(starmon_dstctd_v000_folder, 'mat'));
        % end


        function testCompareOldNewParser_mini_v000(~, starmon_mini_v000_param, starmon_mini_v000_folder, mode)
            old_data = load([fullfile(starmon_mini_v000_folder, 'mat', basename(starmon_mini_v000_param)) '.mat']);
            new_data = StaroddiParser(starmon_mini_v000_param, mode);

            [~,newfile,~] = fileparts(new_data.toolbox_input_file);
            [~,oldfile,~] = fileparts(old_data.data.toolbox_input_file);
            assert(strcmp(newfile,oldfile))

            [old_meta, old_dimensions, old_variables] = loadfields(old_data.data);
            [new_meta, new_dimensions, new_variables] = loadfields(new_data);

            [isdiff_meta, why] = treeDiff(old_meta, new_meta);

            if isdiff_meta
                assert(isdiff_meta, why);
            end

            [isdiff_dim, why] = treeDiff(old_dimensions, new_dimensions);

            if isdiff_dim
                assert(isdiff_dim, why);
            end

            [isdiff_var, why] = treeDiff(old_variables, new_variables);

            if isdiff_var
                assert(isdiff_var, why);
            end

        end

        function testCompareOldNewParser_dsttilt_v000(~, starmon_dsttilt_v000_param, starmon_dsttilt_v000_folder, mode)
            old_data = load([fullfile(starmon_dsttilt_v000_folder, 'mat', basename(starmon_dsttilt_v000_param)) '.mat']);
            new_data = StaroddiParser(starmon_dsttilt_v000_param, mode);

            [~,newfile,~] = fileparts(new_data.toolbox_input_file);
            [~,oldfile,~] = fileparts(old_data.data.toolbox_input_file);
            assert(strcmp(newfile,oldfile))

            [old_meta, old_dimensions, old_variables] = loadfields(old_data.data);
            [new_meta, new_dimensions, new_variables] = loadfields(new_data);

            [isdiff_meta, why] = treeDiff(old_meta, new_meta);

            if isdiff_meta
                assert(isdiff_meta, why);
            end

            [isdiff_dim, why] = treeDiff(old_dimensions, new_dimensions);

            if isdiff_dim
                assert(isdiff_dim, why);
            end

            [isdiff_var, why] = treeDiff(old_variables, new_variables);

            if isdiff_var
                assert(isdiff_var, why);
            end

        end

        function testCompareOldNewParser_dstctd_v000(~, starmon_dstctd_v000_param, starmon_dstctd_v000_folder, mode)
            old_data = load([starmon_dstctd_v000_folder '/mat/' basename(starmon_dstctd_v000_param) '.mat']);
            new_data = StaroddiParser(starmon_dstctd_v000_param, mode);

            [~,newfile,~] = fileparts(new_data.toolbox_input_file);
            [~,oldfile,~] = fileparts(old_data.data.toolbox_input_file);
            assert(strcmp(newfile,oldfile))

            [old_meta, old_dimensions, old_variables] = loadfields(old_data.data);
            [new_meta, new_dimensions, new_variables] = loadfields(new_data);

            [isdiff_meta, why] = treeDiff(old_meta, new_meta);

            if isdiff_meta
                assert(isdiff_meta, why);
            end

            [isdiff_dim, why] = treeDiff(old_dimensions, new_dimensions);

            if isdiff_dim
                assert(isdiff_dim, why);
            end

            [isdiff_var, why] = treeDiff(old_variables, new_variables);

            if isdiff_var
                assert(isdiff_var, why);
            end

        end

        function testStaroddiParser_temp_degF(~, mode)
            root_folder = toolboxRootPath();
            file = fullfile(root_folder, 'data', 'testfiles', 'Star_oddi', 'mini', 'v000', '6T3863_degF.DAT');
            new_data = StaroddiParser(file, mode);
            varid = getVar(new_data.variables, 'TEMP');
            var = new_data.variables{varid};
            assert(contains(var.comment, 'expressed in Fahrenheit'));
            assert(min(var.data) >= 25.03);
            assert(max(var.data) <= 25.56);
        end

        function testStaroddiParser_temp_correction(~, mode)
            root_folder = toolboxRootPath();
            file = fullfile(root_folder, 'data', 'testfiles', 'Star_oddi', 'mini', 'v000', '6T3863_t_reconvert.DAT');
            [new_data, sdata] = StaroddiParser(file, mode);

            % temp correction
            is_temp_corrected = isfield(sdata.header_info, 'no_temperature_correction') &&~sdata.header_info.no_temperature_correction;
            assert(is_temp_corrected)

            varid = getVar(new_data.variables, 'TEMP_2');
            var = new_data.variables{varid};
            assert(contains(var.comment, 'correction applied'));
        end

        function testStaroddiParser_pres_correction(~, mode)
            root_folder = toolboxRootPath();
            file = fullfile(root_folder, 'data', 'testfiles', 'Star_oddi', 'dst_ctd', 'v000', '42S8171_correction.DAT');
            [new_data, sdata] = StaroddiParser(file, mode);

            % pres correction
            is_pres_corrected = isfield(sdata.header_info, 'pressure_offset_correction') && sdata.header_info.pressure_offset_correction;
            assert(is_pres_corrected)

            varid = getVar(new_data.variables, 'PRES_REL');
            var = new_data.variables{varid};
            assert(contains(var.comment, 'adjusted'));
        end

        function testStaroddiParser_psal_correction(~, mode)
            root_folder = toolboxRootPath();
            file = fullfile(root_folder, 'data', 'testfiles', 'Star_oddi', 'dst_ctd', 'v000', '42S8171_correction.DAT');
            [new_data, sdata] = StaroddiParser(file, mode);

            % pres correction
            is_pres_corrected = isfield(sdata.header_info, 'pressure_offset_correction') && sdata.header_info.pressure_offset_correction;
            assert(is_pres_corrected)

            varid = getVar(new_data.variables, 'PRES_REL');
            var = new_data.variables{varid};
            assert(contains(var.comment, 'mbar was adjusted'));

            varid = getVar(new_data.variables, 'PSAL_2');
            var = new_data.variables{varid};
            assert(contains(var.comment, 'mbar was adjusted to pressure'));
        end

        function testStaroddiParser_mini_v000(~, starmon_mini_v000_param, mode)
            new_data = StaroddiParser(starmon_mini_v000_param, mode);
            assert(strcmp(new_data.meta.instrument_make, 'Star ODDI'));
            assert(strcmp(new_data.meta.instrument_model, 'Starmon Mini'));
            assert(length(new_data.dimensions) == 1);
            assert(length(new_data.variables) > 4);
        end

        function testStaroddiParser_mini_v001(~, starmon_mini_v001_param, mode)
            new_data = StaroddiParser(starmon_mini_v001_param, mode);
            assert(strcmp(new_data.meta.instrument_make, 'Star ODDI'));
            assert(strcmp(new_data.meta.instrument_model, 'Starmon mini')); % yes - mini lowercase now...
            assert(length(new_data.dimensions) == 1);
            assert(length(new_data.variables) > 4);
        end

        function testStaroddiParser_dsttilt_v000(~, starmon_dsttilt_v000_param, mode)
            new_data = StaroddiParser(starmon_dsttilt_v000_param, mode);
            assert(strcmp(new_data.meta.instrument_make, 'Star ODDI'));
            assert(contains(new_data.meta.instrument_model, 'DST Tilt'));
            assert(length(new_data.dimensions) == 1);
            assert(length(new_data.variables) > 4);
        end

        function testStaroddiParser_dstctd_v000(~, starmon_dstctd_v000_param, mode)
            new_data = StaroddiParser(starmon_dstctd_v000_param, mode);
            assert(strcmp(new_data.meta.instrument_make, 'Star ODDI'));
            assert(contains(new_data.meta.instrument_model, 'DST CTD'));
            assert(length(new_data.dimensions) == 1);
            assert(length(new_data.variables) > 4);
        end

    end

end

function [m, d, v] = loadfields(idata)
%
% grab metadata, dimensons and variables
% A one-liner to save 4 lines.
%
m = rmfield(idata.meta, 'header');
m = orderfields(m); % required for tree matching.
d = idata.dimensions;
v = idata.variables;
end

function [param, files, folder] = get_testfiles(maker, model, version)
%
% get param,files, and folder testfiles information for a certain
% instrument maker/model and version.
%
root_folder = toolboxRootPath();
folder = fullfile(root_folder, 'data', 'testfiles', maker, model, version);
files = FilesInFolder(folder);
param = files2namestruct(files);
end

function [folder] = get_folder(maker, model, version)
%
% wrapper to obtain only folder
%
[~, ~, folder] = get_testfiles(maker, model, version);
end

%function save_mat(data, tparam, outfolder)
%%
%% save a mat file to outfolder/tparam.mat
%%
%fs = char(tparam);
%file = [basename(fs) '.mat'];
%omat = fullfile(outfolder, file);
%save(omat, 'data');
%end
