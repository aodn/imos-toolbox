function [data, flags, paramsLog] = imosInOutWaterQC( sample_data, data, k, type, auto )
%IMOSINOUTWATERQC Flags samples which were taken before and after the instrument was placed
% in the water.
%
% Flags all samples from the data set which have a time that is before or after the 
% in and out water time.
%
% Inputs:
%   sample_data - struct containing the entire data set and dimension data.
%
%   data        - the vector of data to check.
%
%   k           - Index into the sample_data.variables vector.
%
%   type        - dimensions/variables type to check in sample_data.
%
%   auto        - logical, run QC in batch mode
%
% Outputs:
%   data        - Same as input.
%
%   flags       - Vector the same size as data, with before in-water samples 
%                 flagged. 
%
%   paramsLog   - string containing details about params' procedure to include in QC log
%
% Author:       Guillaume Galibert <guillaume.galibert@utas.edu.au>
%

%
% Copyright (c) 2016, Australian Ocean Data Network (AODN) and Integrated 
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
%     * Neither the name of the AODN/IMOS nor the names of its contributors 
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

% this test doesn't apply on dimensions nor TIMESERIES, PROFILE, TRAJECTORY, LATITUDE, LONGITUDE, nor NOMINAL_DEPTH variables
if ~strcmp(type, 'variables'), return; end
if any(strcmp(sample_data.(type){k}.name, {'TIMESERIES', 'PROFILE', 'TRAJECTORY', 'LATITUDE', 'LONGITUDE', 'NOMINAL_DEPTH'})), return; end

time_in_water = sample_data.time_deployment_start;
time_out_water = sample_data.time_deployment_end;

if isempty(time_in_water) || isempty(time_out_water)
    fprintf('%s\n', ['Warning : ' 'Not enough deployment dates ' ...
        'metadata found to perform in/out water QC test.']);
    fprintf('%s\n', ['Please make sure global_attributes ' ...
        'time_deployment_start and time_deployment_end are documented.']);
    return;
end

tTime = 'dimensions';
iTime = getVar(sample_data.(tTime), 'TIME');
if iTime == 0
    tTime = 'variables';
    iTime = getVar(sample_data.(tTime), 'TIME');
    if iTime == 0, return; end
end
time = sample_data.(tTime){iTime}.data;

% get the toolbox execution mode
mode = readProperty('toolbox.mode');

switch mode
    case 'profile'
        % in this case we mainly aim at checking that TIME is not 
        % significantly out against the ddb station time (check for 
        % instrument clock not properly set or typos in the database)
        if ~strcmpi(sample_data.(type){k}.name, 'TIME'), return; end
        
        if time < time_in_water
            error(['TIME value ' datestr(time, 'yyyy-mm-dd HH:MM:SS') ' is lower than time_deployment_start ' datestr(time_in_water, 'yyyy-mm-dd HH:MM:SS') ' => Check ddb station time values against data file time values!']);
        end
        if time > time_out_water
            error(['TIME value ' datestr(time, 'yyyy-mm-dd HH:MM:SS') ' is greater than time_deployment_end ' datestr(time_out_water, 'yyyy-mm-dd HH:MM:SS') ' => Check ddb station time values against data file time values!']);
        end
        
    case 'timeSeries'
        % for test in display
        sampleFile = sample_data.toolbox_input_file;
        
        mWh = findobj('Tag', 'mainWindow');
        qcParam = get(mWh, 'UserData');
        p = 0;
        if ~isempty(qcParam)
            for i=1:length(qcParam)
                if strcmp(qcParam(i).dataSet, sampleFile)
                    p = i;
                    break;
                end
            end
        end
        if p == 0
            p = length(qcParam) + 1;
        end
        qcParam(p).dataSet = sampleFile;
        qcParam(p).('inWater')  = time_in_water;
        qcParam(p).('outWater') = time_out_water;
        % update qcParam for display
        set(mWh, 'UserData', qcParam);
        
        qcSet     = str2double(readProperty('toolbox.qc_set'));
        rawFlag   = imosQCFlag('raw', qcSet, 'flag');
        failFlag  = imosQCFlag('bad', qcSet, 'flag');
        
        paramsLog = ['in=' datestr(time_in_water, 'dd/mm/yy HH:MM:SS') ...
            ', out=' datestr(time_out_water, 'dd/mm/yy HH:MM:SS')];
        
        lenData = length(time);
        
        % initially all data is bad
        flags = ones(lenData, 1, 'int8')*failFlag;
        
        % find samples which were taken before in water
        iGood = time >= time_in_water;
        iGood = iGood & time <= time_out_water;
        
        if any(iGood)
            flags(iGood) = rawFlag;
        else
            error(['All points failed In/Out water QC test in file ' sample_data.toolbox_input_file]);
        end
        
        % transform flags to the appropriate output shape
        sizeData = size(data);
        flags = repmat(flags, [1 sizeData(2:end)]);
end
