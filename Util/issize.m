function [bool] = issize(carray)
% function [bool] = issize(carray)
%
% Check if carray is a valid
% and complete size array.
%
% A valid and complete size array
% is a non-scalar row vector
% with positive integers only.
%
% Inputs:
%
% carray - an array.
%
% Outputs:
%
% bool - true or false.
%
% Example:
%
% %basic
% assert(issize([1,10]))
%
% %a scalar size is incomplete
% assert(~issize(1))
%
% %a logical size is invalid
% assert(~issize([0,1]))
%
% %a column-vector is invalid
% assert(~issize([1;1]))
%
% %a fractional double value is invalid
% assert(~issize([1.5,3.3]))
%
%
% author: hugo.oliveira@utas.edu.au
%
bool = ~isscalar(carray) && isrow(carray) && isindex(carray) && all(carray > 0);
end
