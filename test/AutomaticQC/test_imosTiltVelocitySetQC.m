classdef test_imosTiltVelocitySetQC < matlab.unittest.TestCase

    properties
        testUI = true;
    end

    methods (Test)

        function test_load_nortek_current_meter_values(~)
            ssize = [5, 1];
            sample_data = create_sample_data(ssize);
            sample_data.variables{end}.data = zeros(5,1); %roll
            sample_data.variables{end - 1}.data = zeros(5,1)+90; %pitch
            sample_data.instrument = 'Nortek Aquadopp Current Meter';
            e_logentry = 'firstTiltThreshold=30, secondTiltThreshold=45';
            v = sample_data.variables{1}.data * 0;

            v3 = v + 3;
            [pdata, ~, logentry] = imosTiltVelocitySetQC(sample_data, true);
            assert(isequal(pdata.variables{1}.flags, v3))
            assert(isequal(logentry, e_logentry));

            sample_data.variables{end}.data(:, :) = 0.;
            sample_data.variables{end - 1}.data(:, :) = 31.;
            v2 = v + 2;
            [pdata, ~, logentry] = imosTiltVelocitySetQC(sample_data, true);
            assert(isequal(pdata.variables{1}.flags, v2))
            assert(isequal(logentry, e_logentry));

            sample_data.variables{end}.data(:, :) = 0.;
            sample_data.variables{end - 1}.data(:, :) = 0.;
            v1 = v + 1;
            [pdata, ~, logentry] = imosTiltVelocitySetQC(sample_data, true);
            assert(isequal(pdata.variables{1}.flags, v1))
            assert(isequal(logentry, e_logentry));
        end

        function test_load_nortek_adcp(~)
            ssize = [100, 6];
            sample_data = create_sample_data(ssize);
            sample_data.variables{end}.data = zeros(100,1); %roll
            sample_data.variables{end - 1}.data = zeros(100,1)+90.; %pitch
            sample_data.variables{end - 1}.data([1,99]) = 0;
            sample_data.variables{end - 1}.data([2,98]) = 21;
            sample_data.instrument = 'nortek';
            e_logentry = 'firstTiltThreshold=20, secondTiltThreshold=30';
            v = sample_data.variables{1}.data * 0;

            v3 = v + 3;
            v3([1,99],:) = 1;
            v3([2,98],:) = 2;
            [pdata, ~, logentry] = imosTiltVelocitySetQC(sample_data, true);
            assert(isequal(pdata.variables{1}.flags, v3))
            assert(isequal(e_logentry, logentry))

            sample_data.variables{end}.data(:, :) = 0.;
            sample_data.variables{end - 1}.data(:, :) = 25.;
            v2 = v + 2;
            [pdata, ~, logentry] = imosTiltVelocitySetQC(sample_data, true);
            assert(isequal(pdata.variables{1}.flags, v2))
            assert(isequal(e_logentry, logentry))

            sample_data.variables{end}.data(:, :) = 0.;
            sample_data.variables{end - 1}.data(:, :) = 0.;
            v1 = v + 1;
            [pdata, ~, logentry] = imosTiltVelocitySetQC(sample_data, true);
            assert(isequal(pdata.variables{1}.flags, v1))
            assert(isequal(e_logentry, logentry))
        end

        function test_load_sentinel(~)
            ssize = [100, 33];
            sample_data = create_sample_data(ssize);
            sample_data.variables{end}.data = zeros(100,1); %roll
            sample_data.variables{end - 1}.data = zeros(100,1)+90.; %pitch
            sample_data.instrument = 'ADCP sentinel abcdefg';
            e_logentry = 'firstTiltThreshold=15, secondTiltThreshold=22';
            v = sample_data.variables{1}.data(:, :) * 0;

            v3 = v + 3;
            [pdata, ~, logentry] = imosTiltVelocitySetQC(sample_data, true);
            assert(isequal(pdata.variables{1}.flags, v3))
            assert(isequal(e_logentry, logentry))

            sample_data.variables{end}.data(:, :) = 0.;
            sample_data.variables{end - 1}.data(:, :) = 21.;
            v2 = v + 2;
            [pdata, ~, logentry] = imosTiltVelocitySetQC(sample_data, true);
            assert(isequal(pdata.variables{1}.flags, v2))
            assert(isequal(e_logentry, logentry))

            sample_data.variables{end}.data(:, :) = 0.;
            sample_data.variables{end - 1}.data(:, :) = 0.;
            v1 = v + 1;
            [pdata, ~, logentry] = imosTiltVelocitySetQC(sample_data, true);
            assert(isequal(pdata.variables{1}.flags, v1))
            assert(isequal(e_logentry, logentry))
        end

        function test_below_secondThreshold_ui(testCase)
            if testCase.testUI
                ssize = [100, 33];
                sample_data = create_sample_data(ssize);
                sample_data.variables{end}.data = zeros(100,1); %roll
                sample_data.variables{end - 1}.data = zeros(100,1) +90; %pitch
                sample_data.instrument = 'ADCP sentinel abcdefg';
                e_logentry = 'firstTiltThreshold=15, secondTiltThreshold=91';
                disp('Set firstFlagThreshold to be 4 and SecondTiltThreshold to be 91 for this test to pass');
                v = zeros(ssize)+4;
                [pdata, ~, logentry] = imosTiltVelocitySetQC(sample_data, false);
                assert(isequal(pdata.variables{1}.flags, v))
                assert(isequal(e_logentry, logentry))
            else
                disp("testUI is False...skipping UI testing")
            end

        end

        function test_above_secondThreshold_ui(testCase)
            if testCase.testUI
                ssize = [100, 33];
                sample_data = create_sample_data(ssize);
                sample_data.variables{end}.data = zeros(100,1); %roll
                sample_data.variables{end - 1}.data = zeros(100,1)+81.; %pitch
                sample_data.instrument = 'ADCP sentinel abcdefg';
                e_logentry = 'firstTiltThreshold=15, secondTiltThreshold=80';
                disp('Set SecondTiltThreshold to be 80 for this test to pass');
                v = zeros(ssize)+3;
                [pdata, ~, logentry] = imosTiltVelocitySetQC(sample_data, false);
                assert(isequal(pdata.variables{1}.flags, v))
                assert(isequal(e_logentry, logentry))
            else
                disp("testUI is False...skipping UI testing")
            end
        end

    end

end

function sample_data = create_sample_data(asize)
sample_data = struct();
sample_data.variables = cell(1, 1);
dummy = randn(asize);
names = {'UCUR', 'VCUR', 'WCUR', 'CSPD', 'CDIR', 'PITCH', 'ROLL'};

for k = 1:length(names)
    sample_data.variables{k} = struct();
    sample_data.variables{k}.name = names{k};
    sample_data.variables{k}.data = dummy;
    sample_data.variables{k}.flags = zeros(asize);
end

end
