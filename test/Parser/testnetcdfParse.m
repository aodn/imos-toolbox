classdef testnetcdfParse < matlab.unittest.TestCase

    properties (TestParameter)
        anmn_file = files2namestruct(only_netcdf(rdir([toolboxRootPath 'data/testfiles/aodn/ANMN'])))
        abos_file = files2namestruct(only_netcdf(rdir([toolboxRootPath 'data/testfiles/aodn/ABOS'])))
        meta_fields = {'level', 'file_name', 'site_id', 'survey', 'station', 'instrument_make', 'insturment_model', 'instrument_serial_no', 'instrument_sample_interval', 'instrument_burst_duration', 'instrument_burst_interval', 'featureType'}
    end

    methods (Test)

        function test_no_error_reading_anmn(testCase, anmn_file)
            data = netcdfParse({anmn_file}, '');
            assert(~isempty(data.meta.site_id))
            assert(~isempty(data.time_coverage_start))
            assert(~isempty(data.time_coverage_end))
            assert(isnan(data.meta.instrument_sample_interval) || data.meta.instrument_sample_interval > 0)
            assert((isnan(data.meta.instrument_burst_interval) || data.meta.instrument_burst_interval > 0) && (isnan(data.meta.instrument_burst_duration) || data.meta.instrument_burst_duration > 0))
        end

        function test_no_error_reading_abos(~, abos_file)
            data = netcdfParse({abos_file}, '');
            assert(~isempty(data.meta.site_id))
            assert(~isempty(data.time_coverage_start))
            assert(~isempty(data.time_coverage_end))
            assert(isnan(data.meta.instrument_sample_interval) || data.meta.instrument_sample_interval > 0)
            assert((isnan(data.meta.instrument_burst_interval) || data.meta.instrument_burst_interval > 0) && (isnan(data.meta.instrument_burst_duration) || data.meta.instrument_burst_duration > 0))
        end

    end

end

function ycell = only_netcdf(xcell)
ycell = {};
c = 0;

for k = 1:length(xcell)
    item = xcell{k};

    if strcmpi(item(end - 2:end), '.nc')
        c = c + 1;
        ycell{c} = item;
    end

end

end
