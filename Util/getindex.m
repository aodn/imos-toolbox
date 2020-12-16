function [value] = getindex(arg,index)
% function [value] = getindex(arg,index)
%
% Get an index from an argument.
%
% Inputs:
%
% arg [string | char | logical | cell | struct | array] - an argument.
%
% Outputs:
%
% value - If a struct, this is or arg.(fieldnames(arg)(index)),
%         If a cell, this is arg(index),
%         Otherwise, this is type(arg)(arg(index)).
%
% Example:
%
% %basic usage
% assert(isequal(getindex({1,2,3},3),3)); %parenthesis access
% assert(~isequal(getindex({1,2,{3}},3),{{3}})); %double cell inconsistency
% assert(isequal(getindex(struct('one',1,'two',2),2),2));
% assert(isequal(getindex([true,true,false],3),false));
%
% %raise error for invalid inputs
% f=false;try;getindex(1,10);catch;f=true;end
% assert(f)
%
%
% author: hugo.oliveira@utas.edu.au
%
narginchk(2,2);

aclass = class(arg);

if isnumeric(arg) && isscalar(arg)
	errormsg('Argument is a scalar.')
end
access_is_by_fieldname = isstruct(arg);
access_is_by_brackets = iscell(arg);
access_is_by_parenthesis = islogical(arg) || ischar(arg) || isstring(arg) || isnumeric(arg);

if ~access_is_by_fieldname && ~access_is_by_brackets && ~access_is_by_parenthesis
	errormsg('Index fetching for class %d is not implemented.',aclass)
end

try
	if access_is_by_fieldname
		fnames = fieldnames(arg);
		value = arg.(fnames{index});
	elseif access_is_by_brackets
		value = arg{index};
	elseif access_is_by_parenthesis
		value = arg(index);
	end
catch
	errormsg('Index %d out of range',index)
end
