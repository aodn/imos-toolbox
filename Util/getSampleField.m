function fields = getSampleField(fcell, fname)
%function var = getSampleField(fcell,fname)
%
% Extract all named fields from a cell of toolbox field structs.
%
% Inputs:
%   fcell - a cell of named field structs (variables,dimensions)
%   fname - the field name (e.g. 'name')
%
% Outputs:
%   fields  - the values of every field (fcell{1:end}.(fname))
%
%
% author: hugo.oliveira@utas.edu.au
%
%

%
% Copyright (C) 2020, Australian Ocean Data Network (AODN) and Integrated
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
if ~iscell(fcell), error('fcell must be a cell array'); end
if ~ischar(fname), error('fname must be a string'); end

fields = cell(1, length(fcell));

for k = 1:length(fcell)

    try
        fields{k} = fcell{k}.(fname);
    catch
        continue
    end

end

end
