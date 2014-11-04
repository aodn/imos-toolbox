function [regionalRangeMin, regionalRangeMax, isSite] = getImosRegionalRange(siteName, paramName)
%GETIMOSREGIONALRANGE Returns the regionalRangeMin, regionalRangeMax thresholds 
% to QC data with the regional range QC test. 
%
% These thresholds values were taken from an histogram distribution
% analysis either from historical water samples or in-situ sensor data. If
% no threshold value is found then NaN is returned.
%
% Inputs:
%   siteName  - siteName of the required site. 
%   paramName - paramName of the required IMOS parameter. 
%
% Outputs:
%   regionalRangeMin - lower threshold value for the regional range test
%   regionalRangeMax - upper threshold value for the regional range test
%   isSite           - boolean true if site is found in the list
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
%     * Neither the siteName of the eMII/IMOS nor the names of its contributors 
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

error(nargchk(2, 2, nargin));
if ~ischar(siteName),    error('siteName must be a string'); end
if ~ischar(paramName),   error('paramName must be a string'); end

regionalRangeMin = NaN;
regionalRangeMax = NaN;
isSite = false;

path = '';
if ~isdeployed, [path, ~, ~] = fileparts(which('imosToolbox.m')); end
if isempty(path), path = pwd; end
path = fullfile(path, 'AutomaticQC');

fid = -1;
regRange = [];
try
  fid = fopen([path filesep 'imosRegionalRangeQC.txt'], 'rt');
  if fid == -1, return; end
  
  regRange = textscan(fid, '%s%s%f%f', 'delimiter', ',', 'commentStyle', '%');
  fclose(fid);
catch e
  if fid ~= -1, fclose(fid); end
  rethrow(e);
end

% look for a site and parameter match
iSite  = strcmpi(siteName,  regRange{1});
iParam = strcmpi(paramName, regRange{2});
iLine = iSite & iParam;

if any(iSite), isSite = true; end

if any(iLine)
    regionalRangeMin = regRange{3}(iLine);
    regionalRangeMax = regRange{4}(iLine);
end