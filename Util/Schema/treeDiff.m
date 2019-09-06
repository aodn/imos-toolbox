function [isdiff, finalmsg] = treeDiff(a, b, stopfirst, func, this_root, n),
    % function [isdiff, finalmsg] = treeDiff(a, b, stopfirst, func, this_root, n),
    %
    % An enhanced isequal for matlab variables that supports
    % itemwise comparison between cells/structs at all nested levels.
    % The function compares types, names, lengths, sizes, and content.
    %
    % Inputs:
    %
    % a - an input non-class matlab variable.
    % b - another variable to be compared item-wise with a.
    % stopfirst - a boolean to stop at first error or
    %             continue until the first exception.
    % func - a function of two input arguments - func(a,b), and
    %        one boolean output indicating a result.
    %        Default: @isequal_ctype
    % this_root - a string representing the current nested level in the
    %             reported message. Internal use.
    %             Default: '|'
    % n - the current nested level number. Internal use.
    %     Default: 0.
    %
    % Outputs:
    %
    % isdiff - a boolean to check if `a~=b`.
    % finalmsg - a stack-like string representing
    %            where/why `a` and `b` are different.
    %            Default: empty char array if `a==b`.
    %
    % Example:
    % >>> % basic
    % >>> x = struct('x',3,'y',7,'z',11,'prime',13)
    % >>> y = x,stopfirst = false
    % >>> [isdiff,msg] = treeDiff(x,y,)
    % >>> assert(~isdiff)
    % >>> assert(isequal(msg,char()))
    %
    % >>> % differs
    % >>> x = struct('x',3,'y',7,'z',11,'prime',13)
    % >>> y = struct('x',4,'y',8,'z',12,'prime',14)
    % >>> stopfirst = false
    % >>> [isdiff,msg] = treeDiff(x,y,stopfirst)
    % >>> assert(isdiff)
    % >>> assert(contains(msg,'Content mismatch'))
    % >>> assert(contains(msg,'arg1(1).x'))
    % >>> assert(contains(msg,'arg1(1).y'))
    % >>> assert(contains(msg,'arg1(1).z'))
    % >>> assert(contains(msg,'arg1(1).prime'))
    %
    % >>> % using extra args [func]
    % >>> x = struct('x',3,'y',7,'z',11,'prime',13)
    % >>> y = struct('x',13,'y',13,'z',13,'prime',14);
    % >>> case=@(x) isstruct(x) || (isnumeric(x) && isprime(x))
    % >>> func =@(x) xcase(x) && xcase(y);
    % >>> [isdiff,msg] = treeDiff,x,y,stopfirst,func)
    % >>> assert(isdiff)
    % >>> assert(contains(msg,'Content mismatch - evaluation of `@'))
    % >>> assert(contains(msg,'.prime'))
    % >>> assert(~contains(msg,'arg1(1).x'))
    % >>> assert(~contains(msg,'arg1(1).y'))
    % >>> assert(~contains(msg,'arg1(1).z'))
    %
    % author: hugo.oliveira@utas.edu.au
    %

    % Copyright (C) 2019, Australian Ocean Data Network (AODN) and Integrated
    % Marine Observing System (IMOS).
    %
    % This program is free software: you can redistribute it and/or modify
    % it under the terms of the GNU General Public License as published by
    % the Free Software Foundation version 3 of the License.
    %
    % This program is distributed in the hope that it will be useful,
    % but WITHOUT ANY WARRANTY; without even the implied warranty of
    % MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    % GNU General Public License for more details.
    %
    % You should have received a copy of the GNU General Public License
    % along with this program.
    % If not, see <https://www.gnu.org/licenses/gpl-3.0.en.html>.
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
            msg{end + 1} = type_mismatch(type_a, type_b);
        catch ERROR
            finalmsg = compose(this_root, gather(msg, stopfirst));
            return;
        end

        try
            msg{end + 1} = len_mismatch(len_a, len_b, entry);
        catch ERROR
            finalmsg = compose(this_root, gather(msg, stopfirst));
            return;
        end

        try
            msg{end + 1} = name_mismatch(names_a, names_b);
        catch ERROR
            finalmsg = compose(this_root, gather(msg, stopfirst));
            return;
        end

        try
            msg{end + 1} = size_mismatch(size_a, size_b);
        catch ERROR
            finalmsg = compose(this_root, gather(msg, stopfirst));
            return;
        end

        try
            msg{end + 1} = len_within_mismatch(len_within_a, len_within_b);
        catch ERROR
            finalmsg = compose(this_root, gather(msg, stopfirst));
            return;
        end

        try
            msg{end + 1} = size_within_mismatch(size_within_a, size_within_b);
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
            msg{end + 1} = type_mismatch(type_a, type_b);
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
            msg{end + 1} = compose(this_root, [': Content mismatch - evaluation of `' func2str(func) '( arg1' strtrim(asinput) ', arg2' strtrim(asinput) ')`'' failed\n']);
        else
            disp(asinput)
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

function [msg] = type_mismatch(type_a, type_b),
    %function [msg] = type_mismatch(type_a, type_b),
    %
    % Return a custom msg if the string arguments
    % are different.
    %
    % Inputs:
    %
    % type_a - a string representing a type
    % type_b - as above.
    %
    % Outputs:
    %
    % msg - a custom msg regarding type mismatch.
    %
    % Example:
    % >>> msg = type_mismatch('','')
    % >>> assert(strcmp(msg,''))
    %
    % >>> msg = type_mismatch('a','b')
    % >>> assert(contains(msg,'Type mismatch'))
    %
    % author: hugo.oliveira@utas.edu.au
    %

    msg = '';
    typediff = ~strcmpi(type_a, type_b);

    if typediff,
        msg = [': Type mismatch - expected `' type_a '` got `' type_b '`''\n'];
        return,
    end

end

function [msg] = len_mismatch(len_a, len_b, entry),
    %function [msg] = len_mismatch(len_a,len_b,entry),
    %
    % Return a custom msg if the len arguments
    % are different.
    %
    % Inputs:
    %
    % len_a - a number representing length
    % len_b - as above.
    % entry - a string - ['Fieldnames','Indexes']
    %
    % Outputs:
    %
    % msg - a custom msg regarding length mismatch.
    %
    % Example:
    % >>> msg = len_mismatch(1,1,'Fieldnames')
    % >>> assert(strcmp(msg,''))
    %
    % >>> msg = len_mismatch(1,3,'Fieldnames')
    % >>> assert(contains(msg,'Fieldnames number mismatch'))
    %
    % >>> msg = len_mismatch(1,3,'Indexes')
    % >>> assert(contains(msg,'Indexes number mismatch'))
    %
    % author: hugo.oliveira@utas.edu.au
    %

    msg = '';
    dlen = len_a ~= len_b;

    if dlen,
        msg = [': ' entry ' number mismatch - expected `' num2str(len_a) '` got `' num2str(len_b) '`\n'];
    end

end

function [msg] = name_mismatch(names_a, names_b),
    %function [msg] = name_mismatch(names_a,names_b),
    %
    % Return a custom msg if the set of strings
    % within the cell arugments are different.
    %
    % Inputs:
    %
    % names_a - a cell with strings.
    % names_b - as above.
    %
    % Outputs:
    %
    % msg - a custom msg regarding unique names
    %       mismatch.
    %
    % Example:
    % >>> msg = name_mismatch({'a','b'},{'b','a'})
    % >>> assert(strcmp(msg,''))
    %
    % >>> msg = name_mismatch({'a','b'},{'a'})
    % >>> assert(contains(msg,'Fieldnames differs'))
    %
    % author: hugo.oliveira@utas.edu.au
    %
    msg = '';
    sorted_a = union(names_a, {});
    sorted_b = union(names_b, {});
    unames = union(sorted_a, sorted_b);
    diff_names = ~isequal(unames, sorted_a) ||~isequal(unames, sorted_b);

    if diff_names
        msg = [': Fieldnames differs - expected sorted names to be `' strjoin(sorted_a, ',') '` got `' strjoin(sorted_b, ',') '`''\n'];
    end

end

function [msg] = size_mismatch(size_a, size_b);
    %function [msg] = size_mismatch(size_a,size_b),
    %
    % Return a custom msg if the array size
    % arguments are different.
    %
    % Inputs:
    %
    % size_a - a cell with strings.
    % size_b - as above.
    %
    % Outputs:
    %
    % msg - a custom msg regarding size
    %       mismatch.
    %
    % Example:
    % >>> msg = size_mismatch({'a','b'},{'b','a'})
    % >>> assert(strcmp(msg,''))
    %
    % >>> msg = size_mismatch([1,10],[1,10])
    % >>> assert(contains(msg,'Object size mismatch'))
    %
    % author: hugo.oliveira@utas.edu.au
    %

    msg = '';
    dsize = size_a ~= size_b;

    if any(dsize),
        msg = [': Object size mismatch - expected ' strrep(['(' num2str(size_a) ')'], '  ', ',') ' got ' strrep(['(' num2str(size_b) ')'], '  ', ',') '\n'];
    end

end

function [msg] = len_within_mismatch(len_within_a, len_within_b),
    %function [msg] = len_within_mismatch(size_a,size_b),
    %
    % Return a custom msg if the lengths of entries
    % are different.
    %
    % Inputs:
    %
    % len_within_a - a cell with singleton arrays of doubles..
    % len_within_b - as above.
    %
    % Outputs:
    %
    % msg - a custom msg regarding lengths within
    %       mismatch.
    %
    % Example:
    % >>> msg = len_within_mismatch({[1],[1]},{[1],[1]})
    % >>> assert(strcmp(msg,''))
    %
    % >>> msg = len_within_mismatch({[1],[]},{[1],[3]}
    % >>> assert(contains(msg,'Length of entries mismatch'))
    %
    % author: hugo.oliveira@utas.edu.au
    %

    msg = '';
    sa = length(len_within_a);
    sb = length(len_within_b);

    for k = 1:sa,
        a_len_within_larger = len_within_a{k} > len_within_b{k};
        b_len_within_larger = len_within_b{k} > len_within_a{k};

        if a_len_within_larger || b_len_within_larger,
            msg = [': Length of entries mismatch - expected ' num2str(len_within_a{k}) ' got ' num2str(len_within_b{k}) '\n'];
            return;
        end

    end

end

function [msg] = size_within_mismatch(size_within_a, size_within_b);
    %function [msg] = size_within_mismatch(size_a,size_b),
    %
    % Return a custom msg if the size of entries
    % are different.
    %
    % Inputs:
    %
    % size_within_a - a cell with arrays of doubles..
    % size_within_b - as above.
    %
    % Outputs:
    %
    % msg - a custom msg regarding sizes within
    %       mismatch.
    %
    % Example:
    % >>> msg = size_within_mismatch({[1 2],[1 2]},{[1 2],[1 2]})
    % >>> assert(strcmp(msg,''))
    %
    % >>> msg = size_within_mismatch({[1 2],[1 3]},{[2 1],[3 1]}
    % >>> assert(contains(msg,'Size of entries mismatch'))
    %
    % author: hugo.oliveira@utas.edu.au
    %

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
    %
    %  Return a string representation of the nested level
    %  object/variable.
    %
    % Inputs:
    %
    % this_root - a string representing the current level
    % name - a string of the variable name
    % sflag - a boolean to identify that `name` is a struct fieldname
    % sindex - the index of the structarray.
    %          if `sflag==0` it's ignored (cell indexes).
    %
    % Outputs:
    % rmsg - a string representing the current scope/walk level
    %
    % Example:
    % >>> rmsg = root_msg('|','x',1,1)
    % >>> assert(strcmpi(rmsg,'|(1).x'))
    %
    % >>> rmsg = root_msg('|','1',0,false)
    % >>> assert(strcmpi(rmsg, '|{1}'))

    % author: hugo.oliveira@utas.edu.au
    %

    narginchk(3, 4)

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

function [anym] = anymsg(msg);
    % function [anym] = anymsg(msg);
    %
    % Return a bool if the cell msg is not empty
    %
    % Inputs:
    %
    % msg - a cell of strings
    %
    % Output:
    %
    % anymsg - a bool indicating emptyness
    %
    % Example:
    % >>> [anym] = anymsg({'hello'})
    % >>> assert(anym)
    %
    % >>> [anym] = anymsg({})
    % >>> assert(~anym)
    %
    % author: hugo.oliveira@utas.edu.au
    %

    n = prod(size(msg));

    for k = 1:n

        if ~isempty(msg{k}),
            anym = true;
            return;
        end

    end

    anym = false;
end

function [finalmsg] = compose(this_root, msg);
    % function [finalmsg] = compose(this_root, msg);
    %
    % Compose a msg given a current nested level and
    % a cell of strings, correcting for some
    % particular cases.
    %
    % Inputs:
    %
    % this_root - a string representing the current level
    % msg - a string with all msgs appended.
    %
    % Outputs:
    %
    % finalmsg - a single msg string for use with
    %            printf methods.
    %
    % author: hugo.oliveira@utas.edu.au
    %

    n = 0;
    ss = '';
    se = '\n';
    ws = ' ';

    is_root = this_root == '|';

    if is_root,
        finalmsg = strcat(ss, this_root, ws, msg);
    else
        finalmsg = strcat('\n', ss, this_root, ws, msg);
    end

    no_newline_at_end = ~strcmpi(finalmsg(end - 1:end), '\n');

    if no_newline_at_end,
        finalmsg = strcat(finalmsg, '\n');
    end

    trim_double_start_char = strcmpi(finalmsg(1:2), '||');

    if trim_double_start_char,
        finalmsg = finalmsg(2:end);
    end

end

function [amsg, abort] = gather(allmsg, stopfirst);
    % function [amsg, abort] = gather(allmsg, stopfirst);
    %
    % Gather all non-empty strings in the allmsg cell
    % or only the first non-empty index.
    %
    % Inputs:
    %
    % allmsg - a cell of strings.
    % stopfirst - a boolean to stop a first non-empty index.
    %
    % Outputs:
    %
    % amsg - the aggregated or singleton string msg.
    % abort - a abort boolean to identify that this
    %         function was called with an all empty cell.
    %
    % Example:
    % >>> [amsg,abort] = gather({char(),char(),'a','b'},1)
    % >>> assert(strcmpi(amsg,'ab'))
    % >>> assert(~abort)
    %
    % >>> [amsg,abort] = gather({char()},false)
    % >>> assert(abort)
    %
    % author: hugo.oliveira@utas.edu.au
    %

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
