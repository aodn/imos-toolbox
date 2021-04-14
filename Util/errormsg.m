function errormsg(msg,varargin)
% function errormsg(msg,varargin)
%
% A Wrapper to error, but showing where
% the error ocurred.
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
    error('Error at errormsg(line 21): msg argument is compulsory')
end

cstack = dbstack;
if numel(cstack) == 1
    n = 1;
else
    n = 2;
end
name = cstack(n).name;
line = cstack(n).line;

actualmsg = sprintf([name '(' num2str(line) '):' msg],varargin{:});
dotsplit = split(name,'.');
if numel(dotsplit) == 1
	name_as_id = sprintf('%s:%s',dotsplit{1},dotsplit{1});
else
	id_msg = repmat('%s:',1,numel(dotsplit));
	id_msg = id_msg(1:end-1);
	name_as_id = sprintf(id_msg,dotsplit{:});
end
actual_exception = MException(name_as_id,actualmsg);
try
	actual_exception.none
catch me
	throwAsCaller(actual_exception)
end
