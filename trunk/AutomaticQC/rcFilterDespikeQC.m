function [data flags log] = rcFilterDespikeQC( sample_data, data, k, auto )
%RCFILTERDESPIKEQC Uses an RC filter technique to detect spikes in the given
%data.
%
% This function applies a spike detection filter based on the RC filter 
% despiking method described in:
%
%   Otnes RK & Enochson Loren, 1978 'Applied Time Series Analysis Volume 1:
%   Basic Techniques', pgs 95-96, Wiley.
%
% Inputs:
%   sample_data - struct containing the entire data set and dimension data.
%
%   data        - the vector of data to check.
%
%   k           - Index into the sample_data.variables vector.
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

error(nargchk(3, 4, nargin));
if ~isstruct(sample_data),        error('sample_data must be a struct'); end
if ~isvector(data),               error('data must be a vector');        end
if ~isscalar(k) || ~isnumeric(k), error('k must be a numeric scalar');   end

% auto logical in input to enable running under batch processing
if nargin<4, auto=false; end

k_param = str2double(...
  readProperty('k', fullfile('AutomaticQC', 'rcFilterDespikeQC.txt')));

% we need to modify the data set, so work with a copy
fdata = data;
lenData = length(data);

qcSet     = str2double(readProperty('toolbox.qc_set'));
goodFlag  = imosQCFlag('good',  qcSet, 'flag');
spikeFlag = imosQCFlag('spike', qcSet, 'flag');

log   = {};
flags = ones(lenData, 1)*goodFlag;

% remove the mean and run a mild high pass filter 
% over the data before applying spike detection
fdata = highPassFilter(fdata, 0.99);
fdata = fdata - mean(fdata);

% we need four data sets:
%   - lowpass(data)
%   - square(data)
%   - lowpass(square(data))
%   - square(lowpass(data))
%
% We use a fairly extreme low pass filter to reduce the 
% likelihood of insignificant spikes being flagged

lp   = lowPassFilter(fdata, 0.8);
sq   = fdata .* fdata;
lpsq = lowPassFilter(sq, 0.8);
sqlp = lp .* lp;

variance = lpsq(1:end-1) - sqlp(1:end-1);
% check that data is good
low_bound  = lp(1:end-1) - (k_param * (variance .^ 0.5));
high_bound = lp(1:end-1) + (k_param * (variance .^ 0.5));

% if bad, flag it
iLow = fdata(2:end) <= low_bound;
iHigh = fdata(2:end) >= high_bound;
iBad = iLow | iHigh;
iBad = [false; iBad];
    
flags(iBad) = spikeFlag;