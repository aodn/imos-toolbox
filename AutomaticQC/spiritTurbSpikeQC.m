function [data, flags, paramsLog] = spiritTurbSpikeQC( sample_data, data, k, type, auto )
%SPIRITTURBSPIKEQC applies despike.m recursively to turbidity TURB.
%
%
% Inputs:
%   sample_data - struct containing the data set.
%
%   data        - the vector/matrix of data to check.
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
%   paramsLog   - string containing details about params' procedure to include in QC log
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

narginchk(4, 5);
if ~isstruct(sample_data),              error('sample_data must be a struct');      end
if ~isscalar(k) || ~isnumeric(k),       error('k must be a numeric scalar');        end
if ~ischar(type),                       error('type must be a string');             end

% auto logical in input to enable running under batch processing
if nargin<5, auto=false; end

paramsLog = [];
flags     = [];

% read all values from imosSpikeQC properties file
maxAllowedGrad      = readProperty('gradientMax', fullfile('AutomaticQC', 'spiritTurbSpikeQC.txt'));
maxAllowedSpikeTime = readProperty('timeWindow',  fullfile('AutomaticQC', 'spiritTurbSpikeQC.txt'));

maxAllowedGrad      = str2double(maxAllowedGrad);
maxAllowedSpikeTime = str2double(maxAllowedSpikeTime);

% read dataset QC parameters if exist and override previous 
% parameters file
currentQCtest = mfilename;
maxAllowedGrad      = readQCparameter(sample_data.toolbox_input_file, currentQCtest, 'gradientMax', maxAllowedGrad);
maxAllowedSpikeTime = readQCparameter(sample_data.toolbox_input_file, currentQCtest, 'timeWindow',  maxAllowedSpikeTime);

paramsLog = ['gradientMax=' num2str(maxAllowedGrad) ', timeWindow=' num2str(maxAllowedSpikeTime)];

% let's handle the case we have multiple same param distinguished by "_1",
% "_2", etc...
paramName = sample_data.(type){k}.name;
iLastUnderscore = strfind(paramName, '_');
if iLastUnderscore > 0
    iLastUnderscore = iLastUnderscore(end);
    if length(paramName) > iLastUnderscore
        if ~isnan(str2double(paramName(iLastUnderscore+1:end)))
            paramName = paramName(1:iLastUnderscore-1);
        end
    end
end

paramTested = 'TURB';
iParam = strcmpi(paramName, paramTested);

if any(iParam)
    qcSet    = str2double(readProperty('toolbox.qc_set'));
    rawFlag  = imosQCFlag('raw',  qcSet, 'flag');
    passFlag = imosQCFlag('good', qcSet, 'flag');
    failFlag = imosQCFlag('probablyBad',  qcSet, 'flag');
    badFlag  = imosQCFlag('bad',  qcSet, 'flag');
    
    % matrix case, we unfold the matrix in one vector for profile study
    % purpose
    isMatrix = size(data, 1)>1 & size(data, 2)>1;
    if isMatrix
        len1 = size(data, 1);
        len2 = size(data, 2);
        len3 = size(data, 3);
        data = data(:);
    end
    
    % we don't consider already bad data in the current test
    iBadData = sample_data.variables{k}.flags == badFlag;
    dataTested = data(~iBadData);
    
    if isempty(dataTested), return; end
    
    lenData = length(data);
    lenDataTested = length(dataTested);
    
    flags = ones(lenData, 1, 'int8')*rawFlag;
    flagsTested = ones(lenDataTested, 1, 'int8')*rawFlag;
    
    timeTested = sample_data.dimensions{1}.data(~iBadData);
    
    % we try to identify anomalies / spikes
    iSpike = despike(timeTested, dataTested, maxAllowedGrad, maxAllowedSpikeTime);
    
    % we try to recursively identify more spikes, removing previously
    % identified ones from the tested dataset
    iNewSpike = iSpike;
    while any(iNewSpike)
        iNewSpike = despike(timeTested(~iSpike), dataTested(~iSpike), maxAllowedGrad, maxAllowedSpikeTime);
        nNewSpike = sum(iNewSpike);
        if nNewSpike
            [~, fileName, ext] = fileparts(sample_data.toolbox_input_file);
            disp(['Info : spiritTurbSpikeQC identifies ' num2str(nNewSpike) ' more spikes in ' paramTested ' from ' fileName ext]);
        end
        iSpike(~iSpike) = iNewSpike;
    end
    
    flagsTested(~iSpike) = passFlag;
    flagsTested(iSpike) = failFlag;
    
    flags(~iBadData) = flagsTested;
    
    if isMatrix
        % we fold the vector back into a matrix
        data = reshape(data, [len1, len2, len3]);
        flags = reshape(flags, [len1, len2, len3]);
    end
    
    % write/update dataset QC parameters
    writeQCparameter(sample_data.toolbox_input_file, currentQCtest, 'gradientMax', maxAllowedGrad);
    writeQCparameter(sample_data.toolbox_input_file, currentQCtest, 'timeWindow',  maxAllowedSpikeTime);
end