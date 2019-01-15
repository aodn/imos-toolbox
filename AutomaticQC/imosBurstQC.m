function [data, flags, paramsLog] = imosBurstQC ( sample_data, data, k, type, auto )
%IMOSBURSTQC Flags outliers data in a burst which is out of the burst variability.
%
% Iterates through the bursts of the given data, and returns flags for any samples which
% do not fall within the acceptable ranges defined by PARAM_avg +/- PARAM_var set
% in imosBurstQC.txt.
%
% Inputs:
%   sample_data - struct containing the entire data set and dimension data.
%
%   data        - the vector/matrix of data to check.
%
%   k           - Index into the sample_data.variables vector.
%
%   type        - dimensions/variables type to check in sample_data.
%
%   auto        - logical, run QC in batch mode
%
% Outputs:
%   data        - same as input.
%
%   flags       - Vector the same length as data, with flags for corresponding
%                 data outliers.
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

% only process burst datasets
if ~isfield(sample_data, 'instrument_burst_duration')
    return; 
else
    if isempty(sample_data.instrument_burst_duration), return; end
end

% read all values from the property file
statsFile = ['AutomaticQC' filesep 'imosBurstQC.txt'];
[params, stats]  = listProperties(statsFile);

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

iParam = strncmpi(paramName, params, length(paramName));

if any(iParam)
    % get the flag values with which we flag good and out of range data
    qcSet = str2double(readProperty('toolbox.qc_set'));
    outlierFlag  = imosQCFlag('probablyBad', qcSet, 'flag');
    rawFlag      = imosQCFlag('raw',   qcSet, 'flag');
    goodFlag     = imosQCFlag('good',  qcSet, 'flag');
    probGoodFlag = imosQCFlag('probablyGood', qcSet, 'flag');
    
    statAvg = readProperty([paramName '_avg'], statsFile);
    statVar = readProperty([paramName '_var'], statsFile);
    
    lenData = length(data);
    
    % we replace values flagged as bad by NaN before calculating stats
    iGood = ismember(sample_data.(type){k}.flags, [rawFlag, goodFlag, probGoodFlag]);
    data(~iGood) = NaN;
    
    tTime = 'dimensions';
    iTime = getVar(sample_data.(tTime), 'TIME');
    if iTime == 0
        tTime = 'variables';
        iTime = getVar(sample_data.(tTime), 'TIME');
        if iTime == 0, return; end
    end
    timeData = sample_data.(tTime){iTime}.data;
    
    timeBetweenBurst = sample_data.instrument_burst_interval - sample_data.instrument_burst_duration;
    timeDiff = [timeBetweenBurst; diff(timeData*24*3600)];
    iFirsts = (timeDiff >= timeBetweenBurst);
    iLasts = [iFirsts(2:end); true];
    iFirsts = find(iFirsts);
    iLasts = find(iLasts);
    nBursts = length(iFirsts);
    timeBurstAvg = NaN(nBursts, 1);
    dataBurstAvg = NaN(nBursts, 1);
    dataBurstVar = NaN(nBursts, 1);
    dataThresholdMin = NaN(lenData, 1);
    dataThresholdMax = NaN(lenData, 1);
    for i=1:nBursts
        burstData = data(iFirsts(i):iLasts(i));
        % we get rid of all NaNs to simplify stats calculations
        iNaN = isnan(burstData);
        burstData(iNaN) = [];
        dataBurstAvg(i) = eval(statAvg);
        dataBurstVar(i) = eval(statVar);
        
        dataThresholdMin(iFirsts(i):iLasts(i)) = dataBurstAvg(i) - dataBurstVar(i);
        dataThresholdMax(iFirsts(i):iLasts(i)) = dataBurstAvg(i) + dataBurstVar(i);
        
        burstTime = timeData(iFirsts(i):iLasts(i));
        burstData = burstTime(~iNaN);
        timeBurstAvg(i) = eval(statAvg);
    end
    
    % initialise all flags to non QC'd
    flags = ones(lenData, 1, 'int8')*rawFlag;
    
    paramsLog = ['avg=' statAvg ', var=' statVar];
    
    % initialise all flags to bad
    flags = ones(lenData, 1, 'int8')*outlierFlag;
    
    iPassed = data <= dataThresholdMax;
    iPassed = iPassed & data >= dataThresholdMin;
    
    % add flags for in range values
    flags(iPassed) = goodFlag;
    flags(iPassed) = goodFlag;
    
    % update burstStats info for display
    bSh = findobj('Tag', 'visiBurstStatsCheckBox');
    burstStats = get(bSh, 'UserData');
    if isempty(burstStats)
        burstStats(end+1).fileName = sample_data.toolbox_input_file;
        burstStats(end).(sample_data.(type){k}.name).timeBurstAvg = timeBurstAvg;
        burstStats(end).(sample_data.(type){k}.name).dataBurstAvg = dataBurstAvg;
        burstStats(end).(sample_data.(type){k}.name).dataBurstVar = dataBurstVar;
    else
        iFile = strcmp(sample_data.toolbox_input_file, {burstStats(:).fileName});
        if any(iFile)
            burstStats(iFile).(sample_data.(type){k}.name).timeBurstAvg = timeBurstAvg;
            burstStats(iFile).(sample_data.(type){k}.name).dataBurstAvg = dataBurstAvg;
            burstStats(iFile).(sample_data.(type){k}.name).dataBurstVar = dataBurstVar;
        else
            burstStats(end+1).fileName = sample_data.toolbox_input_file;
            burstStats(end).(sample_data.(type){k}.name).timeBurstAvg = timeBurstAvg;
            burstStats(end).(sample_data.(type){k}.name).dataBurstAvg = dataBurstAvg;
            burstStats(end).(sample_data.(type){k}.name).dataBurstVar = dataBurstVar;
        end
    end
    set(bSh, 'UserData', burstStats);
end
