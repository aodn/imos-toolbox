function [data, flags, log] = morelloImpossibleLocationQC( sample_data, data, k, type, auto )
%MORELLOIMPOSSIBLELOCATION Flags impossible Latitude and Longitude values 
% using IMOS sites information in imosSites.txt.
%
% Impossible location test described in Morello et Al. 2011 paper.
%
% Inputs:
%   sample_data - struct containing the data set.
%
%   data        - the vector of data to check.
%
%   k           - Index into the sample_data dimensions/variables vector.
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

dataLon = [];
dataLat = [];
flags   = [];

qcSet    = str2double(readProperty('toolbox.qc_set'));
passFlag = imosQCFlag('good',           qcSet, 'flag');
failFlag = imosQCFlag('probablyBad',    qcSet, 'flag');

if strcmpi(sample_data.(type){k}.name, 'LONGITUDE')
    dataLon = sample_data.(type){k}.data;
end

if strcmpi(sample_data.(type){k}.name, 'LATITUDE')
    dataLat = sample_data.(type){k}.data;
end

if ~isempty(dataLon) || ~isempty(dataLat)
    % get details from this site
    site = sample_data.meta.site_name; % source = ddb
    if strcmpi(site, 'UNKNOWN'), site = sample_data.site_code; end % source = global_attributes.txt
    
    site = imosSites(site);
    
    % test if site information exists
    if isempty(site)
        warning('No site information found to perform impossible location QC test');
    else
        if ~isempty(dataLon)
            lenData = length(dataLon);
        end
        
        if ~isempty(dataLat)
            lenData = length(dataLat);
        end
        
        % initially all data is good
        flags = ones(lenData, 1)*passFlag;
        
        %test location
        if ~isempty(dataLon)
            if isnan(site.distanceKmPlusMinusThreshold)
                iBadLon = dataLon < site.longitude - site.longitudePlusMinusThreshold || ...
                    dataLon > site.longitude + site.longitudePlusMinusThreshold;
            else
                [~, longitudeMax] = WGS84reckon(site.latitude*pi/180, site.longitude*pi/180, ...
                    site.distanceKmPlusMinusThreshold*1000, pi/2);
                [~, longitudeMin] = WGS84reckon(site.latitude*pi/180, site.longitude*pi/180, ...
                    site.distanceKmPlusMinusThreshold*1000, -pi/2);
                iBadLon = dataLon < longitudeMin*180/pi || dataLon > longitudeMax*180/pi;
            end
            
            if any(iBadLon)
                flags(iBadLon) = failFlag;
            end
        end
        
        if ~isempty(dataLat)
            if isnan(site.distanceKmPlusMinusThreshold)
                iBadLat = dataLat < site.latitude - site.latitudePlusMinusThreshold || ...
                    dataLat > site.latitude + site.latitudePlusMinusThreshold;
            else
                [latitudeMax, ~] = WGS84reckon(site.latitude*pi/180, site.longitude*pi/180, ...
                    site.distanceKmPlusMinusThreshold*1000, 0);
                [latitudeMin, ~] = WGS84reckon(site.latitude*pi/180, site.longitude*pi/180, ...
                    site.distanceKmPlusMinusThreshold*1000, pi);
                iBadLat = dataLat < latitudeMin*180/pi || dataLat > latitudeMax*180/pi;
            end
            
            if any(iBadLat)
                flags(iBadLat) = failFlag;
            end
        end
    end
end