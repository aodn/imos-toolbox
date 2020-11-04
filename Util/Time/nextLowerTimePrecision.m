function [lower_prec] = nextLowerTimePrecision(prec)
% function [lower_prec] = nextLowerTimePrecision(prec)
%
% Return the next lower time precision
%
% Inputs:
%
% prec - a precision string
%
% Outputs:
%
% lower_prec - next lower precision string
%
% Example:
%
% prec = 'microsecond';
% [lower_prec] = nextLowerTimePrecision(prec);
% assert(strcmp(lower_prec,'milisecond'))
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
allprecision = {'day', 'hour', 'minute', 'second', 'milisecond', 'microsecond'};
ind = find(contains(allprecision, prec));

if ~isempty(ind)

    if ind == 1
        lower_prec = allprecision{ind};
    else
        lower_prec = allprecision{ind - 1};
    end

else
    error('%s not supported', prec)
end
