function [fcell] = fields2cell(s, names)
    % function [fcell] = fields2cell(s,names)
    %
    % extract pre-defined field from a structure
    % into a cell.
    %
    % Inputs:
    %
    % s - a structure
    % names - a string or a cell of strings.
    %
    % Outputs:
    %
    % fcell - a cell with s.(names{n}) fields.
    %
    % Examples:
    % s = struct('x',1,'y',2,'z',3)
    % [fcell] = fields2cell(s,{'z','y','x'})
    % assert(isequal(fcell,{3,2,1}))
    %
    % author: hugo.oliveira@utas.edu.au
    %

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

    % You should have received a copy of the GNU General Public License
    % along with this program.
    % If not, see <https://www.gnu.org/licenses/gpl-3.0.en.html>.
    %

    narginchk(2, 2);
    invalid_names = ~ischar(names) && ~iscellstr(names) && ~isstring(names);

    if invalid_names
        error('Second argument must be string or cell of strings')
    end

    snames = fieldnames(s);
    fcell = cell(1, 1);

    for k = 1:numel(names)
        fname = names{k};

        if inCell(snames, fname)
            fcell{k} = s.(fname);
        else
            fcell{k} = {};
        end

    end

end
