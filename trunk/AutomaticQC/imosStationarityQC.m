function [data, flags, paramsLog] = imosStationarityQC( sample_data, data, k, type, auto )
%IMOSSTATIONARITYQC Flags consecutive PARAMETERS listed in
%imosGlobalRangeQC.txt equal values in the given data set.
%
% Stationarity test from IOC which finds and flags any consecutive equal values
% when number of consecutive points of equal values > T = 24*(60/delta_t) 
% with delta_t the sampling interval in minutes.
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

error(nargchk(4, 5, nargin));
if ~isstruct(sample_data),              error('sample_data must be a struct');      end
if ~isscalar(k) || ~isnumeric(k),       error('k must be a numeric scalar');        end
if ~ischar(type),                       error('type must be a string');             end

% auto logical in input to enable running under batch processing
if nargin<5, auto=false; end

paramsLog = [];
flags     = [];

% read all values from imosGlobalRangeQC properties file
values = readProperty('*', fullfile('AutomaticQC', 'imosGlobalRangeQC.txt'));
param = strtrim(values{1});

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

iParam = strcmpi(paramName, param);

if any(iParam)
    
    qcSet    = str2double(readProperty('toolbox.qc_set'));
    passFlag = imosQCFlag('good', qcSet, 'flag');
    failFlag = imosQCFlag('bad',  qcSet, 'flag');
    badFlag  = imosQCFlag('bad',  qcSet, 'flag');
    
    % we don't consider already bad data in the current test
    iBadData = sample_data.variables{k}.flags == badFlag;
    dataTested = data(~iBadData);
    
    if isempty(dataTested), return; end
    
    % matrix case, we unfold the matrix in one vector for timeserie study
    % purpose
    isMatrix = size(data, 1)>1 & size(data, 2)>1;
    if isMatrix
        len1 = size(data, 1);
        len2 = size(data, 2);
        len3 = size(data, 3);
        data = data(:);
    end
    lenData = length(data);
    lenDataTested = length(dataTested);
    
    % initially all data is good
    flags = ones(lenData, 1, 'int8')*passFlag;
    flagsTested = ones(lenDataTested, 1, 'int8')*passFlag;
    
    % calc the max allowed number of consecutive values
    delta_t = sample_data.meta.instrument_sample_interval/60;
    nt = floor(24 * (60 / delta_t));
    
    equVal  = (diff(dataTested) == 0);
    
    % special case when not any consecutive couple of same value
    if all(~equVal)
        return;
    end
    
    % special case when all consecutive couple of same value
    if all(equVal)
        flagsTested = ones(lenDataTested, 1, 'int8')*failFlag;
        flags(~iBadData) = flagsTested;
        return;
    end
    
    if equVal(1)
        equVal = [true; equVal];
    else
        equVal = [false; equVal];
    end
    diffVal = ~equVal;
    
    lastEqVal   = (equVal(1:end-1) - equVal(2:end)) == 1;
    lastDiffVal = (diffVal(1:end-1) - diffVal(2:end)) == 1;
    
    if equVal(end)
        lastEqVal(end+1)   = true;
        lastDiffVal(end+1) = false;
    else
        lastEqVal(end+1)   = false;
        lastDiffVal(end+1) = true;
    end
    
    pos = (1:1:lenDataTested)';
    
    posLastEqVal    = pos(lastEqVal);
    posLastDiffVal  = pos(lastDiffVal);
    
    if equVal(1) && equVal(end)
        % starts and finish with a same value portion
        numLastEqVal = [posLastEqVal(1); posLastEqVal(2:end) - (posLastDiffVal-1)];
    elseif equVal(1) && ~equVal(end)
        % starts with a same value portion and finish with distincts values
        numLastEqVal = [posLastEqVal(1); posLastEqVal(2:end) - (posLastDiffVal(1:end-1)-1)];
    elseif ~equVal(1) && equVal(end)
        % starts with distinct values and finish with a same value portion
        numLastEqVal = posLastEqVal - (posLastDiffVal-1);
    else
        % starts and finish with a distinct value portion
        numLastEqVal = posLastEqVal - (posLastDiffVal(1:end-1)-1);
    end
    
    lastEqValNum = double(lastEqVal);
    lastEqValNum(lastEqVal) = numLastEqVal;
    
    iFlatline = find(lastEqValNum > nt);
    if ~isempty(iFlatline)
        nFlatline = length(iFlatline);
        for i=1:nFlatline
            flagsTested(iFlatline(i)-lastEqValNum(iFlatline(i))+1:iFlatline(i)) = failFlag;
        end
        flags(~iBadData) = flagsTested;
    end
    
    if isMatrix
        % we fold the vector back into a matrix
        data = reshape(data, [len1, len2, len3]);
        flags = reshape(flags, [len1, len2, len3]);
    end
end
