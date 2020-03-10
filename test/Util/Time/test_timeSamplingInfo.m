classdef test_timeSamplingInfo < matlab.unittest.TestCase

    methods (Test)

        function test_basic(~)
            info = timeSamplingInfo([1, 2, 3, 4, 5.3], 'day');
            assert(info.uniform_sampling);
            assert(all([info.unique_sampling, info.monotonic_sampling, info.progressive_sampling]));
        end

        function test_extra_fields(~)
            info = timeSamplingInfo([1, 2, 1, 3, 1, 4, 1, 5, 1], 'day');
            assert(~all([info.unique_sampling, info.progressive_sampling, info.regressive_sampling, info.monotonic_sampling]));
            assert(isequal(info.sampling_steps_median, []));
            assert(all(info.jump_forward_indexes == [1 0 1 0 1 0 1 0]));
            assert(all(info.jump_backward_indexes == [0 1 0 1 0 1 0 1]));
        end

        function test_ignore_microsecond(~)
            info = timeSamplingInfo([1, 2, 3, 4 + 0.49/86400, 5], 'second');
            assert(info.repeated_samples == 0);
            assert(info.sampling_steps == 1);
        end

        function test_detect_sampling_above_scale(~)
            info = timeSamplingInfo([1, 2, 3, 4 + 0.5/86400, 5], 'second');
            assert(info.repeated_samples == 0);
            assert(isequal(info.sampling_steps * 86400, [86400, 86401]));
        end

        function test_ignore_sequential_offsets_below_scale(~)
            drifts = [0, 0, 0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1] / 86400;
            times = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13];
            info = timeSamplingInfo(times + drifts, 'second');
            assert(info.sampling_steps_in_seconds == 86400);
        end

        function test_detect_offset_above_scale(~)
            drifts = [0, 0, 0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.9] / 86400;
            times = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13];
            info = timeSamplingInfo(times + drifts, 'second');
            assert(length(info.sampling_steps) == 2);
            assert(isequal(info.sampling_steps_in_seconds, [86400, 86401]));
        end

        function test_several_sampling_drifts(~)
            drifts = [0, 0.5, 0.5, 0.5, 0.75, 1, 1.25, 1.5, 3, 6, 9, 12, 24] / 86400;
            times = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13];
            info = timeSamplingInfo(times + drifts, 'second');
            assert(isequal(info.sampling_steps_in_seconds, 86400 + [0, 1, 2, 3, 12]));
        end

    end

end
