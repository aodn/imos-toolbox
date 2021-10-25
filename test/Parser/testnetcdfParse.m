classdef testnetcdfParse < matlab.unittest.TestCase

    properties (TestParameter)
        anmn_file = files2namestruct(only_netcdf(rdir([toolboxRootPath 'data/testfiles/aodn/ANMN'])))
        dwm_file = files2namestruct(only_netcdf(rdir([toolboxRootPath 'data/testfiles/aodn/DWM'])))
        meta_fields = {'level', 'file_name', 'site_id', 'survey', 'station', 'instrument_make', 'insturment_model', 'instrument_serial_no', 'instrument_sample_interval', 'instrument_burst_duration', 'instrument_burst_interval', 'featureType'}
    end

    methods (Test)

        function test_no_error_reading_anmn(~, anmn_file)
            data = netcdfParse({anmn_file}, '');
            assert_metadata(data);
            assert_instrument_sample_interval(data);
            assert_burst_sampling(data);
        end

        function test_no_error_reading_dwm(~, dwm_file)
            data = netcdfParse({dwm_file}, '');
            assert_metadata(data);
            assert_instrument_sample_interval(data);
            assert_burst_sampling(data);
        end

    end

end

function ycell = only_netcdf(xcell)
ycell = cell(1,1000);
c = 0;
for k = 1:length(xcell)
    item = xcell{k};

    if strcmpi(item(end - 2:end), '.nc')
        c = c + 1;
        ycell{c} = item;
    end

end
ycell=ycell(1:c);
end

function assert_metadata(data)
got_site_id = isfield(data,'meta') && isfield(data.meta,'site_id');
assert(got_site_id);
assert_site_id = ~isempty(data.meta.site_id);
assert(assert_site_id);

got_time_coverage = isfield(data,'time_coverage_start') && isfield(data,'time_coverage_end');
assert(got_time_coverage);
assert_time_coverage = ~isempty(data.time_coverage_start) && ~isempty(data.time_coverage_end);
assert(assert_time_coverage);
end

function assert_instrument_sample_interval(data)
if isfield(data,'instrument_sample_interval')
    if ~isempty(data.instrument_sample_interval) && isfield(data,'meta') && isfield(data.meta,'instrument_sample_interval')
        assert(data.instrument_sample_interval == data.meta.instrument_sample_interval)
    end
else
    warning('%s missing instrument_sample_interval',data.toolbox_input_file)
end

end

function assert_burst_sampling(data)
is_burst = isfield(data,'instrument_burst_interval') || isfield(data,'instrument_burst_duration');
if is_burst
    has_burst_interval_but_not_duration = isfield(data,'instrument_burst_interval') && ~isfield(data,'instrument_burst_duration');
    has_burst_duration_but_not_interval = isfield(data,'instrument_burst_duration') && ~isfield(data,'instrument_burst_interval');
    if has_burst_interval_but_not_duration || has_burst_duration_but_not_interval
        warning('%s contains incomplete burst information',data.toolbox_input_file)
    else
        assert_burst_interval = (~isnan(data.instrument_burst_interval)) || (data.instrument_burst_interval > 0);
        assert_burst_duration = (~isnan(data.instrument_burst_duration)) || (data.instrument_burst_duration > 0);
        assert(assert_burst_interval && assert_burst_duration)
        if isfield(data,'meta')
            assert_burst_sampling(data.meta)
        end
    end
end
end
