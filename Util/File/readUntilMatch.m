function [clines, number_of_lines] = readUntilMatch(fid, pattern, is_regex, stacksize)
%function [clines, number_of_lines] = readUntilMatch(fid, pattern, is_regex, stacksize)
%
% Read a file, line by line, until a pattern is found, returning
% all lines read and the total number of lines.
% The result is empty (total number of lines) if no match is found.
%
% Inputs:
%
% fid - numerical file id
% pattern - the string pattern to match
% is_regex - the string pattern is a regex.
%            Default: False.
% stacksize - the preallocation length (N) of the clines cell (1xN).
%
%
% Outputs:
%
% clines - a cell of strings with all lines read until the match.
% number_of_lines - the total number of lines read
%
% Example:
% % create
% tmpfile = [tempdir 'test_readUntilMatch.txt'];
% fid = fopen(tmpfile,'w');
% fprintf(fid,'%c\n%c\n%c\n',['a','X','c']);
% fclose(fid);
%
% % full read
% fid = fopen(tmpfile,'r');
% [text,lc] = readUntilMatch(fid,'X');
% assert(isequal(text{1},'a'))
% assert(isequal(text{2},'X'))
% assert(lc==2)
%
% % partial read
% fid = fopen(tmpfile,'r');
% [text,lc] = readUntilMatch(fid,'a');
% assert(isequal(text{1},'a'))
% assert(length(text)==1)
% assert(lc==1)
%
% % empty case
% fid = fopen(tmpfile,'r');
% [text,lc] = readUntilMatch(fid,'Z');
% assert(isempty(text));
% assert(lc==4)
%
% author: hugo.oliveira@utas.edu.au
%
narginchk(2, 4)

if nargin < 3
    is_regex = false;
end

if nargin < 4
    stacksize = 1000;
end

if is_regex
    match_fun = @regexp;
else
    match_fun = @contains;
end

[text, eof] = read_line(fid);
if eof
    number_of_lines = 0;
    clines = {};
    return
else
    number_of_lines = 1;
    clines = cell(1, stacksize);
    clines{1} = text;
end

while ~eof
    matched = match_fun(text, pattern);
    if matched
        break
    end
    [text, eof] = read_line(fid);
    number_of_lines = number_of_lines +1;
    clines{number_of_lines} = text;
end

if ~matched
    clines = {};
else
    clines=clines(1:number_of_lines);
end

end

function [text, eof] = read_line(fid)
%
% read a line from a matlab
% file identification integer.
%
eof = false;
text = fgetl(fid);

if isnumeric(text)
    eof = true;
    return
end

end
