function [data, flags, log] = wqmBurstFilterMedianQC( sample_data, data, k, auto )
%WQMBURSTFILTERMEDIAN Flags all values within a burts which are not between 
% median +/- 2*variability_around_median. Median and variability are computed
% for each burst.
%
%
% Inputs:
%   sample_data - struct containing the data set.
%
%   data        - the vector of data to check.
%
%   k           - Index into the sample_data variable vector.
%
%   auto        - logical, run QC in batch mode
%
% Outputs:
%   data        - same as input.
%
%   flags       - Vector the same length as data, with flags
%
%   log         - Empty cell array.
%
% Author:       Guillaume Galibert <guillaume.galibert@utas.edu.au>
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

qcSet    = str2double(readProperty('toolbox.qc_set'));
rawFlag = imosQCFlag('raw',  qcSet, 'flag');
goodFlag = imosQCFlag('good',  qcSet, 'flag');
rangeFlag = imosQCFlag('bound', qcSet, 'flag');
spikeFlag = imosQCFlag('spike', qcSet, 'flag');

lenData = length(data);

log   = {};

% initially all data is good
flags = ones(lenData, 1)*goodFlag;

% Let's find each start of bursts
dt = [0; diff(sample_data.dimensions{1}.data)];
iBurst = [1; find(dt>(1/24/60)); length(sample_data.dimensions{1}.data)+1];

% let's read data burst by burst
for i=1:length(iBurst)-1
    dataBurst = data(iBurst(i):iBurst(i+1)-1);
    flagBurst = flags(iBurst(i):iBurst(i+1)-1);
    
    %Do some quick and dirty tidy up QA/QC
    switch sample_data.variables{k}.name
        case {'TEMP' 'CNDC'}
            flagBurst(dataBurst==0 | dataBurst>30) = rangeFlag;
        case {'PRES' 'PRES_REL'}
            flagBurst(dataBurst==0 | dataBurst>150) = rangeFlag;
        case 'PSAL'
            flagBurst(dataBurst==99 | dataBurst>40 | dataBurst<30) = rangeFlag;
        case 'DOXY'
            flagBurst(dataBurst<0) = rangeFlag;
        case {'FLU2' 'TURB'}
            % Let's compute mean / median
            iGood = (flagBurst == goodFlag);
            dataBurstGood = dataBurst(iGood);
            dataBurstMedian = median(dataBurstGood)';
            
            % Let's compute variability
            stdDevMedian = sqrt(mean((dataBurstGood - dataBurstMedian).^2));
            
            % Flag outliers using previously computed variability
            coef = 2;
            flagBurst(dataBurst > (dataBurstMedian + coef*stdDevMedian)) = spikeFlag;
            flagBurst(dataBurst < (dataBurstMedian - coef*stdDevMedian)) = spikeFlag;
        otherwise
            flagBurst(:) = rawFlag;
    end
    
    flags(iBurst(i):iBurst(i+1)-1) = flagBurst;
end