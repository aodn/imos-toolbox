function [uprec,lprec] = precisionBounds(time)
% function [uprec,lprec] = getPrecision(time)
%
% Calculate the precision bounds strings given
% a singleton datenum array.
%
%
% Inputs:
%
% time - a singleton datenum vector array
%
% Outputs:
%
% uprec - the upper bound precision string
% lprec - the lower bound precision string
%
%
% Example:
%
% [uprec,lprec] = precisionBounds(1e-6/86400);
% assert(strcmpi(uprec,'microsecond'))
% assert(strcmpi(lprec,'microsecond'))
%
% [uprec,lprec] = precisionBounds(30/86400);
% assert(strcmpi(uprec,'second'))
% assert(strcmpi(lprec,'milisecond'))
%
% [uprec,lprec] = precisionBounds(31/86400);
% assert(strcmpi(uprec,'minute'))
% assert(strcmpi(lprec,'second'))
%
% [uprec,lprec] = precisionBounds(1831/86400);
% assert(strcmpi(uprec,'hour'))
% assert(strcmpi(lprec,'minute'))
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
if length(time)>1
	error('Time must be singleton')
end

allprec = {'day','hour','minute','second','milisecond','microsecond'};
n = length(allprec);
vals = zeros(1,n);
for k = 1:length(allprec)
	vals(:,k) = 1/stepsInDay(allprec{k});
end

pdiff=timeQuantisation(abs(vals-time),'microsecond');
ubound=find(pdiff==min(pdiff),1,'last');
lbound=min(ubound+1,n);

uprec = allprec{ubound};
lprec = allprec{lbound};
end
