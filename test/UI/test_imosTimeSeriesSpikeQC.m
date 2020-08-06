classdef test_imosTimeSeriesSpikeQC < matlab.unittest.TestCase

    methods (Test)
        function test_no_ndvars_processed(~)
            sample_data = create_sample_data([100,1],{'2dvar','3dvar','TEMP','PITCH','ROLL'});
            dummy = sample_data.variables{1}.data;
            sample_data.variables{1}.data = repmat(dummy,1,6);
            sample_data.variables{1}.dimensions = 2;
            sample_data.variables{2}.data = repmat(dummy,1,6,12);
            sample_data.variables{2}.dimensions = 3;
            z = imosTimeSeriesSpikeQC(sample_data,true);
            procvars = fieldnames(z);
            assert(~inCell(procvars,'2dvar'));
            assert(~inCell(procvars,'3dvar'));
        end

    end
end

function sample_data = create_sample_data(asize,varnames)
sample_data = struct();
sample_data.variables = cell(1, 1);
sample_data.dimensions = cell(1, 1);
dummy = randn(asize);

for k = 1:length(varnames)
    sample_data.variables{k} = struct();
    sample_data.variables{k}.name = varnames{k};
    sample_data.variables{k}.data = dummy;
    sample_data.variables{k}.flags = zeros(asize);
    sample_data.variables{k}.dimensions = 1;
end
sample_data.dimensions{1} = struct('name','TIME','data',linspace(0,length(dummy),1),'flags',zeros(asize));
end
