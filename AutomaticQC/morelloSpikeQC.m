function [data, flags, log] = morelloSpikeQC( sample_data, data, k, type, auto )
%MORELLOSPIKE Flags TEMP and PSAL spikes in the given data set.
%
% Spike test from ANFOG which finds and flags any data which value Vn passes
% the test |Vn-(Vn+1 + Vn-1)/2| - |(Vn+1 - Vn-1)/2| > threshold
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
% Author:       Dirk Slawinski <dirk.slawinski@csiro.au>
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

% read all values from morelloSpikeQC properties file
values = readProperty('*', fullfile('AutomaticQC', 'morelloSpikeQC.txt'));
param = strtrim(values{1});
threshold = strtrim(values{2});

iParam = strcmpi(sample_data.(type){k}.name, param);

if any(iParam)
    lenData = length(data);
    
    threshold = threshold(iParam);
    threshold = ones(lenData, 1) * str2double(threshold);
   
    qcSet    = str2double(readProperty('toolbox.qc_set'));
    passFlag = imosQCFlag('good', qcSet, 'flag');
    failFlag = imosQCFlag('bad',  qcSet, 'flag');
    
    % initially all data is good
    flags = ones(lenData, 1)*passFlag;
    testval = flags*NaN;
    
    I = (2:lenData-1);
    Ip1 = I + 1;
    Im1 = I - 1;
    
    testval(1) = abs(data(2) - data(1));
    testval(I) = abs(abs(data(I) - (data(Ip1) + data(Im1))/2) ...
        - abs((data(Ip1) - data(Im1))/2));
    testval(lenData) = abs(data(lenData) - data(lenData-1));
    
    iSpike = testval > threshold;
    if any(iSpike)
        flags(iSpike) = failFlag;
    end
end