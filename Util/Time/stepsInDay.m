function [steps] = stepsInDay(tunit)
% function [steps] = timeQuantisationStep(prec)
%
% How many steps are defined in day, for a given time unit.
%
%
% Inputs:
%
% tunit - string representing a time/precision unit.
%
% Outputs:
%
% steps - a floating point number
%
% Example:
%
% [steps] = stepsInDay('minute');
% assert(isequal(steps,1440))
%
%
% author: hugo.oliveira@utas.edu.au
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
%
% You should have received a copy of the GNU General Public License
% along with this program.
% If not, see <https://www.gnu.org/licenses/gpl-3.0.en.html>.

switch tunit
    case 'microsecond'
        steps = 8.64e10;
    case 'milisecond'
        steps = 8.64e7;
    case 'second'
        steps = 8.64e4;
    case 'minute'
        steps = 1440;
    case 'hour'
        steps = 24;
    case 'day'
        steps = 1;
    otherwise
        error('%s not supported',prec)
end
