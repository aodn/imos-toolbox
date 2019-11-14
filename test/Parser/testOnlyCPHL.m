classdef testOnlyCPHL < matlab.unittest.TestCase

    % Test CPHL is the only loaded parameter in instruments
    % with fluorescence instrument variables.
    %
    % author: hugo.oliveira@utas.edu.au
    %

    properties (TestParameter)
        mode = struct('timeSeries', 'timeSeries'); %, 'profile', 'profile');

        ecot_v000_param = getfield(chla_inputs(), 'ecot_v000_param');
        ecot_reader = {@ECOTripletParse};

        jfe_v000_param = getfield(chla_inputs(), 'jfe_v000_param');
        jfe_reader = {@infinitySDLoggerParse};

        %rbr
        solo_v000_param = getfield(chla_inputs(), 'solo_v000_param');
        solo_reader = {@XRParse};

        % tr1060_v000_param = getfield(chla_inputs(), 'tr1060_v000_param');
        % tr1060_reader = {@XRParse};

        twr2050_v000_param = getfield(chla_inputs(), 'twr2050_v000_param');
        twr2050_reader = {@XRParse};

        xr420_v000_param = getfield(chla_inputs(), 'xr420_v000_param')
        xr420_reader = {@XRParse};

        xr620_v000_param = getfield(chla_inputs(), 'xr620_v000_param')
        xr620_reader = {@XRParse};

        %sbs
        sbe19p_v000_param = getfield(chla_inputs(), 'sbe19p_v000_param');
        sbe19p_reader = {@SBE19Parse};

        sbe25p_v000_param = getfield(chla_inputs(), 'sbe25p_v000_param');
        sbe25p_reader = {@SBE19Parse};

        sbe9p_v000_param = getfield(chla_inputs(), 'sbe9p_v000_param');
        sbe9p_reader = {@SBE19Parse};

        wqmraw_v000_param = getfield(chla_inputs(), 'wqmraw_v000_param');
        wqmraw_reader = {@readWQMraw};

        wqmdat_v000_param = getfield(chla_inputs(), 'wqmdat_v000_param');
        wqmdat_reader = {@readWQMdat};
    end

    methods (Test)

        function test_ecot(testCase, ecot_reader, ecot_v000_param, mode)
            data = ecot_reader({ecot_v000_param}, mode);
            assert(check_cphl(data));
        end

        function test_jfe(testCase, jfe_reader, jfe_v000_param, mode)
            data = jfe_reader({jfe_v000_param}, mode);
            assert(check_cphl(data));
        end

        function test_solo(testCase, solo_reader, solo_v000_param, mode)
            data = solo_reader({solo_v000_param}, mode);
            assert(check_cphl(data));
        end

        % TODO: investigate further files available not working
        % function test_tr1060(testCase, tr1060_reader, tr1060_v000_param, mode)
        %     data = tr1060_reader({tr1060_v000_param}, mode);
        %     assert(check_cphl(data));
        % end

        function test_twr2050(testCase, twr2050_reader, twr2050_v000_param, mode)
            data = twr2050_reader({twr2050_v000_param}, mode);
            assert(check_cphl(data));
        end

        function test_xr420(testCase, xr420_reader, xr420_v000_param, mode)
            data = xr420_reader({xr420_v000_param}, mode);
            assert(check_cphl(data));
        end

        function test_xr620(testCase, xr620_reader, xr620_v000_param, mode)
            data = xr620_reader({xr620_v000_param}, mode);
            assert(check_cphl(data));
        end

        function test_sbe19p(testCase, sbe19p_reader, sbe19p_v000_param, mode)
            data = sbe19p_reader({sbe19p_v000_param}, mode);
            assert(check_cphl(data));
        end

        function test_sbe25p(testCase, sbe25p_reader, sbe25p_v000_param, mode)
            data = sbe25p_reader({sbe25p_v000_param}, mode);
            assert(check_cphl(data));
        end

        function test_sbe9p(testCase, sbe9p_reader, sbe9p_v000_param, mode)
            data = sbe9p_reader({sbe9p_v000_param}, mode);
            assert(check_cphl(data));
        end

        function test_wqmraw(testCase, wqmraw_reader, wqmraw_v000_param, mode)
            data = wqmraw_reader(wqmraw_v000_param, mode);
            assert(check_cphl(data));
        end

        function test_wqmdat(testCase, wqmdat_reader, wqmdat_v000_param, mode)
            data = wqmdat_reader(wqmdat_v000_param, mode);
            assert(check_cphl(data));
        end

        function test_aquatrackapp(~,sbe19p_reader,sbe19p_v000_param,mode)
            data = sbe19p_reader({sbe19p_v000_param},mode);
            %fake volt_cphl variable
            for k=1:length(data.variables)
                if contains(data.variables{k}.name,'CPHL')
                    newvar = data.variables{k};
                    newvar.name = 'volt_CHL';
                    data.variables{end+1} = newvar;
                    break
                end
            end
            output = aquatrackaPP({data},'qc',0);
            data = output{1};
            comment = data.variables{end}.comment;
            assert(check_cphl(data));
            assert(contains(comment,'analogic input'));
            assert(contains(comment,'scaleFactor='));
            assert(contains(comment,'offset='));
        end

    end

end

function [e] = chla_inputs(varargin)
% function e = chla_inputs()
%
% load instrument files that can hold fluorescence data
%
% Inputs:
%
% Outputs:
%
% e - a structure for testing.
% e.name_param = filenames as structures for test referecing
%
% author: hugo.oliveira@utas.edu.au
%
fullpath = @fullfile;

e.root_folder = toolboxRootPath();    
e.ecot_folder = fullpath(e.root_folder, 'data/testfiles/ECOTriplet/v000/');

ecot_v000 = FilesInFolder(e.ecot_folder);

c = 0;
for k = 1:length(ecot_v000)

    if contains(ecot_v000{k}, '.raw')
        c = c + 1;
        e.ecot_v000_files{c} = ecot_v000{k};
    end

end
e.ecot_v000_param = files2namestruct(e.ecot_v000_files);

e.jfe_folder = fullpath(e.root_folder, 'data/testfiles/JFE/v000/');
e.jfe_v000_files = FilesInFolder(e.jfe_folder);
e.jfe_v000_param = files2namestruct(e.jfe_v000_files);

e.solo_folder = fullpath(e.root_folder, 'data/testfiles/RBR/solo/v000/');
e.solo_v000_files = FilesInFolder(e.solo_folder);
e.solo_v000_param = files2namestruct(e.solo_v000_files);
% e.tr1060_folder = fullpath(e.root_folder, 'data/testfiles/RBR/TR-1060/v000/');
% e.tr1060_v000_files = FilesInFolder(e.tr1060_folder);
% e.tr1060_v000_param = files2namestruct(e.tr1060_v000_files);

e.tdr2050_folder = fullpath(e.root_folder, 'data/testfiles/RBR/TDR-2050/v000/');
e.tdr2050_v000_files = FilesInFolder(e.tdr2050_folder);
e.tdr2050_v000_param = files2namestruct(e.tdr2050_v000_files);

e.twr2050_folder = fullpath(e.root_folder, 'data/testfiles/RBR/TWR-2050/v000/');
e.twr2050_v000_files = FilesInFolder(e.twr2050_folder);
e.twr2050_v000_param = files2namestruct(e.twr2050_v000_files);

e.xr420_folder = fullpath(e.root_folder, 'data/testfiles/RBR/XR420/v000/');
e.xr420_v000_files = FilesInFolder(e.xr420_folder);
e.xr420_v000_param = files2namestruct(e.xr420_v000_files);

e.xr620_folder = fullpath(e.root_folder, 'data/testfiles/RBR/XR620/v000/');
e.xr620_v000_files = FilesInFolder(e.xr620_folder);
e.xr620_v000_param = files2namestruct(e.xr620_v000_files);

e.sbe19p_folder = fullpath(e.root_folder, 'data/testfiles/Sea_Bird_Scientific/SBE/19plus/v000/');
e.sbe19p_v000_files = FilesInFolder(e.sbe19p_folder);
e.sbe19p_v000_param = files2namestruct(e.sbe19p_v000_files);

e.sbe25p_folder = fullpath(e.root_folder, 'data/testfiles/Sea_Bird_Scientific/SBE/25plus/v000/');
e.sbe25p_v000_files = FilesInFolder(e.sbe25p_folder);
e.sbe25p_v000_param = files2namestruct(e.sbe25p_v000_files);

e.sbe9p_folder = fullpath(e.root_folder, 'data/testfiles/Sea_Bird_Scientific/SBE/9plus/v000/');
e.sbe9p_v000_files = FilesInFolder(e.sbe9p_folder);
e.sbe9p_v000_param = files2namestruct(e.sbe9p_v000_files);

e.wqmraw_folder = fullpath(e.root_folder, 'data/testfiles/Sea_Bird_Scientific/WQM/RAW/v000/');
e.wqmraw_v000_files = FilesInFolder(e.wqmraw_folder);
e.wqmraw_v000_param = files2namestruct(e.wqmraw_v000_files);

e.wqmdat_folder = fullpath(e.root_folder, 'data/testfiles/Sea_Bird_Scientific/WQM/DAT/v000/');
e.wqmdat_v000_files = FilesInFolder(e.wqmdat_folder);
e.wqmdat_v000_param = files2namestruct(e.wqmdat_v000_files);
end

function [is_cphl, is_numbered, number] = check_cphl(data)
% function is_cphl = check_cphl(data)
%
% Check if chlf and chlu are not defined in the data
% structure and if any cphl is numbered or not
%
% Inputs:
%
% data - the struct output of a Instrument Parser func
%
% Outputs:
%
% is_cphl - a is_cphlean indicating if chlf or chlu are missing.
% is_numbered - a is_cphlean indicating multiple cphl
% number - the number of cphl definitions
%
% author: hugo.oliveira@utas.edu.au
%
is_cphl = false;
is_numbered = false;
number = [];
vars = data.variables;

cn = 1;

for k = 1:length(vars)
    v = vars{k};
    vname = v.name;

    if strcmpi(vname, 'CHLF')
        return
    elseif strcmpi(vname, 'CHLU')
        return
    elseif contains(vname, 'CPHL')

        if contains(vname, '_')
            is_numbered = true;
            cn = cn + 1;
            number = cn;
        end

    end

end

is_cphl = true;
end
