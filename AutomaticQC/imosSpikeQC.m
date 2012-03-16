function [data, flags, log] = imosSpikeQC( sample_data, data, k, type, auto )
%IMOSSPIKEQC Flags any variable present in imosSpikeQC.txt according to the 
% associated threshold in the given data set.
%
% Spike test from ARGO which finds and flags any data which value Vn passes
% the test |Vn-(Vn+1 + Vn-1)/2| - |(Vn+1 - Vn-1)/2| > threshold
%
% ARGO suggests the following thresholds for Temperature and Salinity :
%
% Threshold = 6 for temperature when pressure < 500 dbar
% Threshold = 2 for temperature when pressure >= 500 dbar
%
% Threshold = 0.9 for salinity when pressure < 500 dbar
% Threshold = 0.3 for salinity when pressure >= 500 dbar
%
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

% read all values from imosSpikeQC properties file
values = readProperty('*', fullfile('AutomaticQC', 'imosSpikeQC.txt'));
param = strtrim(values{1});
thresholdExpr = strtrim(values{2});

iParam = strcmpi(sample_data.(type){k}.name, param);

if any(iParam)
    lenData = length(data);
   
    qcSet    = str2double(readProperty('toolbox.qc_set'));
    rawFlag  = imosQCFlag('raw',  qcSet, 'flag');
    passFlag = imosQCFlag('good', qcSet, 'flag');
    failFlag = imosQCFlag('bad',  qcSet, 'flag');
    
    flags = ones(lenData, 1)*rawFlag;
    testval = nan(lenData, 1);

    I = true(lenData, 1);
    I(1) = false;
    I(end) = false;
    
    Ip1 = [false; I(1:end-1)];
    Im1 = [I(2:end); false];
    
    % testval(1) and testval(end) are left to NaN on pupose so that QC is
    % raw for those two points. Indeed the test cannot be performed.
    data1 = data(Im1);
    data2 = data(I);
    data3 = data(Ip1);
    
    testval(I) = abs(abs(data2 - (data3 + data1)/2) ...
        - abs((data3 - data1)/2));
    
    if strcmpi(thresholdExpr{iParam}, 'PABIM')
        IChl            = true(lenData, 1);
        IChl(1:2)       = false;
        IChl(end-1:end) = false;
    
        IChlp1 = [false; IChl(1:end-1)];
        IChlp2 = [false; false; IChl(1:end-2)];
        IChlm1 = [IChl(2:end); false];
        IChlm2 = [IChl(3:end); false; false];
        
        dataChl0 = data(IChlm2);
        dataChl1 = data(IChlm1);
        dataChl2 = data(IChl);
        dataChl3 = data(IChlp1);
        dataChl4 = data(IChlp2);
        
        threshold = [NaN; NaN; ...
            abs(median(dataChl0+dataChl1+dataChl2+dataChl3+dataChl4, 2)) + ...
            abs(std(dataChl0+dataChl1+dataChl2+dataChl3+dataChl4, 0, 2)); ...
            NaN; NaN];
    else
        threshold = eval(thresholdExpr{iParam});
        threshold = ones(lenData, 1) .* threshold;
    end
    
    iNoSpike = testval <= threshold;
    if any(iNoSpike)
        flags(iNoSpike) = passFlag;
    end
    
    iSpike = testval > threshold;
    if any(iSpike)
        flags(iSpike) = failFlag;
    end
end