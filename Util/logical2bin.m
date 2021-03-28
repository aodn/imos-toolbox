function [bitstring] = logical2bin(larr)
% function [bitstring] = logical2bin(larr)
%
% Convert a logical array to a bit string representation
%
% Inputs:
%
% larr - the logical array
%
% Outputs:
%
% bitstring - the bitstring array
%
% Example:
%
% %basic usage
% x = logical2bin([true,false,true,true,false]);
% assert(strcmpi(x,'10110'));
%
%
% author: hugo.oliveira@utas.edu.au
%
if ~islogical(larr)
	error('First argument is not logical')
end
bitstring = num2str(larr,'%d');
end
