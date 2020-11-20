classdef test_imosTimeSeriesSpikeQC < matlab.unittest.TestCase

    properties (TestParameter)
        burst_file = {[toolboxRootPath() 'data/testfiles/Nortek/signature_500/v000/S100165A008_TR44Jun6.ad2cp']};
        non_burst_file = {[toolboxRootPath() 'data/testfiles/Sea_Bird_Scientific/SBE/19plus/v000/chla_aquaT3_as_aquaUV.cnv']};
        burst_file_nc = {[toolboxRootPath() 'data/testfiles/netcdf/test/UI/IMOS_ANMN-QLD_CKOSTUZ_20150523T085944Z_DARBGF_FV01_DARBGF-SURF-1505-WQM-1_END-20150714T221531Z_C-20171026T040809Z.nc']};
        non_burst_file_nc = {[toolboxRootPath() 'data/testfiles/netcdf/test/UI/IMOS_ANMN-QLD_CFKSTUZ_20150805T103003Z_DARBGF_FV01_DARBGF-1508-SBE16plus-29.3_END-20160207T225112Z_C-20171023T055701Z.nc']};
    end


    methods (Test)
        function test_no_ndvars_processed(~)
            sample_data = create_sample_data([100,1],{'2dvar','3dvar','TEMP','PITCH','ROLL'});
            z = imosTimeSeriesSpikeQC(sample_data,true);
            procvars = fieldnames(z);
            assert(~inCell(procvars,'2dvar'));
            assert(~inCell(procvars,'3dvar'));
        end

        function test_non_burst(~)
            sample_data = create_sample_data([100,1],{'2dvar','3dvar','TEMP','PITCH','ROLL'});
            sample_data.instrument_burst_duration = '';
            sample_data.instrument_burst_interval = '';
            imosTimeSeriesSpikeQC(sample_data,true);
        end

        function test_burst(~)
            sample_data = create_sample_data([44,1],{'2dvar','3dvar','TEMP','PITCH','ROLL'});
            btime = (1:11)'+[1,3600,3600*2,3600*3];
            btime = btime(:);
            sample_data.dimensions{1}.data = btime;
            sample_data.instrument_burst_duration = 10;
            sample_data.instrument_burst_interval = 3600;
            imosTimeSeriesSpikeQC(sample_data,true);
        end

        function test_use_meta_info(testCase)
            sample_data = create_sample_data([44,1],{'2dvar','3dvar','TEMP','PITCH','ROLL'});
            btime = (1:11)'+[1,3600,3600*2,3600*3];
            btime = btime(:);
            sample_data.dimensions{1}.data = btime;
            sample_data.meta = struct();
            sample_data.meta.instrument_burst_duration = 10;
            sample_data.meta.instrument_burst_interval = 3600;
            z = imosTimeSeriesSpikeQC(sample_data,true);
            assert(~isempty(z));
            sample_data.meta.instrument_burst_duration = NaN;
            sample_data.meta.instrument_burst_interval = 3600;
            func = @() imosTimeSeriesSpikeQC(sample_data,true);
            assert(isempty(fieldnames(func())));
            last_warning_msg = lastwarn;
            assert(isequal(last_warning_msg,'Invalid burst metadata...skipping'));
        end

        function test_use_metadata_at_meta_level(~)
            sample_data = create_sample_data([44,1],{'2dvar','3dvar','TEMP','PITCH','ROLL'});
            btime = (1:11)'+[1,3600,3600*2,3600*3];
            btime = btime(:);
            sample_data.dimensions{1}.data = btime;
            sample_data.instrument_burst_duration = '';
            sample_data.instrument_burst_interval = '';
            sample_data.meta = struct();
            sample_data.meta.instrument_burst_duration = 3600;
            sample_data.meta.instrument_burst_interval = 10;
            imosTimeSeriesSpikeQC(sample_data,true);
        end

        function real_nonburst_file(~,non_burst_file)
            sample_data = SBE19Parse({non_burst_file},'timeSeries');
            for k=1:length(sample_data.variables)
                sample_data.variables{k}.flags = sample_data.variables{k}.data*0;
            end
            imosTimeSeriesSpikeQC(sample_data,true);
        end

        function real_burst_file(~,burst_file)
            sample_data = signatureParse({burst_file},'timeSeries');
            sample_data = sample_data{1};
            for k=1:length(sample_data.variables)
                sample_data.variables{k}.flags = sample_data.variables{k}.data*0;
            end
            imosTimeSeriesSpikeQC(sample_data,true);
        end

        function real_nonburst_file_netcdf(~,non_burst_file_nc)
            sample_data = netcdfParse({non_burst_file_nc},'timeSeries');
            z = imosTimeSeriesSpikeQC(sample_data,true);
            assert(~isempty(z));
        end

        function real_burst_file_netcdf(~,non_burst_file_nc)
            sample_data = netcdfParse({non_burst_file_nc},'timeSeries');
            z = imosTimeSeriesSpikeQC(sample_data,true);
            assert(~isempty(z));
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
sample_data.variables{1}.data = repmat(dummy,1,6);
sample_data.variables{1}.dimensions = 2;
sample_data.variables{2}.data = repmat(dummy,1,6,12);
sample_data.variables{2}.dimensions = 3;

end
