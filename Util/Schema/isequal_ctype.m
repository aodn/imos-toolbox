function [bool] = isequal_ctype(a, b),
    % function [bool] = isequal_ctype(a,b),
    %
    % An enhanced isequal that compare type and content.
    % This will not compare types of individual [cell,struct]
    % [indexes,fieldnames]. For this, use treeDiff.
    %
    % Inputs:
    %
    % a - any non-class matlab variable.
    % b - any non-class matlab variable.
    %
    % Outputs:
    %
    % bool - a boolean number representing if the type and content of
    %        a and b are the same.
    %
    % Example:
    % >>> a = 0,b=false;
    % >>> assert(~isequal_ctype(a,b))
    % >>> a = {0,int8(1),single(2),3.}, b = {false,int8(1),single(2),3.}
    % >>> assert(isequal_ctype(a,b))
    % >>> b{4} = 4.
    % >>> assert(~isequal_ctype(a,b))
    % >>> %matlab caveat - use treeDiff.m instead
    % >>> a = struct('x',false), b = struct('x',0)
    % >>> assert(isequal_ctype(a,b))
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

    atype = whichtype(a);
    btype = whichtype(b);
    bool = isequal(atype, btype);

    if bool,
        bool = isequaln(a, b);
    end

end
