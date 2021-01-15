function [degC] = toCelsius(array, units)
% function degC = toCelsius funcname(celsius)
%
% Convert to degree Celsius
%
% Inputs:
%
% array - array of temperature values
% units - unit string one of {'celsius','kelvin','fahr','fahrenheit'}
%
% Outputs:
%
% degC - array in degree celsius
%
% Example:
%
% degC = toCelsius([300.15],'kelvin');
% assert(round(degC)==27);
% degC = toCelsius([27],'celsius');
% assert(round(degC)==27);
% degC = toCelsius([80.6],'fahr');
% assert(round(degC)==27);
%
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

from_kelvin = @(x) x - 273.15;
from_fahr = @(x) (x - 32) .* 5/9;

if strcmpi(units, 'kelvin')
    degC = from_kelvin(array);
elseif strcmpi(units, 'celsius')
    degC = array;
elseif strcmpi(units, 'fahr') || strcmpi(units, 'fahrenheit')
    degC = from_fahr(array);
else
    error('Invalid units %s', units);
end

end
