function [bool] = isfunctionhandle(arg),
	bool = isa(arg,'function_handle');
end
