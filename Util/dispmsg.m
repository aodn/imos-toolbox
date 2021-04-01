function dispmsg(msg,varargin)
% function dispmsg(msg,varargin)
%
% A Wrapper to disp, but showing where
% the function is being called.
%
% Inputs:
%
% msg - A message string.
% varargin - sprintf/further arguments (e.g.fields for msg).
%
%
% Example:
%
% %basic usage
%
%
% author: hugo.oliveira@utas.edu.au
%
if nargin < 1
    error('Error at dispmsg(line 21): msg argument is compulsory')
end

cstack = dbstack(1);
name = cstack(1).name;
line = cstack(1).line;
actualmsg = sprintf([name '(' num2str(line) '): ' msg],varargin{:});
disp(actualmsg)
end
