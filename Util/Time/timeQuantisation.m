function [tq] = timeQuantisation(time, prec)
% function [tq] = timeQuantisation(time, prec)
%
% Quantize time by a certain precision.
%
% Inputs:
%
% time - a datenum time array - i.e units in days
% prec - the precision string
%
% Outputs:
%
% tq - quantize time
%
% Example:
%
% [tq] = timeQuantisation([1,2,3,4+0.001/86400],'microsecond');
% assert(isequal(tq,[1,2,3,4+0.001/86400]))
% [tq] = timeQuantisation([1,2,3,4+0.001/86400],'milisecond');
% assert(isequal(tq,[1,2,3,4+0.001/86400]))
% [tq] = timeQuantisation([1,2,3,4+0.001/86400],'second');
% assert(isequal(tq,[1,2,3,4]))
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
%

step = stepsInDay(prec);
tq = uniformQuantise(time, 1 ./ step);

end
