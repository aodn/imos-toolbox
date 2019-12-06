classdef test_inCellPartialMatch < matlab.unittest.TestCase

    properties (TestParameter)
        tinput = {{sprintf('a\tb\tc'), 'b', 'c'}};
    end

    methods (Test)

        function test_match_first_index(~, tinput)
            [is_complete, indexes] = inCellPartialMatch(tinput, {'a b'});
            assert(is_complete)
            assert(isequal(indexes, 1))
        end

        function test_partial_match(~, tinput)
            [is_complete, indexes] = inCellPartialMatch(tinput, {'a c'});
            assert(is_complete)
            assert(isequal(indexes, 1))
        end

        function test_partial_match_reduced(~, tinput)
            [is_complete, indexes] = inCellPartialMatch(tinput, {'a c', 'c'});
            assert(is_complete)
            assert(isequal(indexes, [1; 1]))
        end

        function test_partial_match_complete(~, tinput)
            [is_complete, indexes] = inCellPartialMatch(tinput, {'a c', 'c'}, true);
            assert(is_complete)
            assert(iscell(indexes))
            assert(isequal(indexes{1}, {1}))
            assert(isequal(indexes{2}, {1, 3}))
        end

    end

end
