function [argtype] = whichtype(arg),
	% function [argtype] = whichtype(arg),
	% a wrapper to return a string represenation of type arg
	% `arg` - any matlab type
	% <->
	% argtype - a string representation of the type
	%
	% author: hugo.oliveira@utas.edu.au
	%
	[~,~,~,argtype] = detectType(arg);
end
