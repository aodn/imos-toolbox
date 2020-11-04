function [ok, msg] = commentEvalWrapper(cell_of_strings, line_offset, dbreak)
%function [ok, msg] = commentEvalWrapper(cell_of_strings)
%
% a closure to evaluate commented string entries
% inside a cell. The function stops at the first
% empty entry in a cell and ignore all non comments
% entries.
%
% Inputs:
%
% cell_of_strings - a cell of strings to be evaluated.
% line_offset - The line offset of the commented string.
%               Default: 0.
% dbreak - boolean to break/keyboard at a wrong evaluation.
%
% Outputs:
%
% ok - if the evaluation was fine.
% msg - the fail msg if any.
%
% Example:
%
% [ok,msg] = commentEvalWrapper({'%a=10;','%b=a-10.;'});
% assert(ok)
% assert(isempty(msg))
%
% % Manual testing below, since nested calls will trigger a fail
% % [ok,msg] = commentEvalWrapper({'%a?x=10;'});
% % assert(~ok)
% % assert(contains(msg,'Error:'));
%
% author: hugo.oliveira@utas.edu.au
%
if nargin < 2
    line_offset = 0;
end
BOL_re = '(\s*%\s*)';
EXPR_re = '(?<expr>.+$)';
re = [BOL_re EXPR_re];

ok = false;
msg = '';

nentries = length(cell_of_strings);
k = 1;

while true

    if k > nentries
        break
    end

    etext = cell_of_strings{k};

    if isempty(etext)
        break
    else
        match = regexpi(etext, re, 'names');

        if ~isempty(match)
            etext = match.expr;

            try
                eval(etext)
            catch err
                msg = sprintf('{line(%d)}:%%%s -> %s', line_offset + k, etext, err.message);
                if dbreak
                    docstring_stack(cell_of_strings, k, msg)
                    keyboard;
                else
                    disp(msg)
                end

                return
            end

        end

    end

    k = k + 1;
end

ok = true;
end

function docstring_stack(cell_of_strings, errind, msg)
%function stop_at_docstring_error(cell_of_strings, errind, msg)
%
% Display/debug the erroed docstring
%
disp('%->Docstring start')

for c = 1:errind
    disp(cell_of_strings{c})
end
disp(msg)
end
