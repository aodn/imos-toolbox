function [name] = callerName()
% function [name] = callerName()
%
% Return the name of the function that 
% called this function.
%
% Inputs:
%
%
% Outputs:
%
% name - the function name.
%
% Example:
% %only works here since this is evaluated.
% name = callerName();
% assert(strcmpi(callerName,'testDocstring'));
% %outside any function
% %assert(callerName(),'user-interaction');
%
%
% author: hugo.oliveira@utas.edu.au
%
narginchk(0,0);
s = dbstack(2);
if isempty(s)
	name = '';
else
	name = s(1).name;
end
end
