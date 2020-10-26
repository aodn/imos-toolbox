function [row] = row(array)
% function [row] = row(array)
%
% Compose a row vector from array.
%
% Inputs:
% 
% array - an array.
%
% Outputs:
% 
% row - a row vector.
%
% Example:
%
% assert(isequal(row([1,2,3]),[1,2,3]))
% assert(isequal(row(ones(3,3)),repmat(1,1,9)))
% assert(isrow(row(randn(30,1))))
%
% author: hugo.oliveira@utas.edu.au
%
if isrow(array)
	row = array;
else
	row = transpose(array(:));
end

end
