function [is_valid, emsg] = validateType(a, b, stopfirst);
    % function [is_valid, emsg] = validateType(a, b, stopfirst);
    % validate, recursively, the types of `a` and `b`
    % `a` - input of any type
    % `b` - input of any type
    % `stopfirst` - boolean to stop at first error
    %  <->
    % `is_valid` - bool with result
    % `emsg` - str with errors
    %
    % author: hugo.oliveira@utas.edu.au
    %
    if nargin<3,
        stopfirst=true;
    end

    atype = createTree(a);
    btype = createTree(b);
    [is_diff, emsg] = treeDiff(atype, btype, stopfirst);

    if is_diff,
        is_valid = false;
    else
        is_valid = true;
    end

end
