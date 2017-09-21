function value = updateIfEmpty(testValue, emptyValue, notEmptyValue)
%UPDATEIFEMPTY Return emptyValue if testValue is empty, otherwise return
%testValue or notEmptyValue if defined. Useful in template file to perform
%some IF statements
%
%
% Inputs:
%
%   testValue       - object checked if empty
%   emptyValue      - object to be returned if testValue is empty
%   notEmptyValue   - object to be returned if testValue is not empty
%
% Outputs:
%
%   value           - object returned.
%
% Author: Guillaume Galibert <guillaume.galibert@utas.edu.au>
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
  narginchk(2,3);

  if nargin == 2, notEmptyValue = testValue; end
  
  if isempty(testValue)
      value = emptyValue;
  else
      value = notEmptyValue;
  end
end
