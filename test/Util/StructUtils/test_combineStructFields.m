classdef test_combineStructFields < matlab.unittest.TestCase

    methods (Test)

        function test_basic(~)
			a = struct(); b=a;
			a.x = 1;
			b.x = 2;
			b.y = 3;
			combined = combineStructFields(a,b);
			assert(combined.x==2);
			assert(combined.y==3);
        end

        function test_multi_structure_case(~)
			% multi structure case
			a = struct(); b=a; c=a;
			a.x = 1;
			b.x = 2;
			b(2).x = 3;
			b(3).x = 4;
			c.x = 3;
			c(2).x = 4;
			c(3).x = 5;
			combined = combineStructFields(a,b,c);
			assert(isequal(size(combined),[1,3]))
			assert(combined(1).x==3)
			assert(combined(2).x==4)
			assert(combined(3).x==5)
        end

    end

end
