function value = bytecast(bytes, endianness, dataType, cpuEndianness)
%BYTECAST Cast a vector of bytes to the given type. 
%
% This function is used by the Nortek Paradopp and Teledyne workhorse ADCP
% parsers. Raw data files read in by both of these parsers store data in
% little endian.
% 
% Inputs:
%   bytes      - vector of bytes
%   endianness - endianness of the bytes - 'L' for little, 'B' for big.
%   dataType   - type to cast to, e.g. 'uint8', 'int64' etc.
%   cpuEndianness - endianness of the current CPU's bytes - 'L' for little, 'B' for big.
%
% Outputs:
%   value      - the given bytes cast to the given value.
%
% Author: Paul McCarthy <paul.mccarthy@csiro.au>
%         Charles James 2012 added call to swapbytes for opposite endianess
%         computers 
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

if cpuEndianness == endianness, 
    value = typecast(bytes, dataType);
else
    value = typecast(swapbytes(bytes), dataType);
end
  
value = double(value);
end