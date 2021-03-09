function [blog] = bin2logical(bitstring)
% function [blog] = bin2logical(bitstring)
%
% Convert a bit string to a logical array
%
% Inputs:
%
% bitstring[str] - A bit string containing only '0' or '1'.
%
% Outputs:
%
% blog[logical] - A logical array 
%
% Example:
%
% %basic usage
% x = bin2logical('10001');
% assert(all(x([1,5])))
% assert(~all(x([2,3,4])));
%
%
% author: hugo.oliveira@utas.edu.au
%
narginchk(1,1)
if ~ischar(bitstring)
	errormsg('Not a bit string')
end

blog = zeros(size(bitstring),'logical');
for k=1:numel(bitstring)
	if strcmp(bitstring(k),'0')
		blog(k) = false;
	elseif strcmp(bitstring(k),'1')
		blog(k) = true;
	else
		errormsg('Invalid bit string: %s',bitstring)
	end
end
