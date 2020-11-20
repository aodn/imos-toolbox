function [arr] = randomBetween(a,b,n,type)
% function [arr] = randomBetween(a,b,n,type)
%
% Draw n numbers from the a-b range (inclusive)
%
% Inputs:
%
% a - start of random range (inclusive)
% b - end of random range (inclusive)
% n - the number of draws
% type - optional type string.
%      - default: 'double'
%      - available: 'double','int', or 'logical'.
% Outputs:
%
% arr - an array of size 1xn with random numbers in the ]a,b[ open interval.
%
% Example:
% %from: https://www.mathworks.com/help/matlab/math/floating-point-numbers-within-specific-range.html
% arr=randomBetween(0,1,10);
% assert(min(arr)>0 && max(arr)<1)
%
% % random int
% arr=randomBetween(0,5,100,'int');
% assert(all(double(int64(arr))==arr))
%
% % random logical
% arr=randomBetween(0,1,100,'logical');
% assert(min(arr)==0 && max(arr)==1)
%
% % random constant
% arr=randomBetween(1,1,10,'int');
% assert(isequal(arr,ones(1,10)));
%
%
% author: hugo.oliveira@utas.edu.au
%

if nargin==4
	if contains(type,'int')
		arr = randi([a b],1,n);
		return
	end
	if contains(type,'logical')
		arr = logical(randi([0,1],1,n));
		return
	end
end

if nargin<3
	n = 1;
end
arr = (b-a).*rand(1,n) + a;
end
