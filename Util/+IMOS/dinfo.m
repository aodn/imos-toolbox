function [info] = dinfo(obj)
% function [info] = dinfo(obj)
%
% Return several information fields
% about the dimensions of an obj.
%
% Inputs:
%
% obj - any standard matlab object.
%
% Outputs:
%
% info[struct] -  The dimension structure information.
%
% Example:
%
% %basic usage
% x = IMOS.dinfo(zeros(3,1,2));
% assert(all(x.size==[3,1,2]))
% assert(x.numel==6)
% assert(x.ndims==3)
% assert(~x.lack_dimensions)
% assert(~x.isvector)
% assert(~x.iscolumn)
% assert(~x.isrow)
% assert(~x.ismatrix)
% assert(all(x.sorted_indexes==[1,2,3]))
% assert(x.max_dim_index==1)
% assert(x.min_dim_index==2)
% assert(all(x.singleton_dimensions==[0,1,0]))
% assert(x.total_singleton_dims==1)
% assert(x.has_singleton_dim)
% assert(x.squeezable)
%
%
% author: hugo.oliveira@utas.edu.au
%
narginchk(1, 1);
info.size = size(obj);
info.lack_dimensions = sum(info.size) == 0;

if info.lack_dimensions
    info.numel = 0;
    info.ndims = 0;
else
    info.numel = numel(obj);
    info.ndims = ndims(obj);
end

info.isvector = isvector(obj);
info.iscolumn = iscolumn(obj);
info.isrow = isrow(obj);

if info.lack_dimensions
    info.ismatrix = false;
else
    info.ismatrix = ismatrix(obj);
end

info.sorted_indexes = sort(info.size);

if info.lack_dimensions
    info.max_dim_index = 0;
    info.min_dim_index = 0;
else
    info.max_dim_index = find(info.sorted_indexes(end) == info.size, 1, 'first');
    info.min_dim_index = find(info.sorted_indexes(1) == info.size, 1, 'last');
end

info.singleton_dimensions = info.size == 1;
info.total_singleton_dims = sum(info.singleton_dimensions);
info.has_singleton_dim = any(info.total_singleton_dims >= 1);
info.squeezable = info.has_singleton_dim && info.ndims > 2;
end
