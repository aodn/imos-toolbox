function [data, flags, log] = morelloRangeNetCDFQC( sample_data, data, k, type, auto )
%MORELLORANGE Flags value out of a climatology range.
%
% Range test which finds and flags any data which value doesn't fit in the
% range [min max] = climRange(lon, lat, date, depth, param)
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

dataName  = sample_data.(type){k}.name;
iVar = 0;
if strcmpi(dataName, 'TEMP')
    iVar = 1;
elseif strcmpi(dataName, 'PSAL')
    iVar = 2;
elseif strcmpi(dataName, 'DOX2')
    iVar = 3;
end
    
if iVar > 0
    % we'll need time and depth information
    idTime  = getVar(sample_data.dimensions, 'TIME');
    ivDepth = getVar(sample_data.variables, 'DEPTH');
    if ivDepth == 0
        fprintf('%s\n', ['Warning : ' 'No depth information found to '...
            'perform range QC test']);
        return;
    end
    dataTime  = sample_data.dimensions{idTime}.data;
    dataDepth = sample_data.variables{ivDepth}.data;
    flagDepth = sample_data.variables{ivDepth}.flags;
    
    qcSet    = str2double(readProperty('toolbox.qc_set'));
    rawFlag  = imosQCFlag('raw',  qcSet, 'flag');
    passFlag = imosQCFlag('good', qcSet, 'flag');
    failFlag = imosQCFlag('bad',  qcSet, 'flag');
    
    % as we use depth information to retrieve climatology data, let's set
    % depth as NaN when depth hasn't been QC'd good.
    iGoodDepth = flagDepth == passFlag;
    dataDepth(~iGoodDepth) = NaN;
    
    climDir = readProperty('importManager.climDir');
    
    % get details from this site
    site = sample_data.meta.site_name; % source = ddb
    if strcmpi(site, 'UNKNOWN'), site = sample_data.site_code; end % source = global_attributes.txt
    clear sample_data;
    
    site = imosSites(site);
    
    % test if site information exists
    if isempty(site)
        fprintf('%s\n', ['Warning : ' 'No site information found to '...
            'perform range QC test']);
    else
        % test if climatology exist
        climFile = fullfile(climDir, ['Clim_' site.name '_2011.nc']);
        if ~exist(climFile, 'file')
            fprintf('%s\n', ['Warning : ' 'No climatology file found '...
                'to perform range QC test']);
        else
            % get date format for netcdf time attributes
            dateFmt = readProperty('exportNetCDF.dateFormat');
            
            % open netCDF file
            ncid = netcdf.open(climFile, 'NC_NOWRITE');
            
            clim = struct;
            
            % get global attributes
            clim.globals = readNetCDFAtts(ncid, netcdf.getConstant('NC_GLOBAL'));
            
            % transform any time attributes into matlab serial dates
            timeAtts = {'date_created', 'time_coverage_start', 'time_coverage_end', ...
                'time_deployment_start', 'time_deployment_end'};
            for k = 1:length(timeAtts)
                
                if isfield(clim.globals, timeAtts{k})
                    
                    % Aargh, matlab is a steamer. Datenum cannot handle a trailing 'Z',
                    % even though it's ISO8601 compliant. I hate you, matlab. Assuming
                    % knowledge of the date format here (dropping the last character).
                    newTime = 0;
                    try
                        newTime = datenum(clim.globals.(timeAtts{k}), dateFmt(1:end-1));
                        
                        % Glider NetCDF files use doubles for
                        % time_coverage_start and time_coverage_end
                    catch e
                        try newTime = clim.globals.(timeAtts{k}) + datenum('1950-01-01 00:00:00');
                        catch e
                        end
                    end
                    clim.globals.(timeAtts{k}) = newTime;
                end
            end
            
            % get dimensions
            k = 0;
            try
                while 1
                    
                    [name len] = netcdf.inqDim(ncid, k);
                    
                    % get id of associated coordinate variable
                    varid = netcdf.inqVarID(ncid, name);
                    
                    k = k + 1;
                    
                    clim.dimensions{k} = readNetCDFVar(ncid, varid);
                end
            catch e
            end
            
            % get variable data/attributes
            k = 0;
            l = 0;
            try
                while 1
                    
                    v = readNetCDFVar(ncid, k);
                    
                    k = k + 1;
                    
                    % skip dimensions - they have
                    % already been added as dimensions
                    if getVar(clim.dimensions, v.name) ~= 0
                        continue;
                    end
                    
                    l = l + 1;
                    
                    % update dimension IDs
                    dims = v.dimensions;
                    v.dimensions = [];
                    for m = 1:length(dims)
                        
                        name = netcdf.inqDim(ncid, dims(m));
                        v.dimensions(l) = getVar(clim.dimensions, name);
                    end
                    
                    % collate qc variables separately
                    if strfind(v.name, '_quality_control'), clim.qcVars   {l} = v;
                    else                                    clim.variables{l} = v;
                    end
                end
            catch e
            end
            
            netcdf.close(ncid);
            
            lenData = length(data);
            
            flags = ones(lenData, 1)*passFlag;
            
            % read step type from morelloRangeNetCDFQC properties file
            maxTimeStdDev = str2double(readProperty('MAX_TIME_SD', fullfile('AutomaticQC', 'morelloRangeNetCDFQC.txt')));
            
            % let's find the nearest depth in climatology
            iClimDepth = 0;
            lenDim = length(clim.dimensions);
            for i=1:lenDim
                if strcmpi(clim.dimensions{i}.name, 'DEPTH'), iClimDepth = i; end
            end
            
            climDepth = clim.dimensions{iClimDepth}.data';
            lenClimDepth = length(climDepth);
            distClimData = abs(repmat(climDepth, lenData, 1) - repmat(dataDepth, 1, lenClimDepth));
            minDistClimData = min(distClimData, [], 2);
            iClimDepth = repmat(minDistClimData, 1, lenClimDepth) == distClimData;
            clear dataDepth distClimData;
            
            % let's find data having more than 1 clim depth and filter
            % only the first clim depth (happens when data point
            % located exactly between 2 climatology depth values).
            cumSumClimDepth = cumsum(iClimDepth, 2);
            i2ClimDepth = cumSumClimDepth == 2;
            if any(any(i2ClimDepth))
                iClimDepth(i2ClimDepth) = false;
            end
            clear cumSumClimDepth i2ClimDepth;
            
            iDepth = nan(lenData, 1);
            depths = nan(lenData, 1);
            for i=1:lenClimDepth
                iDepth(iClimDepth(:, i)) = i;
                depths(iClimDepth(:, i)) = climDepth(i);
            end
            clear iClimDepth;

            % let's find the nearest time bin in climatology
            iClimTimeBounds = 0;
            iClimDataMean = 0;
            iClimDataStd = 0;
            lenVar = length(clim.variables);
            for i=1:lenVar
                if strcmpi(clim.variables{i}.name, 'climatology_bounds'), iClimTimeBounds = i; end
                if strcmpi(clim.variables{i}.name, [dataName '_mean']), iClimDataMean = i; end
                if strcmpi(clim.variables{i}.name, [dataName '_SD']), iClimDataStd = i; end
            end
            climatology_bounds = clim.variables{iClimTimeBounds}.data;
            
            dateRefMin = datestr(datenum(clim.globals.climatology_day_start, 'yyyy-mm-dd'), 'yyyy-01-01');
            dateRefMax = datestr(datenum(clim.globals.climatology_day_end, 'yyyy-mm-dd'), 'yyyy-01-01');
            
            daysSpan = datenum(dateRefMax, 'yyyy-mm-dd') - datenum(dateRefMin, 'yyyy-mm-dd');
            daysBins(:, 1) = climatology_bounds(:, 1);
            daysBins(:, 2) = climatology_bounds(:, 2) - daysSpan;
            lenTimeBins = size(daysBins, 1);
            
            % convert time data in days of year [0 365[ (ex. : January the 1st at 12:00pm is 0.5)
            [dateOrigin, ~, ~, ~, ~, ~] = datevec(dataTime);
            daysOfYear = dataTime - datenum(dateOrigin, 1, 1);
            clear dateOrigin dataTime;
            
            % loop style (less memory issues)
            iBin = false(lenData, lenTimeBins);
            for i=1:lenTimeBins
                startWindow = daysBins(i, 1);
                endWindow = daysBins(i, 2);
                
                iBin(:, i) = daysOfYear >= startWindow;
                iBin(:, i) = iBin(:, i) & (daysOfYear < endWindow);
                
                if startWindow < 0
                    startWindow = 365 + startWindow;
                    iBin(:, i) = iBin(:, i) | (daysOfYear >= startWindow);
                end
                
                if endWindow >= 366
                    endWindow = endWindow - 365;
                    iBin(:, i) = iBin(:, i) | (daysOfYear < endWindow);
                end
            end
            clear daysOfYear;
            
            mean    = clim.variables{iClimDataMean}.data;
            stdDev  = clim.variables{iClimDataStd}.data;
            
            % let's compute range values
            rangeMin = mean - maxTimeStdDev*stdDev;
            rangeMax = mean + maxTimeStdDev*stdDev;
            
            % range test
            dataRangeMin = nan(size(data));
            dataRangeMax = nan(size(data));
            for i=1:lenClimDepth
                for j=1:lenTimeBins
                    iDataDepth = i == iDepth;
                    
                    dataDepth = data(iDataDepth);
                    flagDepth = flags(iDataDepth);
                    dataRangeMinDepth = dataRangeMin(iDataDepth);
                    dataRangeMaxDepth = dataRangeMax(iDataDepth);
                    
                    dataDepthBin = dataDepth(iBin(iDataDepth, j));
                    flagDepthBin = flagDepth(iBin(iDataDepth, j));
                    dataRangeMinDepthBin = dataRangeMinDepth(iBin(iDataDepth, j));
                    dataRangeMaxDepthBin = dataRangeMaxDepth(iBin(iDataDepth, j));
                    
                    if ~isempty(dataDepthBin)
                        dataRangeMinDepthBin = rangeMin(j, i);
                        dataRangeMaxDepthBin = rangeMax(j, i);
                        
                        iBadData = dataDepthBin < dataRangeMinDepthBin;
                        iBadData = iBadData | dataDepthBin > dataRangeMaxDepthBin;
                        
                        dataRangeMinDepth(iBin(iDataDepth, j)) = dataRangeMinDepthBin;
                        dataRangeMaxDepth(iBin(iDataDepth, j)) = dataRangeMaxDepthBin;
                        dataRangeMin(iDataDepth) = dataRangeMinDepth;
                        dataRangeMax(iDataDepth) = dataRangeMaxDepth;
                        
                        if any(iBadData)
                            flagDepthBin(iBadData) = failFlag;
                            flagDepth(iBin(iDataDepth, j)) = flagDepthBin;
                            flags(iDataDepth) = flagDepth;
                        end
                    end
                end
            end
            
            % for test in display
%             mWh = findobj('Tag', 'mainWindow');
%             morelloRange = get(mWh, 'UserData');
%             morelloRange.rangeDEPTH = depths;
%             if strcmpi(dataName, 'TEMP')
%                 morelloRange.rangeMinT = dataRangeMin;
%                 morelloRange.rangeMaxT = dataRangeMax;
%             elseif strcmpi(dataName, 'PSAL')
%                 morelloRange.rangeMinS = dataRangeMin;
%                 morelloRange.rangeMaxS = dataRangeMax;
%             elseif strcmpi(dataName, 'DOX2')
%                 morelloRange.rangeMinDO = dataRangeMin;
%                 morelloRange.rangeMaxDO = dataRangeMax;
%             end
%             set(mWh, 'UserData', morelloRange);
            
            % let's non QC data points too far in depth from
            % climatology depth values
            distMaxDepth = 10;
            iClimDepthTooFar = minDistClimData > distMaxDepth;
            if any(iClimDepthTooFar)
                flags(iClimDepthTooFar) = rawFlag;
                fprintf('%s\n', ['Warning : ' 'some data points '...
                    'are located further than ' num2str(distMaxDepth)...
                    'm in depth from the depth values climatology and '...
                    'won''t be QC''d']);
            end
        end
    end
end