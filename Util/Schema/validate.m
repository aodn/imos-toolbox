function [is_valid, emsg] = validate(a, b, stopfirst);
    % function [is_valid, emsg] = validate(a, b);
    % validate a against b. The validation include type,size,length,name space, name match, and content.
    % `a` - any type input
    % `b` - any type input
    % `stopfirst` - a boolean to stop at first error
    % <->
    % is_valid - a bool with result
    % emsg - a str with errors
    %
    % author: hugo.oliveira@utas.edu.au
    if nargin<3
        stopfirst=true;
    end

    [is_diff, emsg] = treeDiff(a, b, stopfirst);

    if is_diff,
        is_valid = false;
    else
        is_valid = true;
    end

end
