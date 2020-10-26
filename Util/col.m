function [col] = col(array)
% function [col] = col(array)
%
% Compose a col vector from array.
%
% Inputs:
% 
% array - an array.
%
% Outputs:
% 
% col - a col vector.
%
% Example:
%
% assert(isequal(col([1;2;3]),[1;2;3]))
% assert(isequal(col([1,2,3]),[1;2;3]))
% assert(isequal(col(ones(3,3)),repmat(1,9,1)))
% assert(iscolumn(col(randn(1,30))))
%
% author: hugo.oliveira@utas.edu.au
%
if iscolumn(array)
	col = array;
else
	col = array(:);
end

end
