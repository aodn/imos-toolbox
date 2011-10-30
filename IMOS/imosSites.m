function site = imosSites(name)
%IMOSSITES Returns the name, longitude, latitude and different thresholds 
% to QC data with the Morello et Al. 2011 impossible location test. 
%
% IMOS sites longitude and latitude were taken from the IMOS portal 
% metadata.
%
% Inputs:
%   name - name of the required site details. 
%
% Outputs:
%   site - structure with the following fields for the requested site :
%               -name
%               -longitude
%               -latitude
%               -latitudePlusMinusThreshold
%               -longitudePlusMinusThreshold
%               -distanceKmPlusMinusThreshold (optional, 
%                       if documented overrules previous thresholds values)
%
% Author:  Guillaume Galibert <guillaume.galibert@utas.edu.au>
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

error(nargchk(1, 1, nargin));
if ~ischar(name),    error('name must be a string'); end

site = [];

% get the location of this m-file, which is 
% also the location of imosSite.txt
path = [pwd filesep 'IMOS'];

fid = -1;
params = [];
try
  fid = fopen([path filesep 'imosSites.txt'], 'rt');
  if fid == -1, return; end
  
  params = textscan(fid, '%s%f%f%f%f%f', 'delimiter', ',', 'commentStyle', '%');
  fclose(fid);
catch e
  if fid ~= -1, fclose(fid); end
  rethrow(e);
end

% look for a site name match
iName = strcmpi(name, params{1});

if any(iName)
    site = struct;
    
    site.name                           = params{1}{iName};
    site.longitude                      = params{2}(iName);
    site.latitude                       = params{3}(iName);
    site.latitudePlusMinusThreshold     = params{4}(iName);
    site.longitudePlusMinusThreshold    = params{5}(iName);
    site.distanceKmPlusMinusThreshold   = params{6}(iName);
else
    return;
end
