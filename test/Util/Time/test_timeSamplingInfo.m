classdef test_timeSamplingInfo < matlab.unittest.TestCase

    methods (Test)

        function test_basic(~)
            info = timeSamplingInfo([1, 2, 3, 4, 5.3], 'day');
            assert(info.uniform_sampling)
            assert(all([info.unique_sampling, info.monotonic_sampling, info.progressive_sampling]))
        end

        function test_symmetric_cases(~)
            time = [1, 2, 1, 3, 1, 4, 1, 5, 1];
            info = timeSamplingInfo(time, 'day');
            assert(~all([info.unique_sampling, info.progressive_sampling, info.regressive_sampling, info.monotonic_sampling]))
            assert(info.sampling_steps_median==0) % symmetric values
            assert(info.sampling_steps_mode==-4) %sorted first occurrence
            assert(all(info.jump_magnitude == [1, -1, 2, -2, 3, -3, 4, -4]))
            assert(all(info.jump_forward_indexes == [1 0 1 0 1 0 1 0]))
            assert(all(info.jump_backward_indexes == [0 1 0 1 0 1 0 1]))

        end

        function test_perfect_sampling(~)
            time = 1:10;
            info = timeSamplingInfo(time, 'day');
            assert(all([info.consistent_sampling, info.unique_sampling, info.uniform_sampling, info.monotonic_sampling, info.progressive_sampling]))
            assert(isequal(info.number_of_sampling_steps,1))
            assert(isequal(info.sampling_steps, 1))
            assert(isequal(info.sampling_steps_median, 1))
            assert(isequal(info.sampling_steps_mode, 1))
        end

        function test_detect_time_jumps(~)
            time = [1:10,60:80,130:140];
            info = timeSamplingInfo(time,'day');
            assert(all([info.consistent_sampling,info.unique_sampling,info.monotonic_sampling, info.progressive_sampling]))
            assert(isequal(info.jump_magnitude,[50,50]))
        end

        function test_null_case(~)
            time = repmat(0,10,1);
            info = timeSamplingInfo(time,'day');
            assert(info.number_of_sampling_steps==1);
            assert(info.sampling_steps_median==0);
            assert(info.sampling_steps_mode==0);
            assert(all([info.consistent_sampling,info.constant_vector,info.repeated_samples,info.uniform_sampling]))
            assert(isempty(info.jump_magnitude))
            assert(isempty(info.jump_forward_indexes))
        end

        function test_repeated_time_entries(~)
            time = [1:10,60,60,60,60,60,65:80,130:140];
            info = timeSamplingInfo(time,'day');
            assert(isequal(info.sampling_steps,[0,1,5,50]))
            assert(info.sampling_steps_mode==1)
            assert(all([info.consistent_sampling,info.repeated_samples,info.progressive_sampling]))
            assert(isequal(info.jump_magnitude,[50, 0, 0, 0, 0, 5, 50]))
            assert(isequal(info.jump_forward_indexes,[1, 0, 0, 0, 0, 1, 1]))
        end

        function test_ignore_microsecond(~)
            info = timeSamplingInfo([1, 2, 3, 4 + 0.49/86400, 5], 'second');
            assert(info.repeated_samples == 0)
            assert(info.sampling_steps == 1)
        end

        function test_detect_sampling_above_scale(~)
            info = timeSamplingInfo([1, 2, 3, 4 + 0.5/86400, 5], 'second');
            assert(info.repeated_samples == 0)
            assert(isequal(info.sampling_steps * 86400, [86400, 86401]))
        end

        function test_ignore_sequential_offsets_below_scale(~)
            drifts = [0, 0, 0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1] / 86400;
            times = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13];
            info = timeSamplingInfo(times + drifts, 'second');
            assert(info.sampling_steps_in_seconds == 86400)
        end

        function test_detect_offset_above_scale(~)
            drifts = [0, 0, 0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.9] / 86400;
            times = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13];
            info = timeSamplingInfo(times + drifts, 'second');
            assert(length(info.sampling_steps) == 2)
            assert(isequal(info.sampling_steps_in_seconds, [86400, 86401]))
        end

        function test_several_sampling_drifts(~)
            drifts = [0, 0.5, 0.5, 0.5, 0.75, 1, 1.25, 1.5, 3, 6, 9, 12, 24] / 86400;
            times = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13];
            info = timeSamplingInfo(times + drifts, 'second');
            assert(isequal(info.sampling_steps_in_seconds, 86400 + [0, 1, 2, 3, 12]))
        end

    end

end
