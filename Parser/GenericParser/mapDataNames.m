function [data] = mapDataNames(procdata, map_rules, header_info)
% function data = mapDataNames(procdata, map_rules, header_info)
%
% Map variables names according to rules and the header_information
%
% Input:
%
% procdata - the processed data.
% map_rules - the mapping rules.
% header_info - the information from the headers
%                 Default: empty struct if not provided.
%
% Output:
%
% data - a simple structure where the fieldnames are the
%          variables names.
%
% Example:
% % Simplest case - just simple mapping
% sdata.procdata.date = [1,2,3];
% map_rules.date = @(x) 'TIME';
% [data] = mapDataNames(sdata.procdata,map_rules);
% assert(isequal(data.TIME,[1,2,3]));
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
    header_info = struct();
end

rulenames = fieldnames(map_rules);
nr = numel(rulenames);
datanames = fieldnames(procdata);
data = struct();

for k = 1:nr
    oldname = rulenames{k};

    if inCell(datanames, oldname)
        newname = matlab.lang.makeValidName(map_rules.(oldname)(header_info));

        if isfield(data, newname)
            newname = resolveString(fieldnames(data), newname);
        end

        data.(newname) = procdata.(oldname);
    end

end

end
