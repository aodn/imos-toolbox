function value = bytecast(bytes, endianness, dataType)
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
%
% Outputs:
%   value      - the given bytes cast to the given value.
%
% Author: Paul McCarthy <paul.mccarthy@csiro.au>
%         Charles James 2012 added call to swapbytes for opposite endianess
%         computers 
%
%
% Copyright (c) 2009, eMarine Information Infrastructure (eMII) and Integrated 
% Marine Observing System (IMOS).
% All rights reserved.
% 
% Redistribution and use in source and binary forms, with or without 
% modification, are permitted provided that the following conditions are met:
% 
%     * Redistributions of source code must retain the above copyright notice, 
%       this list of conditions and the following disclaimer.
%     * Redistributions in binary form must reproduce the above copyright 
%       notice, this list of conditions and the following disclaimer in the 
%       documentation and/or other materials provided with the distribution.
%     * Neither the name of the eMII/IMOS nor the names of its contributors 
%       may be used to endorse or promote products derived from this software 
%       without specific prior written permission.
% 
% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
% AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
% IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
% ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE 
% LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
% CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
% SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
% INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
% CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
% ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
% POSSIBILITY OF SUCH DAMAGE.
%

[~, ~, cpuEndianness] = computer;
if cpuEndianness == endianness, 
    value = typecast(bytes, dataType);
else
    value = typecast(swapbytes(bytes), dataType);
end
  
value = double(value);
end