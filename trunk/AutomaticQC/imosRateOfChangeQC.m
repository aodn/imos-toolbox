function [data, flags, paramsLog] = imosRateOfChangeQC( sample_data, data, k, type, auto )
%IMOSRATEOFCHANGEQC Flags consecutive PARAMETER values with gradient > threshold.
%
% The aim of the check is to verify the rate of the
% change in time. It is based on the difference
% between the current value with the previous and
% next ones. Failure of a rate of the change test is
% ascribed to the current data point of the set.
% 
% Action: PARAMETER values are flagged if
% |Vi � Vi-1| + |Vi � Vi+1| > 2�(threshold)
% where Vi is the current value of the parameter, Vi�1
% is the previous and Vi+1 the next one. If
% the one parameter is missing, the relative part of
% the formula is omitted and the comparison term
% reduces to 1*(threshold).
%
% These threshold values are handled for each IMOS parameter in
% imosRateOfChangeQC.txt. Standard deviation can be
% used from the first month of significant data
% of the time series as a threshold, stdDev in imosRateOfChangeQC.txt.
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

if ~strcmp(type, 'variables'), return; end

% read all values from imosRateOfChangeQC properties file
values = readProperty('*', fullfile('AutomaticQC', 'imosRateOfChangeQC.txt'));
param = strtrim(values{1});
thresholdExpr = strtrim(values{2});

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
    rawFlag  = imosQCFlag('raw',  qcSet, 'flag');
    passFlag = imosQCFlag('good', qcSet, 'flag');
    goodFlag = imosQCFlag('good', qcSet, 'flag');
    pGoodFlag= imosQCFlag('probablyGood', qcSet, 'flag');
    failFlag = imosQCFlag('probablyBad',  qcSet, 'flag');
    badFlag  = imosQCFlag('bad',  qcSet, 'flag');
    
    paramsLog = ['threshold=' thresholdExpr{iParam}];
    
    % matrix case, we process line by line for timeserie study
    % purpose
    len1 = size(data, 1);
    len2 = size(data, 2);
    flags = ones(len1, len2, 'int8')*rawFlag;
    
    % get previously computed stddev
    qcPrep = sample_data.meta.qcPrep.('imosRateOfChangeQC');
    stdDevs = qcPrep.(type){k}.stdDev;
    
    for i=1:len2
        lineData = data(:,i);
        
        % we don't consider already bad data in the current test
        iBadData = sample_data.(type){k}.flags(:,i) == badFlag;
        dataTested = lineData(~iBadData);
        
        if isempty(dataTested), return; end
        
        lenLineData = length(lineData);
        lenDataTested = length(dataTested);
        
        lineFlags = ones(lenLineData, 1, 'int8')*rawFlag;
        flagsTested = ones(lenDataTested, 1, 'int8')*rawFlag;
        
        % let's consider time in seconds
        tTime = 'dimensions';
        iTime = getVar(sample_data.(tTime), 'TIME');
        if iTime == 0, return; end
        time = sample_data.(tTime){iTime}.data * 24 * 3600;
        if size(time, 1) == 1
            % time is a row, let's have a column instead
            time = time';
        end
    
        if len2 > 1
            stdDev = stdDevs(i);
        else
            stdDev = stdDevs;
        end
    
        previousGradient    = [0; abs(dataTested(2:end) - dataTested(1:end-1))]; % we don't know about the first point
        nextGradient        = [abs(dataTested(1:end-1) - dataTested(2:end)); 0]; % we don't know about the last point
        clear dataTested
        doubleGradient      = previousGradient + nextGradient;
        clear previousGradient nextGradient
        
        % let's compute threshold values
        try
            threshold = eval(thresholdExpr{iParam});
            threshold = ones(lenDataTested, 1) .* threshold;
            % we handle the cases when the doubleGradient is based on the sum
            % of 1 or 2 gradients
            threshold(2:end-1) = 2*threshold(2:end-1);
        catch
            error(['Invalid threshold expression in imosRateOfChangeQC.txt for ' param]);
        end
        
        iGoodGrad = false(lenDataTested, 1);
        iBadGrad = false(lenDataTested, 1);
        
        iGoodGrad = doubleGradient <= threshold;
        iBadGrad = doubleGradient > threshold;
        clear doubleGradient threshold
        
        % if the time period between a point and its previous is greater than 1h, then the
        % test is cancelled and QC is set to Raw for current points.
        time(iBadData) = [];
        diffTime = time(2:end) - time(1:end-1);
        iGreater = diffTime > 3600;
        clear diffTime
        iGreater = [false; iGreater];
        iGoodGrad(iGreater) = false;
        iBadGrad(iGreater)  = false;
        clear iGreater
        
        % we do the same with the second gradient
        diffTime = abs(time(1:end-1) - time(2:end));
        clear time
        iGreater = diffTime > 3600;
        clear diffTime
        iGreater = [iGreater; false];
        iGoodGrad(iGreater) = false;
        iBadGrad(iGreater)  = false;
        clear iGreater
        
        if any(iGoodGrad)
            flagsTested(iGoodGrad) = passFlag;
        end
        
        if any(iBadGrad)
            flagsTested(iBadGrad) = failFlag;
        end
        
        if any(iGoodGrad | iBadGrad)
            lineFlags(~iBadData) = flagsTested;
            flags(:,i) = lineFlags;
        end
        clear iGoodGrad iBadGrad iBadData flagsTested lineFlags
    end
end