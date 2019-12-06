function result = executeQuery( table, field, value)
%EXECUTEQUERY Wrapper around Java DDB interface, allowing queries to the DDB
% pass query to DDB database or CSV file Query
%
% Inputs:
%   table  - The table to query.
%
%   field  - Name of field on which to restrict query. If passed in as an 
%            empty matrix, the entire table is returned. 
%
%   value  - Value of field on which to restrict query. 
%
% Outputs:
%   result - Vector of structs.
%
% See Also executeDDBQuery and executeCSVQuery
%
%
% Author:       Peter Jansen <peter.jansen@csiro.au>
%

%
% Copyright (C) 2017, Australian Ocean Data Network (AODN) and Integrated 
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

isDatabaseCSV = false;
ddb = readProperty('toolbox.ddb');
if isdir(ddb)
    isDatabaseCSV = true;
end
if isDatabaseCSV
    result = executeCSVQuery(table, field,   value);
else
    result = executeDDBQuery(table, field,   value);
end
  
end

