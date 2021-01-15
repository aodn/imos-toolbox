function [l, r] = validBounds(flags, lmin)
% function [l,r] = validBounds(flags)
%
% Return the first (left) and last (right) valid flag
% indexes that are contiguous by lmin amount.
%
% Useful for removing the beginning and ending of timeseries
% that are filled with bad data.
%
%
% Inputs:
%
% flags - int8 QC flags vector.
% lmin - the minimum length for valid contiguous section
%        in each side (data(l:l+lmin), data(r-lmin:r)).
%
% Outputs:
%
% l - the first contiguous left most index of valid data.
% r - the first contiguous right most index of valid data.
%
% Example:
% flags = int8([4,4,4,4,0,0,0,0]);
% [l,r] = validBounds(flags);
% assert(l==5)
% assert(r==8)
%
% flags = int8([0,0,0,0,4,4,4,4]);
% [l,r] = validBounds(flags);
% assert(l==1)
% assert(r==4)
%
% flags = int8([4,4,4,4,0,0,0,0,4,0,0,0,0,4,4,4,4]);
% [l,r] = validBounds(flags);
% assert(l==5)
% assert(r==13)
%
% flags = int8([4,4,4,4,4,0,4,4,4,4,4]);
% [l,r] = validBounds(flags,1);
% assert(l==6)
% assert(r==6)
% [l,r] = validBounds(flags,2);
% assert(isempty(l))
% assert(isempty(r))
%
% flags = int8([4,4,0,0,4,4,4,0,0,4,0,4,4,4]);
% [l,r] = validBounds(flags,2);
% assert(l==3)
% assert(r==9)
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
if nargin < 2
    dmin = 0;
else

    if isempty(flags)
        error("flags argument empty")
    end

    dmin = max(0, lmin - 1);
end

l = [];
r = [];

valid = find(logical((flags == 0) + (flags == 1) + (flags == 2)));

for k = 1:length(valid)
    lstart = valid(k);
    lend = lstart + dmin;

    if ismember(lstart:lend, valid)
        l = lstart;
        break
    end

end

if isempty(l)
    return
end

for k = max(valid):-1:l
    rend = k;
    rstart = rend - dmin;

    if ismember(rstart:rend, valid)
        r = rend;
        break
    end

end

end
