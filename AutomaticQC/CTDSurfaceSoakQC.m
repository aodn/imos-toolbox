function [data, flags, paramsLog] = CTDSurfaceSoakQC( sample_data, data, k, type, auto )
%IMOSINOUTWATERQC Flags samples which were taken before and after the instrument was placed
% in the water.
%
% Flags all samples from the data depending on surface Soak parameters
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
%   flags       - Vector the same size as data, with bad surface soak and
%                 pump samples flagged
%
%   paramsLog   - string containing details about params' procedure to include in QC log
%
% Author:       Charles James (charles.james@sa.gov.au)
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

% this test don't apply on dimensions for timeseries data
if isfield(sample_data, 'featureType')
    % not for time series
    if strcmpi(sample_data.featureType, 'timeSeries')
        return;
    end
else
    % if doubt we don't allow test on any dimension
    if ~strcmp(type, 'variables'), return; end
end

iSBE = getVar(sample_data.variables,'SBE_FLAG');
if ~isempty(iSBE)
    sbe_flag = sample_data.variables{iSBE}.data; % any SBE flag 0 is good and NaN is bad.
else
    sbe_flag = zeros(size(data));
end

% soak status
iTSS = getVar(sample_data.variables, 'tempSoakStatus');
iCSS = getVar(sample_data.variables, 'cndSoakStatus');
iOSS = getVar(sample_data.variables, 'oxSoakStatus');

% only concerned here with pumped sensors or variables derived from pumped
% observations
pumpedVar = {'TEMP', 'CNDC', 'DOX', 'DOXY', 'DOX1', 'DOX2', 'DOXS', 'PSAL', 'DENS'};
ignoreVar = {'TIME', 'PROFILE', 'DIRECTION', 'LATITUDE', 'LONGITUDE', 'BOT_DEPTH', 'ETIME'};

qcSet = str2double(readProperty('toolbox.qc_set'));
rawFlag  = imosQCFlag('raw', qcSet, 'flag');
failFlag = imosQCFlag('bad', qcSet, 'flag');

% Set all data that passed SBE processing with raw flags
iSkip   = ismember(ignoreVar, sample_data.variables{k}.name);
iPumped = ismember(pumpedVar, sample_data.variables{k}.name);
if ~any(iSkip)
    lenData = length(data);
    flags = ones(lenData, 1, 'int8')*rawFlag;
    if any(iPumped)
        % initially all data is raw
        switch pumpedVar{iPumped};
            case 'TEMP' % temperature
                if ~isempty(iTSS)
                    flags = sample_data.variables{iTSS}.data;
                end
            case {'CNDC', 'PSAL', 'DENS'} % dependent on conductivity
                if ~isempty(iCSS)
                    flags = sample_data.variables{iCSS}.data;
                end
            case {'DOX', 'DOXY', 'DOX1', 'DOX2', 'DOXS'} % dependent on oxygen
                if ~isempty(iOSS)
                    flags = sample_data.variables{iOSS}.data;
                end
        end
    end
    
    % On top of the soak status flag, we add the SBE flag information
    if ~isempty(sbe_flag)
        flags(isnan(sbe_flag)) = failFlag; % any SBE flag 0 is good and NaN is bad.
    end
    
    % transform flags to the appropriate output shape
    sizeData = size(data);
    flags = repmat(flags, [1 sizeData(2:end)]);
end
end