function [data, flags, log] = morelloGradientQC( sample_data, data, k, auto )
%MORELLOGRADIENT Flags consecutive values with gradient > threshold.
%
% Gradient test which finds and flags any consecutive data which gradient
% is > threshold
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

error(nargchk(3, 4, nargin));
if ~isstruct(sample_data),        error('sample_data must be a struct'); end
if ~isvector(data),               error('data must be a vector');        end
if ~isscalar(k) || ~isnumeric(k), error('k must be a numeric scalar');   end

% auto logical in input to enable running under batch processing
if nargin<4, auto=false; end

qcSet    = str2double(readProperty('toolbox.qc_set'));
rawFlag = imosQCFlag('raw',  qcSet, 'flag');
goodFlag = imosQCFlag('good',  qcSet, 'flag');
spikeFlag = imosQCFlag('spike', qcSet, 'flag');

lenData = length(data);

log   = {};
flags = ones(lenData, 1)*rawFlag;

% define thresholds
threshold = flags*NaN;
% Threshold = 6 for temperature when pressure < 500 dbar
% Threshold = 2 for temperature when pressure >= 500 dbar
%
% Threshold = 0.9 for salinity when pressure < 500 dbar
% Threshold = 0.3 for salinity when pressure >= 500 dbar

presIdx     = getVar(sample_data.variables, 'PRES');
presRelIdx  = getVar(sample_data.variables, 'PRES_REL');

if presRelIdx == 0
    % update from a relative pressure like SeaBird computes
    % it in its processed files, substracting a constant value
    % 10.1325 dbar for nominal atmospheric pressure
    relPres = sample_data.variables{presIdx}.data - 10.1325;
else
    % update from a relative measured pressure
    relPres = sample_data.variables{presRelIdx}.data;
end

if strcmpi(sample_data.variables{k}.name, 'TEMP')
    threshold(relPres < 500) = 6;
    threshold(relPres >= 500) = 2;
elseif strcmpi(sample_data.variables{k}.name, 'PSAL')
    threshold(relPres < 500) = 0.9;
    threshold(relPres >= 500) = 0.3;
else
    return;
end

% initially all data is good
flags = ones(lenData, 1)*goodFlag;

gradient = [0; data(2:end) - data(1:end-1)];

iGrad = abs(gradient) >= threshold;

if any(iGrad)
    flags(iGrad) = spikeFlag;
end