function [nssize] = removeSingleton(sizearray)
% function [nssize] = removeSingleton(sizearray)
%
% Remove the singleton dimension sizes
% from a sizearray
%
% Inputs:
% 
% sizearray - A size array output
%
% Outputs:
% 
% nssize - A size array without singleton (1's)
%
% Example:
%
% assert(isequal(removeSingleton([1,1,10,30]),[10,30]));
% assert(isequal(removeSingleton([2,3,4]),[2,3,4]));
% assert(isempty(removeSingleton([1])))
%
% author: hugo.oliveira@utas.edu.au
%
narginchk(1,1)
if ~isindex(sizearray) 
	error('%s: Not a numeric index array')
end

nssize = sizearray;
singletons = find(nssize==1);
if singletons
	nssize = num2cell(nssize);
	nssize(singletons) = [];
	nssize = cell2mat(nssize);
end

end
