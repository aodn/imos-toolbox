function [data, flags, paramsLog] = imosImpossibleDepthQC( sample_data, data, k, type, auto )
%IMOSIMPOSSIBLEDEPTHQC Flags PRES, PRES_REL and DEPTH impossible values in
% the given data set.
%
% Impossible depth test compares the actual depth of the instruments to its
% nominal depth. If actual depth values don't fall into an acceptable range
% of values around the nominal depth then they are flagged.
%
% Acceptable ranges are derived from this formula :
%
% instrument_nominal_depth +/- coefficient * (site_nominal_depth / instrument_nominal_depth) 
%
% Distinct coefficient values can be defined for upper and lower threshold.
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
if ~isvector(data) && ~ismatrix(data),  error('data must be a vector or matrix');   end
if ~isscalar(k) || ~isnumeric(k),       error('k must be a numeric scalar');        end
if ~ischar(type),                       error('type must be a string');             end

% auto logical in input to enable running under batch processing
if nargin<5, auto=false; end

paramsLog = [];
flags     = [];

if ~strcmp(type, 'variables'), return; end

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

if strcmpi(paramName, 'PRES') || ...
        strcmpi(paramName, 'PRES_REL')|| ...
        strcmpi(paramName, 'DEPTH')
   
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
    rawFlag  = imosQCFlag('raw', qcSet, 'flag');
    passFlag = imosQCFlag('good', qcSet, 'flag');
    failFlag = imosQCFlag('bad',  qcSet, 'flag');
    
    % matrix case, we unfold the matrix in one vector for timeserie study
    % purpose
    isMatrix = ismatrix(data);
    if isMatrix
        len1 = size(data, 1);
        len2 = size(data, 2);
        data = data(:);
    end
    lenData = length(data);
    
    % get nominal depth and nominal offset information
    nominalData = [];
    nominalOffset = [];
    
    if isfield(sample_data, 'instrument_nominal_depth')
        nominalData = sample_data.instrument_nominal_depth;
        if isfield(sample_data, 'site_nominal_depth')
            nominalOffset = sample_data.site_nominal_depth / nominalData;
        elseif isfield(sample_data, 'site_depth_at_deployment')
            nominalOffset = sample_data.site_depth_at_deployment / nominalData;
        end
    elseif isfield(sample_data, 'instrument_nominal_height') ...
            && isfield(sample_data, 'site_nominal_depth')
        nominalData = sample_data.site_nominal_depth - ...
            sample_data.instrument_nominal_height;
        nominalOffset = sample_data.site_nominal_depth / nominalData;
    elseif isfield(sample_data, 'instrument_nominal_height') ...
            && isfield(sample_data, 'site_depth_at_deployment')
        nominalData = sample_data.site_depth_at_deployment - ...
            sample_data.instrument_nominal_height;
        nominalOffset = sample_data.site_depth_at_deployment / nominalData;
    end
    
    if isempty(nominalData) || isempty(nominalOffset)
        fprintf('%s\n', ['Warning : ' 'Not enough instrument and/or site ' ...
            'nominal/actual depth/height metadata found to perform impossible ' ...
            'depth QC test.']);
        fprintf('%s\n', ['Please make sure global_attributes ' ...
            'instrument_nominal_depth, or instrument_nominal_height and ' ...
            'site_nominal_depth or site_depth_at_deployment are documented.']);
        return;
    end
    
    % read coefficients from imosImpossibleDepthQC properties file
    coefUp      = readProperty('coefUp',    fullfile('AutomaticQC', 'imosImpossibleDepthQC.txt'));
    coefDown    = readProperty('coefDown',  fullfile('AutomaticQC', 'imosImpossibleDepthQC.txt'));
    
    paramsLog = ['coefUp=' coefUp ', coefDown=' coefDown];
    
    coefUp      = str2double(coefUp);
    coefDown    = str2double(coefDown);
    
    % get possible min/max values
    possibleMax = nominalData + coefDown*nominalOffset;
    possibleMin = nominalData - coefUp*nominalOffset;
    
    % possibleMin shouldn't be higher than the surface but this is handled by
    % the global range test anyway.
    % possibleMax cannot be lower than the site depth
    siteDepth = nominalOffset*nominalData;
    possibleMax = min(possibleMax, siteDepth + 10*siteDepth/100); % we allow +10% to the site Depth
    
    if strcmpi(paramName, 'PRES')
        % convert depth into absolute pressure assuming 1 dbar ~= 1 m and
        % nominal atmospheric pressure ~= 10.1325 dBar
        possibleMin = possibleMin + 10.1325;
        possibleMax = possibleMax + 10.1325;
        nominalData = nominalData + 10.1325;
    elseif strcmpi(paramName, 'PRES_REL')
        % convert depth into relative pressure assuming 1 dbar ~= 1 m
        % Nothing to do!
    end
    
    paramsLog = [paramsLog ' => min=' num2str(possibleMin) ', max=' num2str(possibleMax)];
    
    % initially all data is bad
    flags = ones(lenData, 1)*failFlag;
    
    iPossible = data <= possibleMax;
    if (possibleMin < 0) % cannot be out of water
        iPossible = iPossible & (data >= 0);
    else
        iPossible = iPossible & (data >= possibleMin);
    end
    
    if any(iPossible)
        flags(iPossible) = passFlag;
    end
    
    if isMatrix
        % we fold the vector back into a matrix
        data = reshape(data, len1, len2);
        flags = reshape(flags, len1, len2);
    end
    
    % update climatologyRange info for display
    climatologyRange(p).(['range' paramName]) = [nominalData; nominalData];
    climatologyRange(p).(['rangeMin' paramName]) = [possibleMin; possibleMin];
    climatologyRange(p).(['rangeMax' paramName]) = [possibleMax; possibleMax];
    set(mWh, 'UserData', climatologyRange);
end