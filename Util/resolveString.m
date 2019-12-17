function [newname] = resolveString(entity, name, efunc)
% function newname = resolveString(entity,name,efunc)
%
% Resolve a name string to a newname if the name is already
% define in entity.
%
% Resolution is done with a underscore followed by an integer.
%
% Inputs:
%
% entity - a matlab entity
%          default type: a cell array.
% name - a string
% efunc - a function to inspect the entity with `name` [OPTIONAL].
%         default: inCell.
%
% Outputs:
%
% newname - a resolved name
%           newname == name if `name` not in ocell
%           newname == name_(n) if 'name' or name_x present.
%
% Example:
%
% newname = resolveString({'abc'},'abc');
% assert(strcmp(newname,'abc_2'));
%
% author: hugo.oliveira@utas.edu.au
%

% Copyright (C) 2019, Australian Ocean Data Network (AODN) and Integrated
% Marine Observing System (IMOS).
%
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation version 3 of the License.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with this program.
% If not, see <https://www.gnu.org/licenses/gpl-3.0.en.html>.
%
narginchk(2, 3)

if nargin < 3
    efunc = @inCell;
end

if ~efunc(entity, name)
    newname = name;
    return
end

nmax = 20; % completely arbitrary

for n = 2:nmax
    iname = [name '_' num2str(n)];

    if ~efunc(entity, iname)
        newname = iname;
        return;
    end

end

error('Too many variables with the same name %s', name)
end
