classdef testSchema < matlab.unittest.TestCase

    properties (TestParameter)
        basic_type = load_basic_types();
        nested_type = load_nested_types();
        nested_tree_type = load_nested_tree_types();
        treediff_case = load_treediff_cases();
        validate_type_case = load_validatetype_cases();
        validate_content_case = load_validatecontent_cases();
    end

    methods (Test)

        function test_detectType_basic(testCase, basic_type),
            i = basic_type{1};
            e = basic_type{2};
            [itype, is_nested, nested_keys] = detectType(i);
            res = isequal(e, {itype, is_nested, nested_keys});
            assert(res);
        end

        function test_detectType_nested(testCase, nested_type),
            i = nested_type{1};
            e = nested_type{2};
            [itype, is_nested, nested_keys] = detectType(i);
            res = isequal(e, {itype, is_nested, nested_keys});
            assert(res);
        end

        function test_createTree_basic(testCase, basic_type),
            i = basic_type{1};
            e = basic_type{2}{1};
            [tree] = createTree(i);
            res = isequal(e, tree);
            assert(res);
        end

        function test_createTree_nested(testCase, nested_tree_type),
            i = nested_tree_type{1};
            e = nested_tree_type{2};
            [tree] = createTree(i);
            res = isequal(e, tree);
            assert(res);
        end

        function test_treeDiff_equal(testCase, nested_tree_type),
            i = nested_tree_type{1};
            [isdiff, msg] = treeDiff(i, i, false);
            assert(isequal(msg, ''));
            assert(~isdiff);
        end

        function test_treeDiff_notequal(testCase, treediff_case),
            i = treediff_case{1};
            e = treediff_case{2};
            [isdiff, msg] = treeDiff(i, e, false);
            non_empty_msg = ~strcmpi(msg, '');
            assert(isdiff);
            assert(non_empty_msg);
        end

        function test_validate_type(testCase, validate_type_case),
            i = validate_type_case{1};
            e = validate_type_case{2};
            [equal, msg] = validateType(i, e);
            non_empty_msg = ~strcmpi(msg, '');
            assert(~equal)
            assert(non_empty_msg)
        end

        function test_validate_content(testCase, validate_content_case),
            i = validate_content_case{1};
            e = validate_content_case{2};
            emsg = validate_content_case{3};
            [equal, msg] = validate(i, e, false);
            non_empty_msg = ~strcmpi(msg, '');
            foundmsg = length(findstr(emsg, msg)) > 0;
            assert(~equal);
            assert(non_empty_msg);
            assert(foundmsg);
        end

    end

end

function [ps] = load_basic_types();
    % load testcases for basic types
    %
    % ps here is a structure with several basic tests
    % every fieldname is a parametrized case.
    % every fieldname is a 2x1 cell with [i]nputs and [e]xpected results.
    % inputs are cells
    % expected results are also cells, usually cells of cells if the expected output of a test function is more than one.
    %

    ea = logical(zeros(0));

    i = {cell(0, 0), cell(1, 1), cell(1, 2), cell(2, 1), cell(2, 2)};

    e = {{cell(0, 0), false, ea}, {{@isdouble}, false, false}, {{@isdouble, @isdouble}, false, logical(zeros([1, 2]))}, {transpose({@isdouble, @isdouble}), false, logical(zeros([2, 1]))}, {reshape({@isdouble, @isdouble, @isdouble, @isdouble}, 2, 2), false, logical(zeros([2, 2]))}};

    i = joinCell(i, {struct()});
    e = joinCell(e, {{struct(), false, ea}});

    i = joinCell(i, {NaN, -inf, +inf});
    e = joinCell(e, {{@isnan, false, ea}, {@isinf, false, ea}, {@isinf, false, ea}});

    i = joinCell(i, {'', 'a', 'abc'});
    e = joinCell(e, {{@ischar, false, ea}, {@ischar, false, ea}, {@ischar, false, ea}});

    i = joinCell(i, {logical(false), logical(1)});
    e = joinCell(e, {{@islogical, false, ea}, {@islogical, false, ea}});

    i = joinCell(i, {@sin, @(x) sin(x)});
    e = joinCell(e, {{@isfunctionhandle, false, ea}, {@isfunctionhandle, false, ea}});

    i = joinCell(i, {single(1), double(2)});
    e = joinCell(e, {{@issingle, false, ea}, {@isdouble, false, ea}});

    i = joinCell(i, {[1, 2, 3], [1, 2, NaN], [1, 2, -inf], [1, 2, inf]});
    e = joinCell(e, {{@isdouble, false, ea}, {@isdouble, false, ea}, {@isdouble, false, ea}, {@isdouble, false, ea}});

    ii = {int8(8), uint8(8), int16(16), uint16(16), int32(32), uint32(32), int64(64), uint64(64)};
    ee = {{@isint8, false, ea}, {@isuint8, false, ea}, {@isint16, false, ea}, {@isuint16, false, ea}, {@isint32, false, ea}, {@isuint32, false, ea}, {@isint64, false, ea}, {@isuint64, false, ea}};

    i = joinCell(i, ii);
    e = joinCell(e, ee);
    ps = struct();

    for k = 1:length(i),

        if iscell(e{k}{1})
            name = ['cell_' num2str(k)];
        elseif isstruct(e{k}{1})
            name = ['struct_' num2str(k)];
        else
            name = [func2str(e{k}{1}) '_' num2str(k)];
        end

        ps.(name) = {i{k}, e{k}};
    end

end

function [ps1, non_nested_entries, z1] = load_nested_types(),
    % load testcases for nested types
    %
    % ps1 is a structure with one case - a deeply nested structure.
    % non_nested_entries is the number of simple fieldnames at root level of the case in ps1.
    % z1 is the same structure as in ps1.(name), but without a deeply nested structures.
    %
    s1 = struct();
    s1.int8 = int8(1);
    s1.int16 = int16(1);
    s1.int32 = int32(1);
    s1.int64 = int64(1);
    s1.logical = logical(1);
    s1.single = single(1);
    s1.double = double(1);
    s1.nan = NaN;
    s1.pinf = +inf;
    s1.ninf = -inf;
    s1.doublearray = [1, 2, 3, NaN, +inf, -inf];
    non_nested_entries = length(fieldnames(s1));
    s1.cell00 = cell(0, 0);
    s1.cell10 = cell(1, 0);
    s1.cell11 = cell(1, 1);
    s1.cell21 = cell(2, 1);
    s1.cell22 = cell(2, 2);
    s1.cellofstructs = cell(1, 1);
    s1.cellofstructs{1} = s1;
    z1 = s1; % stop too deep nesting for parametrizing
    s1.cellincell = cell(1, 1);
    s1.cellincell{1} = z1;
    s1.struct = z1;
    s1.structofcellsofstructs = struct();
    s1.structofcellsofstructs.item = z1.cellofstructs;
    s1.structarray(3, 2) = struct();

    i = s1;

    nentries = length(fieldnames(s1));
    nnested = logical(ones(1, nentries));
    nnested(1:non_nested_entries) = false;
    e1 = struct();
    e1.int8 = @isint8;
    e1.int16 = @isint16;
    e1.int32 = @isint32;
    e1.int64 = @isint64;
    e1.logical = @islogical;
    e1.single = @issingle;
    e1.double = @isdouble;
    e1.nan = @isnan;
    e1.pinf = @isinf;
    e1.ninf = @isinf;
    e1.doublearray = @isdouble;
    e1.cell00 = @iscell;
    e1.cell10 = @iscell;
    e1.cell11 = @iscell;
    e1.cell21 = @iscell;
    e1.cell22 = @iscell;
    e1.cellofstructs = @iscell;
    e1.cellincell = @iscell;
    e1.struct = @isstruct;
    e1.structofcellsofstructs = @isstruct;
    e1.structarray = @isstruct;

    e = {e1, true, nnested};
    ps1.nested = {i, e};
end

function [ps] = load_nested_tree_types(),
    % load testcases for tree functions with nested types
    %
    % ps is a structure with one case - a deeply nested structure
    % it's different from load_nested_types
    % since we are now comparing the output of a the entire
    % variable instead of just at the root level
    %

    ps = struct();
    [pp, non_nested_entries, z1] = load_nested_types();
    s1 = pp.nested{1};
    nentries = length(fieldnames(s1));
    nnested = logical(ones(1, nentries));
    nnested(1:non_nested_entries) = false;

    e2.int8 = @isint8;
    e2.int16 = @isint16;
    e2.int32 = @isint32;
    e2.int64 = @isint64;
    e2.logical = @islogical;
    e2.single = @issingle;
    e2.double = @isdouble;
    e2.nan = @isnan;
    e2.pinf = @isinf;
    e2.ninf = @isinf;
    e2.doublearray = @isdouble;
    e2.cell00 = {};
    e2.cell10 = {};
    e2.cell11 = {@isdouble};
    e2.cell21 = transpose({@isdouble @isdouble});
    e2.cell22 = reshape({@isdouble @isdouble @isdouble @isdouble}, 2, 2);
    e2.cellofstructs = cell(1, 1);
    e2.cellofstructs{1} = e2;
    e2.cellofstructs{1}.cellofstructs = cell(1, 1);
    e2.cellofstructs{1}.cellofstructs{1} = @isdouble; %match above def
    z2 = e2; % stop too deep nesting structure
    e2.cellincell = cell(1, 1);
    e2.cellincell{1} = e2.cellofstructs{1};
    e2.cellincell{1}.cellofstructs = cell(1, 1);
    e2.cellincell = cell(1, 1);
    e2.cellincell{1} = z2;
    e2.struct = z2;
    e2.structofcellsofstructs = struct();
    e2.structofcellsofstructs.item = z2.cellofstructs;
    e2.structarray = struct();

    ps.nested_tree = {s1, e2};
end

function [ps] = load_treediff_cases(),
    % load testcases for different tree nested types cases
    %
    % ps is a structure with several fieldnames,
    % each one holds deeply nested trees that are slightly different
    % and seeks to cause inequality in simple and complex cases.
    %

    ps = struct();

    base = load_nested_tree_types();
    p = base.nested_tree{1};

    i = p;
    e = p;

    i.item = single(1);
    e.item = double(1);
    ps.diff_type_float = {i, e};

    i.item = NaN;
    e.item = double(1);
    ps.diff_type_nan = {i, e};

    i.item = inf;
    e.item = double(1);
    ps.diff_type_inf = {i, e};

    i.item = inf;
    e.item = nan;
    ps.diff_type_infnan = {i, e};

    i.item = int8(1);
    e.item = single(1);
    ps.diff_type_int8 = {i, e};

    i.item = @sin;
    e.item = @cos;
    ps.diff_type_fh = {i, e};

    % same function handle but different pointers
    i.item = @(x) sin(x) + 10;
    e.item = @(x) sin(x) + 10;
    ps.diff_type_fh_pointer = {i, e};

    i.item = cell(0, 0);
    e.item = struct();
    ps.diff_subitem_cs = {i, e};

    i.item = [1, 2, 3];
    e.item = [1, 2];
    ps.diff_subitem_array = {i, e};

    i.item = cell(1, 0);
    e.item = struct();
    ps.diff_type_cs = {i, e};

    i.item = 'abc';
    e.item = 'abca';
    ps.diff_content_char = {i, e};

    i.item = 10.111111111111111;
    e.item = 10.111111111111112;
    ps.diff_content_double = {i, e};

    i.item = cell(1, 1);
    i.item{1} = single(10);
    e.item = cell(1, 1);
    e.item{1} = double(10);
    ps.diff_cell_content_type = {i, e};

    i.item{1} = struct();
    i.item{1}.item = 'abc';
    e.item{1} = struct();
    e.item{1}.item = 10;
    ps.diff_cell_content_is_struct_with_content = {i, e};

    i.item = struct();
    i.item.item = cell(1, 1);
    e.item = struct();
    e.item.item = struct();
    ps.diff_struct_content = {i, e};

    i.item.item{1} = 10;
    e.item.item = cell(1, 1);
    e.item.item{1} = int8(10);
    ps.diff_struct_content_is_cell_with_content = {i, e};

    i.item.item{1} = struct();
    i.item.item{1}(3) = struct();
    e.item.item{1} = struct();
    ps.diff_content_structarray = {i, e};

    i.item.item{1}(2, 3) = struct();
    e.item.item{1}(3, 2) = struct();
    ps.diff_size_content_struct_array_size = {i, e};

    i = p;
    e = p;
    i = struct();
    i(3, 1) = struct();
    e = struct();
    ps.diff_size_structarray_3x1 = {i, e};

    i = p;
    e = p;
    i.item = struct();
    i.item(1, 3) = struct();
    e.item = struct();
    ps.diff_size_structarray_1x3 = {i, e};

    i = struct();
    i(3,3) = struct();
    e = struct();
    e(4,4) = struct();
    ps.diff_size_structarray_3x3v4x4 = {i,e};

    i = p;
    e = p;
    i.item = struct();
    i.item(3, 3) = struct();
    e.item = struct();
    e.item(4, 4) = struct();
    ps.diff_subitem_structarray_3x3v4x4 = {i, e};

    i = p;
    e = p;
    i.item = struct();
    i.item(3, 4) = struct();
    e.item = struct();
    e.item(4, 3) = struct();
    ps.diff_size_structarray_3x4v4x3 = {i, e};

    i = p;
    e = p;
    i.item.item2.item3 = {};
    e.item.item2 = struct();
    ps.diff_len_mismatch = {i, e};

    e.item.item2.item4 = {};
    ps.diff_name_structh = {i, e};

    i.item = cell(5, 1);
    e.item = cell(6, 1);
    ps.diff_len_cell_within_mismatch = {i, e};

    i.item = struct();
    i.item(5) = struct();
    e.item = struct();
    e.item(4) = struct();
    ps.diff_subitem_struct_length = {i, e};

    i.item = cell(5, 6);
    e.item = cell(6, 5);
    ps.diff_size_cell_size = {i, e};

    i.item = cell(2, 1);
    e.item = cell(2, 1);
    i.item{1} = zeros(3, 2);
    e.item{1} = zeros(2, 3);
    ps.diff_cell_content_size_mismatch = {i, e};

    i.item = struct();
    i.item.a = zeros(3, 2);
    e.item = struct();
    e.item.a = zeros(2, 3);
    ps.diff_struct_content_size_mismatch = {i, e};

    %structarray

    % i.item = struct();
    % i.item(1,1).name1 = 'a';
    % i.item(1,2).name1 = 'a';
    % i.item(1,3).name1 = 'a';
    % i.item(1,4).name1 = 'a';
    % e.item = struct();
    % e.item(1,1).name1 = 'aa';

end

function [ps] = load_validatetype_cases(),
    % load the validatetype test cases
    % ps only contains cases that the types between input and expected outputmatches.
    %
    z = load_treediff_cases();
    sametypes = {'diff_cell_content_type', 'diff_cell_content_is_struct_with_content', 'diff_struct_content', 'diff_struct_content_is_cell_with_content', 'diff_len_mismatch'};
    ps = struct();

    for k = 1:length(sametypes),
        ps.(sametypes{k}) = z.(sametypes{k});
    end

end

function [ps] = load_validatecontent_cases(),
    % load the validatecontent testcases
    % ps contains several validation cases that should fail and the respective why messages. The specific messages are required to match the fail with the reason.
    %
    z = load_treediff_cases();
    ps = struct();
    names = fieldnames(z);

    for k = 1:length(names),
        msg = '';

        if length(findstr('content', names{k})) > 0 || length(findstr('diff_type', names{k})) > 0,
            msg = 'Content mismatch';
        end

        if length(findstr('diff_name', names{k})) > 0,
            msg = 'Fieldnames differs';
        end

        if length(findstr('diff_subitem', names{k})) > 0,
            msg = 'Length of entries';
        end

        if length(findstr('diff_len', names{k})) > 0
            msg = 'number mismatch';
        end

        if length(findstr('diff_size', names{k})) > 0
            msg = 'Object size mismatch';
        end

        ps.(names{k}) = {z.(names{k}){1}, z.(names{k}){2}, msg};
    end

end
