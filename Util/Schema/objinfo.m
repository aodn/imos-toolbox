function [names, objlen, objsize, lens, sizes, otype, otypes] = objinfo(arg);
    % function [names, objlen, objsize, lens, sizes, otype, otypes] = objinfo(arg);
    %
    % A utility function to extract useful information about
    % the argument. This will walk through the indexes/fieldnames
    % along the first (root) level of a [cell,struct].
    %
    % Inputs:
    %
    % arg - any nonclass matlab type variable.
    %
    % Outputs:
    %
    % names - a cell with the fieldnames of the arg, if a struct.
    % objlen - a number with the length of the arg.
    % objsize - an array with the size of the arg.
    % lens - a cell with the objlen(s) of the items
    %        in arg if a [cell,struct]. Order follows
    %        fieldnames if a struct.
    %        Otherwise, `lens` is equal to `objlen`.
    %
    % sizes - a cell with the objsize(s) of the items
    %         in arg if a [cell,struct]. Order is the  same as above.
    %         Otherwise, `sizes` is equal to `objsize`.
    % otype - a string representation of the type of arg.
    % otypes - a cell with the otype of each item(s)
    %          in arg if a [cell/struct]
    %
    % Example:
    % >>> % simple case
    % >>> [names,objlen,objsize,lens,sizes,otype,otypes] = objinfo([1])
    % >>> assert(isequal(names,cell(0,0)))
    % >>> assert(objlen==1)
    % >>> assert(all(objsize==[1,1]))
    % >>> assert(lens==objsize)
    % >>> assert(all(sizes==objsize))
    % >>> assert(strcmp(otype,'double'))
    % >>> assert(strcmp(otypes{1},otype))
    % >>> % struct case
    % >>> [n,~,~,~,s,~,t] = objinfo(struct('x',0,'y',{{'a','b'}}))
    % >>> assert(isequal(n,fieldnames(x)))
    % >>> assert(isequal(s{1},1))
    % >>> assert(isequal(s{2},2))
    % >>> assert(isequal(t{1},'double'))
    % >>> assert(isequal(t{2},'cell'))
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

    if isstruct(arg),
        names = fields(arg);

        if length(names) == 0;
            names = cell(0, 0);
        end

        objsize = size(arg);
        objlen = length(names);
        lens = cell(0, 0);
        sizes = cell(0, 0);
        otype = 'struct';
        otypes = cell(0, 0);

        for k = 1:objlen
            name = names{k};
            data = arg.(name);
            lens{k} = length(data);
            sizes{k} = size(data);
            otypes{k} = whichtype(data);
        end

    else
        names = cell(0, 0);
        objsize = size(arg);
        objlen = length(arg);
        otypes = cell(0, 0);

        if iscell(arg),
            lens = cell(0, 0);
            sizes = cell(0, 0);
            otype = 'cell';

            for k = 1:objlen
                data = arg{k};
                lens{k} = length(data);
                sizes{k} = size(data);
                otypes{k} = whichtype(data);
            end

        else
            lens = length(arg);
            sizes = size(arg);
            otype = whichtype(arg);
            otypes{1} = otype;
        end

    end

end
