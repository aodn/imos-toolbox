function [is_valid, emsg] = validate(a, b, stopfirst);
    % function [is_valid, emsg] = validate(a, b);
    %
    % Validate a against b.
    % The validation include type,size,length,name space, name match, and content.
    %
    % Inputs:
    %
    % a - any type input
    % b - any type input
    % stopfirst - a boolean to stop at first error
    %             Default: true.
    %
    % Outputs:
    %
    % is_valid - a boolean with result of validation
    % emsg - a string with errors
    %
    % Example:
    % >>> a = struct('x',1,'y',2)
    % >>> b = struct('x',1,'y',2,'z',3)
    % >>> [is_valid,emsg] = validate(a,b,false)
    % >>> assert(~is_valid)
    % >>> assert(contains(emsg,'Fieldnames number mismatch'))
    % >>> assert(contains(emsg,'Content mismatch'))
    % >>> [is_valid,emsg] = validate(a,b,true)
    % >>> assert(~contains(emsg,'Content mismatch'))
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

    if nargin<3
        stopfirst=true;
    end

    [is_diff, emsg] = treeDiff(a, b, stopfirst);

    if is_diff,
        is_valid = false;
    else
        is_valid = true;
    end

end
