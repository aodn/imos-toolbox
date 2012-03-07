function [data, flags, log] = tukey53HDespikeQC( sample_data, data, k, type, auto )
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
%   type        - dimensions/variables type to check in sample_data.
%
%   auto        - logical, run QC in batch mode
%
% Outputs:
%   data        - same as input.
%
%   flags       - Vector the same length as data, with flags for corresponding
%                 data which has been detected as spiked.
%
%   log         - Empty cell array.
%
% Author:       Paul McCarthy <paul.mccarthy@csiro.au>
% Contributor:  Guillaume Galibert <guillaume.galibert@utas.edu.au>
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

error(nargchk(4, 5, nargin));
if ~isstruct(sample_data),        error('sample_data must be a struct'); end
if ~isvector(data),               error('data must be a vector');        end
if ~isscalar(k) || ~isnumeric(k), error('k must be a numeric scalar');   end
if ~ischar(type),                 error('type must be a string');        end

% auto logical in input to enable running under batch processing
if nargin<5, auto=false; end

log   = {};
flags   = [];

if ~strcmp(type, 'variables'), return; end

k_param = str2double(...
  readProperty('k', fullfile('AutomaticQC', 'tukey53HDespikeQC.txt')));

% we need to modify the data set, so work with a copy
fdata = data;
lenData = length(data);

qcSet     = str2double(readProperty('toolbox.qc_set'));
rawFlag   = imosQCFlag('raw',   qcSet, 'flag');
goodFlag  = imosQCFlag('good',  qcSet, 'flag');
spikeFlag = imosQCFlag('spike', qcSet, 'flag');

flags = ones(lenData,1)*rawFlag;

% remove mean, and apply a mild high pass 
% filter before applying spike detection
fdata = highPassFilter(fdata, 0.99);
fdata = data - mean(fdata);

stddev = std(fdata);

lenU1 = lenData-4;
lenU2 = lenU1-2;
lenU3 = lenU2-1;

u1 = zeros(lenU1,1);
u2 = zeros(lenU2, 1);
u3 = zeros(lenU3, 1);

% calculate x', x'' and x'''
m = (3:lenData-2)';
mMinus2ToPlus2 = [m-2 m-1 m m+1 m+2];
u1(1:lenData-4) = median(fdata(mMinus2ToPlus2), 2);
clear mMinus2ToPlus2;

m = (2:lenU1-1)';
mMinus1ToPlus1 = [m-1 m m+1];
u2(1:lenU1-2) = median(u1(mMinus1ToPlus1), 2);
clear mMinus1ToPlus1;
u3(1:lenU2-2) = 0.25 *(u2(1:lenU2-2) + 2*u2(2:lenU2-1) + u2(3:lenU2));

% search the data for spikes
mydelta = abs(fdata(4:lenData-5) - u3(1:lenData-8));
iSpike = mydelta > k_param * stddev;
iNoSpike = mydelta <= k_param * stddev;
iSpike = [false; false; false; iSpike; false; false; false; false; false];
iNoSpike = [false; false; false; iNoSpike; false; false; false; false; false];

if any(iSpike)
    flags(iSpike) = spikeFlag;
end

if any(iNoSpike)
    flags(iNoSpike) = goodFlag;
end