classdef testVoltageParameters < matlab.unittest.TestCase

    % Test Reading correct Voltage Parameters from several parsers.
    %
    % author: hugo.oliveira@utas.edu.au
    %

    properties (TestParameter)
        mode = {'timeSeries'};

        jfe_file = files2namestruct(rdir([toolboxRootPath 'data/testfiles/JFE']))
        awac_file = files2namestruct(filter_wpr(rdir([toolboxRootPath 'data/testfiles/Nortek/awac'])))
        continental_file = files2namestruct(rdir([toolboxRootPath 'data/testfiles/Nortek/continental']))
        signature_file = files2namestruct([rdir([toolboxRootPath 'data/testfiles/Nortek/signature_250']), rdir([toolboxRootPath 'data/testfiles/Nortek/signature_500']), rdir([toolboxRootPath 'data/testfiles/Nortek/signature_1000'])])
        aquadoppProfile_file = files2namestruct(rdir([toolboxRootPath 'data/testfiles/Nortek/aquadopp_profile']))
        aquadoppVelocity_file = files2namestruct(rdir([toolboxRootPath 'data/testfiles/Nortek/aquadopp_velocity']))
        fsi_file = files2namestruct(rdir([toolboxRootPath 'data/testfiles/FSI/nxic_ctd']))

        %TODO enable tests for rcm/ysi 
        %rcm_file = files2namestruct(rdir([toolboxRootPath 'data/testfiles/RCM'])) % files not workign with current parser
        % ysi_file = files2namestruct(rdir([toolboxRootPath 'data/testfiles/YSI'])) % no files avail

    end

    methods (Test)


        function testBatVoltageJFE(~, jfe_file, mode)
            data = infinitySDLoggerParse({jfe_file}, mode);
            assert(any(contains(get_varnames(data), 'BAT_VOLT')))
        end

        function testBatVoltageAwac(~, awac_file, mode)
            data = awacParse({awac_file}, mode);
            assert(any(contains(get_varnames(data), 'BAT_VOLT')))
        end

        function testBatVoltageContinental(~, continental_file, mode)
            data = continentalParse({continental_file}, mode);
            assert(any(contains(get_varnames(data), 'BAT_VOLT')))
        end

        function testBatVoltageSignature(~, signature_file, mode)
            data = signatureParse({signature_file}, mode);
            for k = 1:length(data)
                assert(any(contains(get_varnames(data{k}), 'BAT_VOLT')))
            end

        end
 
        function testBatVoltageAquadoppProfile(~, aquadoppProfile_file)
            data = aquadoppProfilerParse({aquadoppProfile_file}, 'Profile');
            assert(any(contains(get_varnames(data), 'BAT_VOLT')))
        end
 
        function testBatVoltageAquadoppVelocity(~, aquadoppVelocity_file)
            data = aquadoppVelocityParse({aquadoppVelocity_file}, 'Profile');
            assert(any(contains(get_varnames(data), 'BAT_VOLT')))
        end
      
        function testBatVoltageFSI(~, fsi_file, mode)
            data = NXICBinaryParse({fsi_file}, mode);
            assert(any(contains(get_varnames(data), 'BAT_VOLT')))
        end

        %TODO YSI6 enable tests when files are available
        %function testBatVoltageYSI(~, ysi_file, mode)
        %    data = YSI6SeriesParse({ysi_file}, mode);
        %    assert(any(contains(get_varnames(data), 'BAT_VOLT')))
        %end
        
        %TODO RCM enable tests when files are available 
        %function testBatVoltageRCM(~, rcm_file, mode)
        %    data = RCMParse({rcm_file}, mode);
        %    assert(any(contains(get_varnames(data), 'BAT_VOLT')))
        %end

    end

end

function wprfiles = filter_wpr(files)
%
% filter list of files
% to only contain wpr binary files
%
mask = contains(files, '.wpr');
wprfiles = {files{mask}};
end

function varnames = get_varnames(x)
%
% return a cell with varnames
% from an IMOS sample_data
% structure
%
get_single_name = @(x) x.name;
get_all_variable_names = @(x) cellfun(get_single_name, x.variables, 'UniformOutput', false);
varnames = get_all_variable_names(x);
end
