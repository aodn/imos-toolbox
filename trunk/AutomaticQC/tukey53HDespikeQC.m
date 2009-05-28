function [data, flags, log] = ...
tukey53HDespikeQC( sample_data, data, k, varargin )
%TUKEY53HDESPIKEQC Detects spikes in the given data using the Tukey 53H method.
%
% Detects spikes in the given data using the Tukey 53H method, as described in
% 
%   Otnes RK & Enochson Loren, 1978 'Applied Time Series Analysis Volume 1:
%   Basic Techniques', pgs 96-97, Wiley.:
%
%   Goring DG & Nikora VI 2002 'Despiking Acoustic Doppler Velocimeter Data',
%   Journal of Hydraulic Engineering, January 2002, vol 128, issue 1, 
%   pp 117-126.
%
% Inputs:
%   sample_data - struct containing the entire data set and dimension data.
%
%   data        - the vector of data to check.
%
%   k           - Index into the sample_data.variables vector.
%
%   'k_param'   - Filter threshold (see the text). If not provided, a default 
%                 value of 1.5 is used.
%
% Outputs:
%   data        - same as input.
%
%   flags       - Vector the same length as data, with flags for corresponding
%                 data which has been detected as spiked.
%
%   log         - Empty cell array.
%
% Author: Paul McCarthy <paul.mccarthy@csiro.au>
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

error(nargchk(3, 5, nargin));
if ~isstruct(sample_data),        error('sample_data must be a struct'); end
if ~isvector(data),               error('data must be a vector');        end
if ~isscalar(k) || ~isnumeric(k), error('k must be a numeric scalar');   end

p = inputParser;
p.addOptional('k_param', 1.5, @isnumeric);

p.parse(varargin{:});

k_param = p.Results.k_param;

% we need to modify the data set, so work with a copy
fdata = data;

qc_set = str2num(readToolboxProperty('toolbox.qc_set'));
goodFlag  = imosQCFlag('good',  qc_set, 'flag');
spikeFlag = imosQCFlag('spike', qc_set, 'flag');

flags    = zeros(length(fdata), 1);
flags(:) = goodFlag;
log      = {};

% remove mean, and apply a mild high pass 
% filter before applying spike detection
fdata = highPassFilter(fdata, 0.99);
fdata = data - mean(fdata);

stddev = std(fdata);

u1 = zeros(length(fdata)-4,1);
u2 = zeros(length(u1)-2, 1);
u3 = zeros(length(u2)-1, 1);

% calculate x', x'' and x'''
% could be pipelined, but i'm lazy, and it's not too slow
for m = 3:(length(fdata)-2), u1(m-2) = median(fdata(m-2:m+2));              end
for m = 2:(length(u1)-1),    u2(m-1) = median(u1(m-1:m+1));                 end
for m = 2:(length(u2)-1),    u3(m-1) = 0.25 *(u2(m-1) + 2*u2(m) + u2(m+1)); end



% search the data for spikes
for m = 4:(length(fdata)-5)
  
  delta = abs(fdata(m) - u3(m-3));
  if delta > k_param * stddev, flags(m) = spikeFlag; end;
  
end
