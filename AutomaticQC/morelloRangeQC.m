function [data, flags, log] = morelloRangeQC( sample_data, data, k, type, auto )
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

if strcmpi(sample_data.(type){k}.name, 'TEMP') || ...
        strcmpi(sample_data.(type){k}.name, 'PSAL')
    
    % we'll need time and depth information
    idTime  = getVar(sample_data.dimensions, 'TIME');
    ivDepth = getVar(sample_data.variables, 'DEPTH');
    if ivDepth == 0
        warning('No depth information found to perform range QC test');
        return;
    end
    dataTime  = sample_data.dimensions{idTime}.data;
    dataDepth = sample_data.variables{ivDepth}.data;
    
    climDir = readProperty('importManager.climDir');
    
    % get details from this site
    site = sample_data.meta.site_name; % source = ddb
    if strcmpi(site, 'UNKNOWN'), site = sample_data.site_code; end % source = global_attributes.txt
    
    site = imosSites(site);
    
    % test if site information exists
    if isempty(site)
        warning('No site information found to perform range QC test');
    else
        % test if climatology exist
        climFile = fullfile(climDir, site.name, 'clim_output.mat');
        if ~exist(climFile, 'file')
            warning('No climatology file found to perform range QC test');
        else
            clim = load(climFile);
            
            % read step type from morelloRangeQC properties file
            stepType = readProperty('CLIM_STEP', fullfile('AutomaticQC', 'morelloRangeQC.txt'));
            if all(~strcmpi(stepType, {'monthly', 'daily'}))
                warning(['CLIM_STEP : ' stepType ' in morelloRangeQC.txt is not supported to perform range QC test']);
            else
                if strcmpi(stepType, 'monthly')
                    % test if needed information is available
                    if ~all(isfield(clim, {'monmn', 'monsd'}))
                        warning('monmn and/or monsd variables are missing in climatology file');
                        return;
                    end
                elseif strcmpi(stepType, 'daily')
                    if ~all(isfield(clim, {'monmn', 'monsd', 'dm', 'tf_coef'}))
                        warning('monmn, monsd, dm and/or tfcoef variables are missing in climatology file');
                        return;
                    else
                        if ~all(isfield(clim.tf_coef, {'mn', 'an', 'sa', 'tco', 't2co'}))
                            warning('tf_coef.mn, tf_coef.an, tf_coef.sa, tf_coef.tco and/or tf_coef.t2co variables are missing in climatology file');
                            return;
                        end
                    end
                end
                
                qcSet    = str2double(readProperty('toolbox.qc_set'));
                rawFlag  = imosQCFlag('raw',  qcSet, 'flag');
                passFlag = imosQCFlag('good', qcSet, 'flag');
                failFlag = imosQCFlag('bad',  qcSet, 'flag');
                
                lenData = length(data);
                
                flags = ones(lenData, 1)*passFlag;
                
                % let's find the nearest depth in climatology
                lenClimDepth = length(clim.depth);
                climDepth = repmat(clim.depth, lenData, 1);
                distClimData = abs(climDepth - repmat(dataDepth, 1, lenClimDepth));
                minDistClimData = min(distClimData, [], 2);
                iClimDepth = repmat(minDistClimData, 1, lenClimDepth) == distClimData;
                clear climDepth distClimData;
                
                % let's find data having more than 1 clim depth and filter
                % only the first clim depth (happens when data point
                % located exactly between 2 climatology depth values).
                cumSumClimDepth = cumsum(iClimDepth, 2);
                i2ClimDepth = cumSumClimDepth == 2;
                if any(any(i2ClimDepth))
                    iClimDepth(i2ClimDepth) = false;
                end
                clear cumSumClimDepth i2ClimDepth;
                
                iDepth = repmat((1:1:lenClimDepth), lenData, 1);
                iDepth = iDepth(iClimDepth);
                clear iClimDepth;
                
                if strcmpi(sample_data.(type){k}.name, 'TEMP')
                    mean    = squeeze(clim.monmn(1, iDepth, :));
                    meanCor = squeeze(clim.mncor(1, iDepth))';
                    stdDev  = squeeze(clim.monsd(1, iDepth, :));
                    tf_coef = squeeze(clim.tf_coef(1, iDepth))';
                elseif strcmpi(sample_data.(type){k}.name, 'PSAL')
                    mean    = squeeze(clim.monmn(2, iDepth, :));
                    meanCor = squeeze(clim.mncor(2, iDepth))';
                    stdDev  = squeeze(clim.monsd(2, iDepth, :));
                    tf_coef = squeeze(clim.tf_coef(2, iDepth))';
                end
                
                if strcmpi(stepType, 'monthly')
                    % let's find the nearest month in climatology
                    [~, iMonth, ~, ~, ~, ~] = datevec(dataTime');
                    lenMonths = length(clim.monmn(1, 1, :));
                    months = (1:1:lenMonths);
                    months = repmat(months, lenData, 1);
                    iMonth = repmat(iMonth, 1, lenMonths);
                    iMonth = iMonth == months;
                    clear months;
                    
                    mean    = mean(iMonth);
                    stdDev  = stdDev(iMonth);
                    clear iMonth;
                    
                elseif strcmpi(stepType, 'daily')
                    % let's compute interpolated daily mean
                    [baseyear, ~, ~, ~, ~, ~] = datevec(dataTime');
                    dtime = dataTime' - datenum(baseyear, 1, 1);

                    meanInterp      = nan(lenData, 1);
                    stdDevInterp    = nan(lenData, 1);
                    mn              = nan(lenData, 1);
                    an              = nan(lenData, 1);
                    sa              = nan(lenData, 1);
                    tco             = nan(lenData, 1);
                    t2co            = nan(lenData, 1);
                    for i=1:lenData
                        meanInterp(i)   = interp1(clim.dm, mean(i, :),   dtime(i));
                        stdDevInterp(i) = interp1(clim.dm, stdDev(i, :), dtime(i));
                        mn(i)           = tf_coef(i).mn;
                        an(i)           = tf_coef(i).an;
                        sa(i)           = tf_coef(i).sa;
                        tco(i)          = tf_coef(i).tco;
                        t2co(i)         = tf_coef(i).t2co;
                    end
                    
%                     meanInterp(i) = interp1(clim.dm, mean', dtime');
                    
                    % Apply corrections on interpolated mean
                    % read method type from morelloRangeQC properties file
                    method = readProperty('DAILY_METHOD', fullfile('AutomaticQC', 'morelloRangeQC.txt'));
            
                    if strcmpi(method, 'trend_corr')
                        % first method
                        mean = meanInterp;
                        iNaN = isnan(meanCor);
                        mean(~iNaN) = meanInterp(~iNaN) + meanCor(~iNaN) + tco(~iNaN).*dtime(~iNaN)/365.25 + t2co(~iNaN).*(dtime(~iNaN)/365.25).^2;
                    elseif strcmpi(method, 'harmonic')
                        % second method
                        i = sqrt(-1);
                        idy =   i * 2 * pi * dtime / 366;
                        mean = meanInterp;
                        iNaN = isnan(mn);
                        mean(~iNaN) = mn(~iNaN) + real(an(~iNaN).*exp(idy(~iNaN)))+ real(sa(~iNaN).*exp(2*idy(~iNaN)));
                    else
                        % linear interpolation
                        mean = meanInterp;
                    end
                    
                    stdDev = stdDevInterp;
                end
                
                % read step type from morelloRangeQC properties file
                maxTimeStdDev = str2double(readProperty('MAX_TIME_SD', fullfile('AutomaticQC', 'morelloRangeQC.txt')));
                
                % let's compute range values
                rangeMin = mean - maxTimeStdDev*stdDev;
                rangeMax = mean + maxTimeStdDev*stdDev;
                
                % for test in display
%                 mWh = findobj('Tag', 'mainWindow');
%                 morelloRange = get(mWh, 'UserData');
%                 if strcmpi(sample_data.(type){k}.name, 'TEMP')
%                     morelloRange.meanT = mean;
%                     morelloRange.rangeMinT = rangeMin;
%                     morelloRange.rangeMaxT = rangeMax;
%                 elseif strcmpi(sample_data.(type){k}.name, 'PSAL')
%                     morelloRange.meanS = mean;
%                     morelloRange.rangeMinS = rangeMin;
%                     morelloRange.rangeMaxS = rangeMax;
%                 end
%                 set(mWh, 'UserData', morelloRange);
                
                % range test
                iBadData = data < rangeMin;
                iBadData = iBadData | data > rangeMax;
                
                if any(iBadData)
                    flags(iBadData) = failFlag;
                end
                
                % let's non QC data points too far in depth from
                % climatology depth values
                distMaxDepth = 10;
                iClimDepthTooFar = minDistClimData > distMaxDepth;
                if any(iClimDepthTooFar)
                    flags(iClimDepthTooFar) = rawFlag;
                    warning(['some data points are located further than ' distMaxDepth 'm in depth from the depth values climatology and won''t be QC''d']);
                end
            end
        end
    end
end