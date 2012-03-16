function [data, flags, log] = imosGradientQC( sample_data, data, k, type, auto )
%IMOSGRADIENTQC Flags consecutive TEMP or PSAL values with gradient > threshold.
%
% Gradient test which finds and flags any consecutive data which gradient
% is > threshold
%
% Threshold = 6 for temperature when pressure < 500 dbar
% Threshold = 2 for temperature when pressure >= 500 dbar
%
% Threshold = 0.9 for salinity when pressure < 500 dbar
% Threshold = 0.3 for salinity when pressure >= 500 dbar
%
% Threshold = 3 for pressure/depth
%
% by default we assume all IMOS moorings are in shallow water < 500m
%
% Inputs:
%   sample_data - struct containing the data set.
%
%   data        - the vector of data to check.
%
%   k           - Index into the sample_data variable vector.
%
%   type        - dimensions/variables type to check in sample_data.
%
%   auto        - logical, run QC in batch mode
%
% Outputs:
%   data        - same as input.
%
%   flags       - Vector the same length as data, with flags for flatline 
%                 regions.
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

% read all values from imosGradientQC properties file
values = readProperty('*', fullfile('AutomaticQC', 'imosGradientQC.txt'));
param = strtrim(values{1});
thresholdExpr = strtrim(values{2});

iParam = strcmpi(sample_data.(type){k}.name, param);
    
if any(iParam)
    qcSet    = str2double(readProperty('toolbox.qc_set'));
    rawFlag  = imosQCFlag('raw',  qcSet, 'flag');
    passFlag = imosQCFlag('good', qcSet, 'flag');
    failFlag = imosQCFlag('bad',  qcSet, 'flag');
    
    lenData = length(data);
    
    % initially all data is raw
    flags = ones(lenData, 1)*rawFlag;
    
    gradient = abs(data(2:end) - data(1:end-1));
    
    threshold = eval(thresholdExpr{iParam});
    threshold = ones(lenData-1, 1) .* threshold;
    
    iGoodGrad = gradient < threshold;
    iGoodGrad = [iGoodGrad; false]; % we don't know about the last point
    
    iBadGrad = gradient >= threshold;
    % when current point is flagged bad then also the next one
    iBadGrad(2:end) = iBadGrad(1:end-1) | iBadGrad(2:end);
    iBadGrad = [iBadGrad; false]; % we don't know about the last point
    
    if any(iGoodGrad)
        flags(iGoodGrad) = passFlag;
    end
    
    if any(iBadGrad)
        flags(iBadGrad) = failFlag;
    end
end