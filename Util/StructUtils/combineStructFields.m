function [combined] = combineStructFields(varargin)
    % function [combined] = combineStructFields(varargin)
    %
    % This will combine or overwrite, in the argument order,
    % the different fieldnames in the argument structures.
    %
    % Inputs:
    %
    % any number of structures
    %
    % Outputs:
    %
    % combined - a structure with all fieldnames of the arguments combined
    %
    % Example:
    % % basic case
    % a = struct(); b=a;
    % a.x = 1;
    % b.x = 2;
    % b.y = 3;
    % combined = combineStructFields(a,b);
    % assert(combined.x==2);
    % assert(combined.y==3);
    %
    % % multi structure case
    % a = struct(); b=a; c=a;
    % a.x = 1;
    % b.x = 2;
    % b(2).x = 3;
    % b(3).x = 4;
    % c.x = 3;
    % c(2).x = 4;
    % c(3).x = 5;
    % combined = combineStructFields(a,b,c);
    % assert(isequal(size(combined),[1,3]))
    % assert(combined(1).x==3)
    % assert(combined(2).x==4)
    % assert(combined(3).x==5)
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

    for n = 1:nargin
        arg = varargin{n};
        snames = fieldnames(arg);
        for s = 1:numel(arg)
            for k = 1:length(snames)
                name = snames{k};
                combined(s).(name) = arg(s).(name);
            end
        end
    end

end
