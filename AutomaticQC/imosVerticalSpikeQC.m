function [data, flags, paramsLog] = imosVerticalSpikeQC( sample_data, data, k, type, auto )
%IMOSSPIKEQC Flags any variable present in imosVerticalSpikeQC.txt according to the 
% associated threshold in the given data set.
%
% Spike test on profiles data from ARGO which finds and flags any data which value Vn passes
% the test |Vn-(Vn+1 + Vn-1)/2| - |(Vn+1 - Vn-1)/2| > threshold
%
% These threshold values are handled for each IMOS parameter in
% imosVerticalSpikeQC.txt
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
% Copyright (C) 2017, Australian Ocean Data Network (AODN) and Integrated 
% Marine Observing System (IMOS).
%
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation version 3 of the License.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
% GNU General Public License for more details.

% You should have received a copy of the GNU General Public License
% along with this program.
% If not, see <https://www.gnu.org/licenses/gpl-3.0.en.html>.
%

narginchk(4, 5);
if ~isstruct(sample_data),              error('sample_data must be a struct');      end
if ~isscalar(k) || ~isnumeric(k),       error('k must be a numeric scalar');        end
if ~ischar(type),                       error('type must be a string');             end

% auto logical in input to enable running under batch processing
if nargin<5, auto=false; end

paramsLog = [];
flags     = [];

% this test only applies to profile mode
mode = readProperty('toolbox.mode');
if ~strcmpi(mode, 'profile')
    return;
end

% read all values from imosSpikeQC properties file
values = readProperty('*', fullfile('AutomaticQC', 'imosVerticalSpikeQC.txt'));

% read dataset QC parameters if exist and override previous 
% parameters file
currentQCtest = mfilename;
values = readDatasetParameter(sample_data.toolbox_input_file, currentQCtest, '*', values);

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
    failFlag = imosQCFlag('probablyBad',  qcSet, 'flag');
    badFlag  = imosQCFlag('bad',  qcSet, 'flag');
    badFlags = [failFlag, badFlag];
    
    paramsLog = ['threshold=' thresholdExpr{iParam}];
    
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
    iBadData = ismember(sample_data.variables{k}.flags, badFlags);
    dataTested = data(~iBadData);
    
    if isempty(dataTested), return; end
    
    lenData = length(data);
    lenDataTested = length(dataTested);
    
    flags = ones(lenData, 1, 'int8')*rawFlag;
    flagsTested = ones(lenDataTested, 1, 'int8')*rawFlag;
    
    testval = nan(lenDataTested, 1);

    I = true(lenDataTested, 1);
    I(1) = false;
    I(end) = false;
    
    Ip1 = [false; I(1:end-1)];
    Im1 = [I(2:end); false];
    
    % testval(1) and testval(end) are left to NaN on purpose so that QC is
    % raw for those two points. Indeed the test cannot be performed.
    data1 = dataTested(Im1);
    data2 = dataTested(I);
    data3 = dataTested(Ip1);
    
    testval(I) = abs(data2 - (data3 + data1)/2) ...
        - abs((data3 - data1)/2);
    
    if strcmpi(thresholdExpr{iParam}, 'PABIM')
        % we execute the suggested PABIM white book v1.3 threshold value
        % for 'Flurorescence like' data (p.44):
        % 
        % Threshold_Value = |median(V0,V1,V2,V3,V4)| + |standard_deviation(V0,V1,V2,V3,V4)|
        IChl            = true(lenDataTested, 1);
        IChl(1:2)       = false;
        IChl(end-1:end) = false;
    
        IChlp1 = [false; IChl(1:end-1)];
        IChlp2 = [false; false; IChl(1:end-2)];
        IChlm1 = [IChl(2:end); false];
        IChlm2 = [IChl(3:end); false; false];
        
        dataChl0 = dataTested(IChlm2);
        dataChl1 = dataTested(IChlm1);
        dataChl2 = dataTested(IChl);
        dataChl3 = dataTested(IChlp1);
        dataChl4 = dataTested(IChlp2);
        
        threshold = [NaN; NaN; ...
            abs(median(dataChl0+dataChl1+dataChl2+dataChl3+dataChl4, 2)) + ...
            abs(std(dataChl0+dataChl1+dataChl2+dataChl3+dataChl4, 0, 2)); ...
            NaN; NaN];
    else
        threshold = eval(thresholdExpr{iParam});
        threshold = ones(lenDataTested, 1) .* threshold;
    end
    
    iNoSpike = testval <= threshold;
    if any(iNoSpike)
        flagsTested(iNoSpike) = passFlag;
    end
    
    iSpike = testval > threshold;
    if any(iSpike)
        flagsTested(iSpike) = failFlag;
    end
    
    if any(iSpike | iNoSpike)
        flags(~iBadData) = flagsTested;
    end
    
    if isMatrix
        % we fold the vector back into a matrix
        data = reshape(data, [len1, len2, len3]);
        flags = reshape(flags, [len1, len2, len3]);
    end
    
    % write/update dataset QC parameters
    for i=1:length(param)
        writeDatasetParameter(sample_data.toolbox_input_file, currentQCtest, param{i}, thresholdExpr{i});
    end
end