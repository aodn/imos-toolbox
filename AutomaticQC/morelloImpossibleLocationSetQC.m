function [sample_data] = morelloImpossibleLocationSetQC( sample_data, auto )
%MORELLOIMPOSSIBLELOCATIONSET Flags impossible Latitude and Longitude values 
% using IMOS sites information in imosSites.txt.
%
% Impossible location test described in Morello et Al. 2011 paper.
%
% Inputs:
%   sample_data - struct containing the entire data set and dimension data.
%   auto - logical, run QC in batch mode
%
% Outputs:
%   sample_data - same as input, with QC flags added for variable/dimension
%                 data.
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

error(nargchk(1, 2, nargin));
if ~isstruct(sample_data), error('sample_data must be a struct'); end

% auto logical in input to enable running under batch processing
if nargin<2, auto=false; end

dataLon = [];
dataLat = [];
flagLon = [];
flagLat = [];

qcSet    = str2double(readProperty('toolbox.qc_set'));
passFlag = imosQCFlag('good',           qcSet, 'flag');
failFlag = imosQCFlag('probablyBad',    qcSet, 'flag');

idLon = getVar(sample_data.dimensions, 'LONGITUDE');
if idLon > 0
    dataLon = sample_data.dimensions{idLon}.data;
end

idLat = getVar(sample_data.dimensions, 'LATITUDE');
if idLat > 0
    dataLat = sample_data.dimensions{idLat}.data;
end

if ~isempty(dataLon) && ~isempty(dataLat)
    % get details from this site
    site = sample_data.meta.site_name; % source = ddb
    if strcmpi(site, 'UNKNOWN'), site = sample_data.site_code; end % source = global_attributes.txt
    
    site = imosSites(site);
    
    % test if site information exists
    if isempty(site)
        warning('No site information found to perform impossible location QC test');
    else
        lenData = length(dataLon);
        
        % initially all data is good
        flagLon = ones(lenData, 1)*passFlag;
        flagLat = flagLon;
        
        %test location
            if isnan(site.distanceKmPlusMinusThreshold)
                % test each independent coordinate on a rectangular area
                iBadLon = dataLon < site.longitude - site.longitudePlusMinusThreshold || ...
                    dataLon > site.longitude + site.longitudePlusMinusThreshold;
                iBadLat = dataLat < site.latitude - site.latitudePlusMinusThreshold || ...
                    dataLat > site.latitude + site.latitudePlusMinusThreshold;
            else
                % test each couple of coordinate on a circle area
                obsDist = WGS84dist(site.latitude, site.longitude, dataLat, dataLon);
                iBadLon = obsDist/1000 > site.distanceKmPlusMinusThreshold;
                iBadLat = iBadLon;
            end
            
            if any(iBadLon)
                flagLon(iBadLon) = failFlag;
                
            end
            if any(iBadLat)
                flagLat(iBadLat) = failFlag;
            end
            
            sample_data.dimensions{idLon}.flags = flagLon;
            sample_data.dimensions{idLat}.flags = flagLat;
    end
end