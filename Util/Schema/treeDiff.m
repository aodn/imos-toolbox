function [isdiff, finalmsg] = treeDiff(a, b, stopfirst, func, this_root, n),
    % function [isdiff, finalmsg] = treeDiff(a, b, stopfirst, func, this_root, n),
    % an enhanced isequal for matlab variables that supports cells/structs itemwise comparison at all nested levels.
    % The function compares types, names, lengths, sizes, and content.
    % `a` - an input variable
    % `b` - an expected variable to be equal to `a`
    % `stopfirst` - a boolean to stop at first error or continue until the first exception
    % `func` - internal use - a function handle to a function fo two arguments - default to isequal_ctype
    % `this_root` - internal use - a string representing the current nested level - default to `|`
    % `n` - internal use - the current nested level number - default to 0.
    % <->
    % `isdiff` - return true if is `a~=b`.
    % `finalmsg` - a stack-like string representing where/why `a` and `b` are different.
    %
    % author: hugo.oliveira@utas.edu.au
    %
    if nargin < 3
        stopfirst = true;
        func = @isequal_ctype;
        this_root = '|';
        n = 0;
    elseif nargin < 4
        func = @isequal_ctype;
        this_root = '|';
        n = 0;
    elseif nargin < 5
        this_root = '|';
        n = 0;
    elseif nargin < 6
        n = 0;
    end

    finalmsg = '';
    msg = cell(0, 0);
    abort = false;
    isdiff = true;

    is_a_struct = isstruct(a);
    is_b_struct = isstruct(b);
    is_a_cell = iscell(a);
    is_b_cell = iscell(b);

    both_structs = is_a_struct && is_b_struct;
    both_cells = is_a_cell && is_b_cell;

    if both_structs,
        entry = 'Fieldnames';
    else
        entry = 'Length';
    end

    [names_a, len_a, size_a, len_within_a, size_within_a, type_a, types_in_a] = objinfo(a);
    [names_b, len_b, size_b, len_within_b, size_within_b, type_b, types_in_b] = objinfo(b);

    if both_structs || both_cells,

        try
            msg{end + 1} = type_mismatch(type_a, type_b, n);
        catch ERROR
            finalmsg = compose(this_root, gather(msg, stopfirst));
            return;
        end

        try
            msg{end + 1} = len_mismatch(len_a, len_b, entry, n);
        catch ERROR
            finalmsg = compose(this_root, gather(msg, stopfirst));
            return;
        end

        try
            msg{end + 1} = name_mismatch(names_a, names_b, n);
        catch ERROR
            finalmsg = compose(this_root, gather(msg, stopfirst));
            return;
        end

        try
            msg{end + 1} = size_mismatch(size_a, size_b, n);
        catch ERROR
            finalmsg = compose(this_root, gather(msg, stopfirst));
            return;
        end

        try
            msg{end + 1} = len_within_mismatch(len_within_a, len_within_b, n);
        catch ERROR
            finalmsg = compose(this_root, gather(msg, stopfirst));
            return;
        end

        try
            msg{end + 1} = size_within_mismatch(size_within_a, size_within_b, n);
        catch ERROR
            finalmsg = compose(this_root, gather(msg, stopfirst));
            return;
        end

        % walk through
        if both_structs,

            for kk = 1:numel(a),

                for k = 1:len_a,
                    name = names_a{k};
                    root_str = root_msg(this_root, name, true, kk);

                    try
                        [~, msg{end + 1}] = treeDiff(a(kk).(name), b(kk).(name), stopfirst, func, root_str, n + 1);
                    catch ERROR
                        finalmsg = compose(this_root, gather(msg, stopfirst));
                        return;
                    end

                end

            end

        else

            for k = 1:len_a
                root_str = root_msg(this_root, num2str(k), false);

                try
                    [~, msg{end + 1}] = treeDiff(a{k}, b{k}, stopfirst, func, root_str, n + 1);
                catch ERROR
                    finalmsg = compose(this_root, gather(msg, stopfirst));
                    return;
                end

            end

        end

        funcfail = ~func(a, b);

    else % simple cases or nested levels

        try
            msg{end + 1} = type_mismatch(type_a, type_b, n);
        catch ERROR
            finalmsg = compose(this_root, gather(msg, stopfirst));
            return;
        end

        funcfail = ~func(a, b);

    end

    if funcfail;
        asinput = strrep(this_root, '|.', '');
        asinput = strrep(asinput, '|', '');
        not_simple_case = ~strcmpi(strtrim(asinput), '');

        if not_simple_case,
            asinput = strrep(this_root, '|', '');
            msg{end + 1} = compose(this_root, [': Content mismatch - evaluation of `' func2str(func) '( arg1' strtrim(asinput) ', arg2' strtrim(asinput) ')`'' failed']);
        else
            msg{end + 1} = compose(this_root, [': Content mismatch - evaluation of `' func2str(func) '( a' strtrim(asinput) ', b' strtrim(asinput) ')`'' failed\n']);
        end

        finalmsg = compose(this_root, gather(msg, stopfirst));
    else
        got_msg = anymsg(msg);

        if got_msg,
            [finalmsg, abort] = gather(msg, stopfirst);

            if abort,
                error(compose(this_root, finalmsg));
            end

        else
            isdiff = false;
        end

    end

end

%
function [msg] = type_mismatch(type_a, type_b, n),
    msg = '';
    typediff = ~strcmpi(type_a, type_b);

    if typediff,
        msg = [': Type mismatch - expected `' type_a '` got `' type_b '`''\n'];
        return,
    end

end

function [msg] = len_mismatch(len_a, len_b, entry, n),
    msg = '';
    dlen = len_a ~= len_b;

    if dlen,
        msg = [': ' entry ' number mismatch - expected `' num2str(len_a) '` got `' num2str(len_b) '`\n'];
    end

end

function [msg] = name_mismatch(names_a, names_b, n),
    msg = '';
    sorted_a = union(names_a, {});
    sorted_b = union(names_b, {});
    unames = union(sorted_a, sorted_b);
    diff_names = ~isequal(unames, sorted_a) ||~isequal(unames, sorted_b);

    if diff_names
        msg = [': Fieldnames differs - expected sorted names to be `' strjoin(sorted_a, ',') '` got `' strjoin(sorted_b, ',') '`''\n'];
    end

end

function [msg] = size_mismatch(size_a, size_b, n);
    msg = '';
    dsize = size_a ~= size_b;

    if any(dsize),
        msg = [': Object size mismatch - expected ' strrep(['(' num2str(size_a) ')'], '  ',',') ' got ' strrep(['(' num2str(size_b) ')'], '  ',',') '\n'];
    end

end

function [msg] = len_within_mismatch(len_within_a, len_within_b, n),
    msg = '';
    sa = length(len_within_a);
    sb = length(len_within_b);

    for k = 1:sa,
        a_len_within_larger = len_within_a{k} > len_within_b{k};
        b_len_within_larger = len_within_b{k} > len_within_a{k};

        if a_len_within_larger,
            msg = [': Length of entries mismatch - expected ' num2str(len_within_a{k}) ' got ' num2str(len_within_b{k}) '\n'];
            return;
        elseif b_len_within_larger,
            msg = [': Length of entries mismatch - expected ' num2str(len_within_b{k}) ' got ' num2str(len_within_a{k}) '\n'];
            return;
        end

    end

end

function [msg] = size_within_mismatch(size_within_a, size_within_b, n);
    msg = '';
    sa = length(size_within_a);
    sb = length(size_within_b);

    for k = 1:sa,
        a_size_within_larger = size_within_a{k} > size_within_b{k};
        b_size_within_larger = size_within_b{k} > size_within_a{k};

        if a_size_within_larger,
            msg = [': Size of entries mismatch - expected ' num2str(size_a) ' got ' num2str(size(b)) '\n'];
            return;
        elseif b_size_within_larger,
            msg = [': Size of entries mismatch - expected ' num2str(size_b) ' got ' num2str(size(a)) '\n'];
            return;
        end

    end

end

function [rmsg] = root_msg(this_root, name, sflag, sindex);
    % function [rmsg] = root_msg(this_root, name, sflag);
    % return a str representation of a nested level object/variable
    % `this_root` - a string representing the current level
    % `name` - a string of the variable name
    % `sflag` - a boolean to identify that `name` is a struct member
    % `sindex` - the index if this structure is a structarray  - default to 0
    % otherwise a cell is assumed.
    % <->
    % `rmsg` - a string representing the current variable nested scope
    if sflag,

        if nargin < 4
            rmsg = strcat(this_root, '.', name);
        else
            rmsg = strcat(this_root, '(', num2str(sindex), ')', '.', name);
        end

    else
        rmsg = strcat(this_root, '{', name, '}');
    end

end

function [anymsg] = anymsg(msg);
    % function [anymsg] = anymsg(msg);
    % return a bool if the cell `msg` is not empty
    %
    n = prod(size(msg));

    for k = 1:n

        if ~isempty(msg{k}),
            anymsg = true;
            return;
        end

    end

    anymsg = false;
end

function [finalmsg] = compose(this_root, msg);
    % function [finalmsg] = compose(this_root, msg);
    % compose a msg given a current nested level and
    % a cell of strings.
    n = 0;
    ss = '';
    se = '\n';
    ws = ' ';

    if this_root == '|',
        finalmsg = strcat(ss, this_root, ws, msg);
    else
        finalmsg = strcat('\n', ss, this_root, ws, msg);
    end

    if ~strcmpi(finalmsg(end - 1:end), '\n'),
        finalmsg = strcat(finalmsg, '\n');
    end

end

function [amsg, abort] = gather(allmsg, stopfirst);
    % gather all or the first message in `allmsg`.
    abort = false;
    amsg = '';

    for k = 1:length(allmsg),

        if ~isempty(allmsg{k})

            if stopfirst,
                amsg = allmsg{k};
                return;
            else
                amsg = strcat(amsg, allmsg{k});
            end

        end

    end

    if isempty(amsg),
        abort = true;
        ss = strcat('VerificationError with previous msgs: ');
        se = strjoin(allmsg);
        amsg = strcat(ss, se);
    end

end
