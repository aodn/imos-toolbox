function [ok, msg] = test_docstring(filename,dbreak)
% function [ok,msg] = test_docstring(filename,dbreak)
%
% Test the Example block of an IMOS source code matlab file.
%
% The function works by evaluating everything
% between the `% Example:` line and the
% `% author:` line of a help block.
%
% Inputs:
%
% filename - the matlab file
% dbreak - a boolean to interactively stop at a
%          wrong docstring evaluation.
%
% Outputs:
%
% ok - if the test succeeded
% msg - the fail msg
%
% Example:
% % test used functions
% [ok,msg] = test_docstring('comment_eval_wrapper');
% assert(ok)
% assert(isempty(msg))
% [ok,msg] = test_docstring('read_until_match');
% assert(ok)
% assert(isempty(msg))
%
% author: hugo.oliveira@utas.edu.au
%
narginchk(1, 2)
if nargin<2
    dbreak = false;
end

fid = fopen(filename, 'r');

if fid < 0
    fullfile = which(filename);
    fid = fopen(fullfile, 'r');

    if fid < 0
        error('cant read %s', filename);
    end

end

use_regex = true;
docstring_start_re = '^\s?%\s?Example[s]?:';
docstring_end_re = '^\s?%\s?author[s]?:';
%TODO: when licenses are removed from all source files, include the one below.
%docstring_end_re = '^(?!\s?%).+';

[docstring_text, block_start_line] = read_until_match(fid, docstring_start_re, use_regex);
if isempty(docstring_text)
    ok = false;
    msg = sprintf('No docstring Example block found in %s',filename);
    return
end

text_to_evaluate = read_until_match(fid, docstring_end_re, use_regex);
text_to_evaluate = text_to_evaluate(1:end-1); % remove docstring_end_re match

[ok, msg] = comment_eval_wrapper(text_to_evaluate, block_start_line, dbreak);

if ~ok
    [~, file] = fileparts(filename);
    msg = [file msg];
end

end
