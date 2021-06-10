classdef testDepthPP < matlab.unittest.TestCase

    % Test DepthPP
    %
    % by hugo.oliveira@utas.edu.au
    %
    properties (TestParameter)
        mode = {'profile','timeSeries'};
        interactive = {ismember('interactive_tests',who('global'))};
    end

    methods (Test)
        function testDepthPPOverwriteDepth(testCase, mode, interactive)
            testCase.assumeTrue(interactive,'Interactive test skipped')
            d = IMOS.gen_dimensions(mode,1,{'TIME'},{@double},{randn(100,1)});
            parr = 100*ones(100,1);
            darr = randn(100,1);
            v = IMOS.gen_variables(d,{'X','PRES','DEPTH'},{@double,@double,@double},{randn(1,1),parr,darr},'coordinates','');
            dataset = struct();
            dataset.dimensions = d;
            dataset.variables = v;
            dataset.instrument_nominal_depth = 200;
            dataset.site_nominal_depth = 205;
            dataset.toolbox_input_file = '';
            dataset.meta = struct();
            dataset = makeNetCDFCompliant(dataset);
            disp('Select from PRES measurements to overwrite DEPTH and make this test pass')
            x = depthPP({dataset},'qc',false); %select from PRES to overwrite DEPTH
            assert(~isequal(x{1}.variables{end}.data,darr));
        end
    end

end
