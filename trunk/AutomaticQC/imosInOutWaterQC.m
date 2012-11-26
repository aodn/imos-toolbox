function [data flags paramsLog] = imosInOutWaterQC( sample_data, data, k, type, auto )
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

% this test don't apply on dimensions for timeseries data
if isfield(sample_data, 'featureType')
    if strcmpi(sample_data.featureType, 'timeSeries')
        if ~strcmp(type, 'variables'), return; end
    end
else
    % if doubt we don't allow test on any dimension
    if ~strcmp(type, 'variables'), return; end
end

time_in_water = sample_data.time_deployment_start;
time_out_water = sample_data.time_deployment_end;

if isempty(time_in_water), return; end
if isempty(time_out_water), return; end

tTime = 'dimensions';
iTime = getVar(sample_data.(tTime), 'TIME');
if iTime == 0
    tTime = 'variables';
    iTime = getVar(sample_data.(tTime), 'TIME');
    if iTime == 0, return; end
end
time = sample_data.(tTime){iTime}.data;

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
end

% transform flags to the appropriate output shape
sizeData = size(data);
sizeData(sizeData == lenData) = 1;
flags = repmat(flags, sizeData);