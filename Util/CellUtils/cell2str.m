function [cstr] = cell2str(xcell, sep)
    % function [cstr] = cell2str(xcell,sep)
    %
    % Convert all items in a cell to string and concatenate
    % then with a separator, ignoring non-numeric entries.
    %
    % Inputs:
    %
    % xcell - a cell
    % sep - a string separator - default to ','
    %
    % Outputs:
    %
    % cstr - a string of all strings and numerics separated by
    %        `sep`.
    %
    % Example:
    % cstr = cell2str({1,'string'})
    % assert(strcmp(cstr,'1,string'))
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

    if nargin < 2
        sep = ',';
    end

    if ~ischar(sep)
        error('second argument `sep` must be string');
    end

    cn = numel(xcell);
    cstr = '';
    ksep = '';

    for k = 1:cn
        data = xcell{k};

        if isnumeric(data)
            cstr = [cstr ksep num2str(data)];
        elseif ischar(data)
            cstr = [cstr ksep data];
        else
            swarning('Ignoring entry %d in first argument', k);
        end

        ksep = sep;
    end

end
