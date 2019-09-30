function value = updateIf(testValue, trueValue, falseValue)
%UPDATEIF Return trueValue if testValue is true, otherwise return
%falseValue. Useful in template file to perform some IF statements
%
%
% Inputs:
%
%   testValue       - object checked if true
%   trueValue       - object to be returned if testValue is true
%   falseValue      - object to be returned if testValue is false
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
  narginchk(3,3);
  
  if testValue
      value = trueValue;
  else
      value = falseValue;
  end
end
