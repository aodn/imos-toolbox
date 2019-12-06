function [is_valid, emsg] = validateType(a, b, stopfirst);
    % function [is_valid, emsg] = validateType(a, b, stopfirst);
    %
    % Validate, recursively, the types of `a` and `b`.
    %
    % Inputs:
    %
    % a - any non-class matlab variable
    % b - any non-class matlab variable
    % stopfirst - boolean to stop at first error
    %
    % Outputs:
    %
    % is_valid - bool with result
    % emsg - str with errors
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

    if nargin < 3,
        stopfirst = true;
    end

    atype = createTree(a);
    btype = createTree(b);
    [is_diff, emsg] = treeDiff(atype, btype, stopfirst);

    if is_diff,
        is_valid = false;
    else
        is_valid = true;
    end

end
