function [data, flags, paramsLog] = imosImpossibleDepthQC( sample_data, data, k, type, auto )
%IMOSIMPOSSIBLEDEPTHQC Flags PRES, PRES_REL and DEPTH impossible values in
% the given data set.
%
% Impossible depth test compares the actual depth of the instruments to an
% acceptable range of values around the nominal depth. If they don't fall
% within that range then they are flagged.
%
% Acceptable ranges are derived from this formula :
%
% upperRange = instrumentNominalDepth - zNominalMargin
% lowerRange = instrumentNominalDepth + zNominalMargin + ...
%   (siteNominalDepth - (instrumentNominalDepth + zNominalMargin)) * ...
%   (1 - cos(maxAngle * pi/180))
%
% zNominalMargin is the acceptable difference between the expected instrument 
% nominal depth and its actual depth when deployed (mooring being ideally 
% vertical).
%
% maxAngle is the maximum angle from the vertical axis that the mooring 
% line can reach in highest current speed conditions.
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

% this test only applies on DEPTH, PRES, and PRES_REL
depthInfos = {'DEPTH', 'PRES_REL', 'PRES'};
if ~any(strcmpi(paramName, depthInfos)), return; end

% get the toolbox execution mode
mode = readProperty('toolbox.mode');

switch mode
    case 'profile'
        % in this case we mainly aim at checking that depth/pressure values
        % are betwwen 0 and BOT_DEPTH +20%
        iBotDepth = getVar(sample_data.variables, 'BOT_DEPTH');
        botDepth = max(sample_data.variables{iBotDepth}.data);
        
        if isnan(botDepth)
            fprintf('%s\n', ['Warning : ' 'Not enough site ' ...
                'nominal/actual depth metadata found to perform impossible ' ...
                'depth QC test.']);
            fprintf('%s\n', ['Please make sure global_attributes ' ...
                'site_nominal_depth or site_depth_at_station are documented.']);
            return;
        end
        
        margin = 20/100;
        botDepth = botDepth + margin*botDepth;
        
        if any(strcmpi(paramName, {'PRES', 'PRES_REL'}))
            if ~isempty(sample_data.geospatial_lat_min) && ~isempty(sample_data.geospatial_lat_max)
                % compute pres_rel with Gibbs-SeaWater toolbox
                % relative_pressure ~= gsw_p_from_z(-depth, latitude)
                if sample_data.geospatial_lat_min == sample_data.geospatial_lat_max
                    latVal = sample_data.geospatial_lat_min;
                else
                    latVal = sample_data.geospatial_lat_min + ...
                        (sample_data.geospatial_lat_max - sample_data.geospatial_lat_min)/2;
                end
                botDepth = gsw_p_from_z(-botDepth, latVal);
            else
                % without latitude information, we assume 1dbar ~= 1m
                fprintf('%s\n', ['Warning : ' 'Not enough location metadata ' ...
                    'found to perform correct impossible depth QC test. 1dbar ~= 1m has been assumed.']);
                fprintf('%s\n', ['Please make sure global_attributes ' ...
                    'geospatial_lat_min and geospatial_lat_max ' ...
                    'are documented.']);
            end
        end
        
        if strcmpi(paramName, 'PRES')
            % we assume nominal atmospheric pressure ~= 10.1325 dBar (gsw_P0/10^4)
            botDepth = botDepth + gsw_P0/10^4;
        end
        
        if strcmpi(type, 'dimensions')
            % test against surface
            if any(data < 0)
                error(['Some ' sample_data.(type){k}.name ' values are above the surface ' ...
                    '=> Check your processing http://help.aodn.org.au/help/sites/help.aodn.org.au/' ...
                    'files/ANMN%20CTD%20Processing%20Procedures.pdf']);
            end
                                    
            % test against bottom
            if any(data > botDepth)
                error(['Some ' sample_data.(type){k}.name ' values are below the bottom +20% ' ...
                    '=> Check ddb site_nominal_depth or site_depth_at_station']);
%                 fprintf('%s\n', ['Warning : ' 'Some ' sample_data.(type){k}.name ' values are below the bottom +20% ' ...
%                     '=> Check ddb site_nominal_depth or site_depth_at_station.']);
            end
        else
            % we deal with variables that have ancillary QC variables.
            qcSet    = str2double(readProperty('toolbox.qc_set'));
            passFlag = imosQCFlag('good', qcSet, 'flag');
            failFlag = imosQCFlag('bad',  qcSet, 'flag');
            
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
            
            % initially all data is bad
            flags = ones(lenData, 1, 'int8')*failFlag;
            
            iPossible = data <= botDepth;
            iPossible = iPossible & (data >= 0);
            
            if any(iPossible)
                flags(iPossible) = passFlag;
            end
            
            if isMatrix
                % we fold the vector back into a matrix
                data = reshape(data, [len1, len2, len3]);
                flags = reshape(flags, [len1, len2, len3]);
            end
        end
        
    case 'timeSeries'
        % this test doesn't apply on dimensions
        if ~strcmp(type, 'variables'), return; end
        
        sampleFile = sample_data.toolbox_input_file;
        
        % for test in display
        mWh = findobj('Tag', 'mainWindow');
        climatologyRange = get(mWh, 'UserData');
        p = 0;
        if isempty(climatologyRange)
            p = 1;
            climatologyRange(p).dataSet = sampleFile;
            climatologyRange(p).(['range' paramName]) = nan(2, 1);
            climatologyRange(p).(['rangeMin' paramName]) = nan(2, 1);
            climatologyRange(p).(['rangeMax' paramName]) = nan(2, 1);
        else
            for i=1:length(climatologyRange)
                if strcmp(climatologyRange(i).dataSet, sampleFile)
                    p=i;
                    break;
                end
            end
            if p == 0
                p = length(climatologyRange) + 1;
                climatologyRange(p).dataSet = sampleFile;
                climatologyRange(p).(['range' paramName]) = nan(2, 1);
                climatologyRange(p).(['rangeMin' paramName]) = nan(2, 1);
                climatologyRange(p).(['rangeMax' paramName]) = nan(2, 1);
            end
        end
        
        qcSet    = str2double(readProperty('toolbox.qc_set'));
        passFlag = imosQCFlag('good', qcSet, 'flag');
        failFlag = imosQCFlag('bad',  qcSet, 'flag');
        
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
        
        % read coefficients from imosImpossibleDepthQC properties file
        zNominalMargin  = readProperty('zNominalMargin',    fullfile('AutomaticQC', 'imosImpossibleDepthQC.txt'));
        maxAngle        = readProperty('maxAngle',          fullfile('AutomaticQC', 'imosImpossibleDepthQC.txt'));
        
        zNominalMargin  = str2double(zNominalMargin);
        maxAngle        = str2double(maxAngle);
        
        % read dataset QC parameters if exist and override previous 
        % parameters file
        currentQCtest   = mfilename;
        zNominalMargin  = readQCparameter(sample_data.toolbox_input_file, currentQCtest, 'zNominalMargin', zNominalMargin);
        maxAngle        = readQCparameter(sample_data.toolbox_input_file, currentQCtest, 'maxAngle', maxAngle);
        
        paramsLog = ['zNominalMargin=' num2str(zNominalMargin) ', maxAngle=' num2str(maxAngle)];
        
        % get nominal depths information
        instrumentNominalDepth = [];
        siteNominalDepth = [];
        
        if ~isempty(sample_data.instrument_nominal_depth)
            instrumentNominalDepth = sample_data.instrument_nominal_depth;
            if ~isempty(sample_data.site_nominal_depth)
                siteNominalDepth = sample_data.site_nominal_depth;
            elseif ~isempty(sample_data.site_depth_at_deployment)
                siteNominalDepth = sample_data.site_depth_at_deployment;
            end
        elseif ~isempty(sample_data.instrument_nominal_height)
            if ~isempty(sample_data.site_nominal_depth)
                instrumentNominalDepth = sample_data.site_nominal_depth - ...
                    sample_data.instrument_nominal_height;
                siteNominalDepth = sample_data.site_nominal_depth;
            elseif ~isempty(sample_data.site_depth_at_deployment)
                instrumentNominalDepth = sample_data.site_depth_at_deployment - ...
                    sample_data.instrument_nominal_height;
                siteNominalDepth = sample_data.site_depth_at_deployment;
            end
        end
        
        if isempty(instrumentNominalDepth) || isempty(siteNominalDepth)
            fprintf('%s\n', ['Warning : ' 'Not enough instrument and/or site ' ...
                'nominal/actual depth/height metadata found to perform impossible ' ...
                'depth QC test.']);
            fprintf('%s\n', ['Please make sure global_attributes ' ...
                'instrument_nominal_depth, or instrument_nominal_height and ' ...
                'site_nominal_depth or site_depth_at_deployment are documented.']);
            return;
        end
        
        %     paramsLog = [paramsLog ', instrument_nominal_depth=' num2str(instrumentNominalDepth) ', site_nominal_depth=' num2str(siteNominalDepth)];
        
        % get possible min/max values
        possibleMin = instrumentNominalDepth - zNominalMargin;
        possibleMax = instrumentNominalDepth + zNominalMargin;
        
        % get deltaZ from knock down event. Is greater when closer to surface.
        deltaZMax = (siteNominalDepth - possibleMin) * ...
            (1 - cos(maxAngle * pi/180));
        
        % we are considering the possibility of deltaZMax being applied to possibleMax
        % (should only be relevant in the case of possibleMin but gives broader boundaries)
        possibleMax = possibleMax + deltaZMax;
        % cannot be out of water
        possibleMin = max(0, possibleMin);
        
        % possibleMin shouldn't be above the surface (~global range value)
        % possibleMax cannot be below the site depth
        possibleMin = max(possibleMin, imosParameters('DEPTH', 'valid_min')); % value from global range
        possibleMax = min(possibleMax, siteNominalDepth + 20*siteNominalDepth/100); % we allow +20% to the nominal site depth
        
        if any(strcmpi(paramName, {'PRES', 'PRES_REL'}))
            if ~isempty(sample_data.geospatial_lat_min) && ~isempty(sample_data.geospatial_lat_max)
                % compute depth with Gibbs-SeaWater toolbox
                % relative_pressure ~= gsw_p_from_z(-depth, latitude)
                if sample_data.geospatial_lat_min == sample_data.geospatial_lat_max
                    possibleMin             = gsw_p_from_z(-possibleMin, sample_data.geospatial_lat_min);
                    possibleMax             = gsw_p_from_z(-possibleMax, sample_data.geospatial_lat_min);
                    instrumentNominalDepth  = gsw_p_from_z(-instrumentNominalDepth, sample_data.geospatial_lat_min);
                else
                    meanLat = sample_data.geospatial_lat_min + ...
                        (sample_data.geospatial_lat_max - sample_data.geospatial_lat_min)/2;
                    possibleMin             = gsw_p_from_z(-possibleMin, meanLat);
                    possibleMax             = gsw_p_from_z(-possibleMax, meanLat);
                    instrumentNominalDepth  = gsw_p_from_z(-instrumentNominalDepth, meanLat);
                end
            else
                % without latitude information, we assume 1dbar ~= 1m
                fprintf('%s\n', ['Warning : ' 'Not enough location metadata ' ...
                    'found to perform correct impossible depth QC test. 1dbar ~= 1m has been assumed.']);
                fprintf('%s\n', ['Please make sure global_attributes ' ...
                    'geospatial_lat_min and geospatial_lat_max ' ...
                    'are documented.']);
            end
            
            if strcmpi(paramName, 'PRES')
                % we assume nominal atmospheric pressure ~= 10.1325 dBar (gsw_P0/10^4)
                possibleMin = possibleMin + gsw_P0/10^4;
                possibleMax = possibleMax + gsw_P0/10^4;
                instrumentNominalDepth = instrumentNominalDepth + gsw_P0/10^4;
            end
        end
        
        paramsLog = [paramsLog ' => min=' num2str(possibleMin) ', max=' num2str(possibleMax)];
        %     disp(paramsLog);
        
        % initially all data is bad
        flags = ones(lenData, 1, 'int8')*failFlag;
        
        iPossible = data <= possibleMax;
        iPossible = iPossible & (data >= possibleMin);
        
        if any(iPossible)
            flags(iPossible) = passFlag;
        end
        
        if isMatrix
            % we fold the vector back into a matrix
            data = reshape(data, [len1, len2, len3]);
            flags = reshape(flags, [len1, len2, len3]);
        end
        
        % write/update dataset QC parameters
        writeQCparameter(sample_data.toolbox_input_file, currentQCtest, 'zNominalMargin', zNominalMargin);
        writeQCparameter(sample_data.toolbox_input_file, currentQCtest, 'maxAngle', maxAngle);
        
        % update climatologyRange info for display
        climatologyRange(p).(['range' paramName]) = [instrumentNominalDepth; instrumentNominalDepth];
        climatologyRange(p).(['rangeMin' paramName]) = [possibleMin; possibleMin];
        climatologyRange(p).(['rangeMax' paramName]) = [possibleMax; possibleMax];
        set(mWh, 'UserData', climatologyRange);
    
end
