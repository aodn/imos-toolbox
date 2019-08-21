function [bool] = isequal_ctype(a,b),
	% function [bool] = isequal_ctype(a,b),
	% an enhanced isequal that compare type and content.
	% <->
	% bool - a boolean number representing if the type and content of a and b are the same.
	%
	% author: hugo.oliveira@utas.edu.au
	atype = whichtype(a);
	btype = whichtype(b);
	bool = isequal(atype,btype);
	if bool,
		bool = isequal(a,b);
	end
end
