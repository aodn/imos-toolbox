function [flat_struct] = nc_flat(ncstruct, keep_empty)
% function [flat_struct] = nc_flat(ncstruct, keep_empty)
%
% Flat the ncinfo structure, recursively,
% into a flattened form with named/dictionary like access.
% Prunning is also allowed.
%
% Inputs:
%
% ncinfo_struct [struct] - a ncinfo like structure
% keep_empty [bool] - flag to keep or prune empty entries.
%
% Outputs:
%
%
% Example:
%
% % basic
% ncstruct = struct('Filename','x.nc','Name','/','Dimensions',[],'Variables',[]);
% ncstruct.Attributes = struct('Name','one','Value',1);
% ncstruct.Attributes(2) = struct('Name','two','Value',2);
% ncstruct.Groups = [];
% ncstruct.Format = 'netcdf4';
% [flat_struct] = nc_flat(ncstruct,true);
% assert(flat_struct.Attributes.one==1)
% assert(flat_struct.Attributes.two==2)
% assert(isstruct(flat_struct.Dimensions))
% assert(isempty(flat_struct.Dimensions))
%
% % recursion
% ncstruct.Groups = rmfield(ncstruct,{'Filename','Format'});
% ncstruct.Groups.Name = 'Group_A';
% ncstruct.Groups.Attributes(1).Name = 'three';
% ncstruct.Groups.Attributes(1).Value = 3;
% ncstruct.Groups(2) = rmfield(ncstruct,{'Filename','Format'});
% ncstruct.Groups(2).Name = 'Group_B';
% ncstruct.Groups(2).Attributes(1).Name = 'four';
% ncstruct.Groups(2).Attributes(1).Value = 4;
% [flat_struct] = nc_flat(ncstruct);
% assert(flat_struct.Attributes.one==1)
% assert(flat_struct.Attributes.two==2)
% assert(flat_struct.Groups.Group_A.Attributes.three==3)
% assert(flat_struct.Groups.Group_B.Attributes.four==4)
%
% % prunning
% [flat_struct] = nc_flat(ncstruct,false);
% assert(isequal(fieldnames(flat_struct),{'Filename','Attributes','Groups','Format'}'));
%
%
% author: hugo.oliveira@utas.edu.au
%
narginchk(1, 2)

if nargin < 2
    keep_empty = true;
end

names = {ncstruct.Name}';
ncstruct = rmfield(ncstruct, 'Name');
fnames = fieldnames(ncstruct);

root_fields = {'Filename', 'Dimensions', 'Variables', 'Attributes', 'Groups', 'Format'};
dims_fields = {'Length', 'Unlimited'};
vars_fields = {'Dimensions', 'Size', 'Datatype', 'Attributes'};
attrs_fields = {'Value'};
group_fields = {'Dimensions', 'Variables', 'Attributes', 'Groups'};

at_root_level = all(contains(root_fields, fnames));
at_dims_level = all(contains(dims_fields, fnames));
at_vars_level = all(contains(vars_fields, fnames));
at_attrs_level = all(contains(attrs_fields, fnames));
at_group_level = all(contains(fnames, group_fields));

if at_attrs_level

    flat_struct = cell2struct({ncstruct.Value}, names, 2);

elseif at_dims_level

    flat_struct = cell2struct(num2cell(ncstruct), names', 2);

elseif at_vars_level
    for k = 1:numel(names)
        flat_struct.(names{k}) = clean_prune(ncstruct(k), {'Attributes', 'Dimensions'}, keep_empty);
    end

elseif at_group_level

    for k = 1:numel(names)
        flat_struct.(names{k}) = clean_prune(ncstruct(k), {'Attributes', 'Dimensions', 'Variables', 'Groups'}, keep_empty);
    end

elseif at_root_level
    for k = 1:numel(names)
        flat_struct = clean_prune(ncstruct(k), {'Attributes', 'Dimensions', 'Variables', 'Groups'}, keep_empty);
    end

end

end

function [s] = clean_prune(s, fnames, keep_flag)
%
% Try to prune/flat the fieldnames of a ncinfo structure.
%
% If keep_flag is true and prune fails,
% the fieldname is kept as an empty struct.
% Otherwise, the fieldname is removed
% from the structure.
%

narginchk(3, 3);

total = numel(fnames);
remove_list = cell(1, total);

c = 0;

for n = 1:total
    name = fnames{n};

    try
        s.(name) = nc_flat(s.(name), keep_flag);
    catch

        if keep_flag
            s.(name) = struct([]);
        else
            c = c + 1;
            remove_list{c} = name;
        end

    end

end

unflat_fields = c>0;
if unflat_fields
    remove_list = remove_list(1:c);
    need_removal = any(contains(remove_list,fieldnames(s)));
    if need_removal
        s = rmfield(s, remove_list);
    end
end

end
