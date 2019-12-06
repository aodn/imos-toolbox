function [combined] = combineStructFields(varargin)
    % function [combined] = combineStructFields(varargin)
    %
    % This will combine or overwrite, in the argument order,
    % the different fieldnames in the argument structures.
    %
    % Inputs:

    % any number of structures
    %
    % Outputs:
    %
    % combined - a structure with all fieldnames of the arguments combined
    %
    % Example:
    % a.x = 1;
    % b.x = 2;
    % b.y = 3;
    % combined = combineStructFields(a,b);
    % assert(combined.x == 2);
    % assert(combined.y == 3);
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

    % You should have received a copy of the GNU General Public License
    % along with this program.
    % If not, see <https://www.gnu.org/licenses/gpl-3.0.en.html>.
    %

    combined = struct();

    for k = 1:nargin
        s = varargin{k};
        snames = fieldnames(s);

        for kk = 1:length(snames)
            name = snames{kk};
            combined.(name) = s.(name);
        end

    end

end
