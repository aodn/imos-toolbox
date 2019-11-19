classdef testPopFromCell < matlab.unittest.TestCase

    methods (Test)

        function test_all_cell_argument(~)
            [newcell] = popFromCell({1, 2, 3}, {2, 3});
            assert(isequal(newcell, {1}))
        end

        function test_string_argument(~)
            [newcell] = popFromCell({'a', 'b'}, 'b');
            assert(isequal(newcell, {'a'}))
        end

        function test_empty_argument(~)

            try
                popFromCell({'a'}, '');
            catch
                assert(true)
                return
            end

            error("Did not raise error")
        end

    end

end
