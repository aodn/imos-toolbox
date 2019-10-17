classdef testtimeSamplingInfo < matlab.unittest.TestCase

    methods (Test)

        function test_simple_monotonic(testCase),
            info = timeSamplingInfo([1, 2, 3, 4]);
            assert(info.uniform_sampling);
            assert(all([info.unique_sampling, info.monotonic_sampling, info.progressive_sampling]));
        end

        function test_decreasing_with_jump_at_end(testCase),
            info = timeSamplingInfo([4, 3, 2, 1, -1]);
            assert(~info.uniform_sampling);
            assert(all(info.sampling_steps == [-2, -1]));
            assert(all(info.sampling_steps_median == -1));
            assert(info.regressive_sampling);
            assert(all([info.unique_sampling, info.monotonic_sampling]));
        end

        function test_increasing_with_jump_at_end(testCase),
            info = timeSamplingInfo([1, 2, 3, 5]);
            assert(info.non_uniform_sampling_indexes == 3);
        end

        function test_increasing_with_repeat(testCase),
            info = timeSamplingInfo([1, 2, 3, 3]);
            assert(~info.uniform_sampling);
            assert(~all([info.unique_sampling, info.monotonic_sampling]));
            assert(info.non_uniform_sampling_indexes == [3]);
        end

        function test_jump_forward_backward(testCase),
            info = timeSamplingInfo([1, 2, 1, 3, 1, 4, 1, 5, 1]);
            assert(~all([info.unique_sampling, info.progressive_sampling, info.regressive_sampling, info.monotonic_sampling]));
            assert(isequal(info.sampling_steps_median, []));
            assert(all(info.jump_forward_indexes == [1 0 1 0 1 0 1 0]));
            assert(all(info.jump_backward_indexes == [0 1 0 1 0 1 0 1]));
        end

    end

end
