function [names, objlen, objsize, lens, sizes, otype, otypes] = objinfo(arg1);
    % function [names, objlen, objsize, lens, sizes, otype, otypes] = objinfo(arg1);
    % Extract useful information about the arg1.
    % 
    % `arg1` - any matlab type variable
    % <->
    % `names` - the fieldnames of the arg, if any
    % `objlen` - the length of the arg
    % `objsize` - the size of the arg
    % `lens` - the length(s) of the items in arg [cell/struct]
    % `sizes` - the size(s) of the items in arg [cell/struct]
    % `otype` - the type of arg
    % `otypes` - the types(s0 of the items in arg [cell/struct]
    %
    % author: hugo.oliveira@utas.edu.au
    %
    if isstruct(arg1),
        names = fields(arg1);
        if length(names) == 0;
            names = cell(0,0);
        end
        objsize = size(arg1);
        objlen = length(names);
        lens = cell(0,0);
        sizes = cell(0,0);
        otype = 'struct';
        otypes = cell(0,0);


        for k = 1:objlen
            name = names{k};
            data = arg1.(name);
            lens{k} = length(data);
            sizes{k} = size(data);
            otypes{k} = whichtype(data);
        end

    else
        names = cell(0,0);
        objsize = size(arg1);
        objlen = length(arg1);
        otypes = cell(0,0);

        if iscell(arg1),
            lens = cell(0,0);
            sizes = cell(0,0);
            otype = 'cell';
            for k = 1:objlen
                data = arg1{k};
                lens{k} = length(data);
                sizes{k} = size(data);
                otypes{k} = whichtype(data);
            end

        else
            lens = length(arg1);
            sizes = size(arg1);
            otype = whichtype(arg1);
        end

    end

end
