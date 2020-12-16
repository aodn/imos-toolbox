function [mcell] = squashCells(varargin)
% function [mcell] = squashCells(varargin)
%
% Squash an arbitrary number of cell arguments
% sequentially into a cell of alternate items
% such as:
%
% ∀ k Z-* mcell(m+1:k*m) = {varargin{k*m/m}{k*m/m},...}
%
% Inputs:
%
% varargin - arbitrary cell arguments
%
% Outputs:
%
% mcell - a cell with all arguments squashed into one.
%
% Example:
%
% %typical usage
% c1={'A','B','C','D','E'};
% c2={1,2,3};
% c3={'F','G'};
% mcell = squashCells(c1,c2,c3);
% assert(isequal(mcell([3,6]),c3))
% assert(isequal(mcell([2,5,8]),c2))
% assert(isequal(mcell([1,4,7,9,10]),c1))
%
% %short to large cells
% c1={'a'};
% c2={'b','d','f'};
% c3={'c','e','g','h','i','j','k'};
% mcell = squashCells(c1,c2,c3);
% assert(isequal(mcell,num2cell('abcdefghijk')))
%
%
% %empty is ignored.
% [mcell] = squashCells({1,2,3},{},{'A','B','C'});
% assert(isequal(mcell,{1,'A',2,'B',3,'C'}));
%
% author: hugo.oliveira@utas.edu.au
%
if any(~cellfun(@iscell,varargin))
    error('%s: Cannot merge non cell objects',mfilename)
end

fcells = ~cellfun(@isempty,varargin);
varargin = varargin(fcells);

totalgroups = numel(varargin);
sizes = cellfun(@numel, varargin);

mcell = cell(1, sum(sizes));
inds = cell(1, totalgroups);

for k = 1:totalgroups
    inds{k} = zeros(1, sizes(k));
end

ngroups = totalgroups;
gsizes = col(num2cell(sizes));
slots = gsizes;
group_index_store = num2cell(col(1:ngroups));
k = 1;
group = find([group_index_store{:}] == k, 1);

while ~isempty(group)
    if slots{group} ~= 0
        slots{group} = slots{group} - 1;
        index_in_group = gsizes{group} - slots{group};
        inds{group}(index_in_group) = k;
        group_index_store{group} = group_index_store{group} + ngroups;
        k = k + 1;
        group = find([group_index_store{:}] == k, 1);
    else
        group_index_store = num2cell([group_index_store{:}] - 1);
        ngroups = ngroups - 1;
        group = find([group_index_store{:}] == k, 1);
    end
end

for k = 1:totalgroups
    mcell(inds{k}) = varargin{k};
end

end
