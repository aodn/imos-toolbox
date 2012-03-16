function [data, flags, log] = imosImpossibleDepthQC( sample_data, data, k, type, auto )
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

if strcmpi(sample_data.(type){k}.name, 'PRES') || ...
        strcmpi(sample_data.(type){k}.name, 'PRES_REL')|| ...
        strcmpi(sample_data.(type){k}.name, 'DEPTH')
   
    qcSet    = str2double(readProperty('toolbox.qc_set'));
    rawFlag  = imosQCFlag('raw', qcSet, 'flag');
    passFlag = imosQCFlag('good', qcSet, 'flag');
    failFlag = imosQCFlag('probablyBad',  qcSet, 'flag');
    
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
    coefUp      = str2double(coefUp);
    coefDown    = readProperty('coefDown',  fullfile('AutomaticQC', 'imosImpossibleDepthQC.txt'));
    coefDown    = str2double(coefDown);
    
    % get possible min/max values
    possibleMax = nominalData + coefDown*nominalOffset;
    possibleMin = nominalData - coefUp*nominalOffset;
    
    if strcmpi(sample_data.(type){k}.name, 'PRES')
        % convert depth into absolute pressure assuming 1 dbar ~= 1 m and
        % nominal atmospheric pressure ~= 10.1325 dBar
        possibleMin = possibleMin + 10.1325;
        possibleMax = possibleMax + 10.1325;
    elseif strcmpi(sample_data.(type){k}.name, 'PRES_REL')
        % convert depth into relative pressure assuming 1 dbar ~= 1 m
        % Nothing to do!
    end
    
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
end