function [data flags log] = outWaterQC( sample_data, data, k )
%OUTWATERQC Flags samples which were taken after the instrument was taken
% out of the water.
%
% Flags all samples from the data set which have a time that is after the 
% out water time. Assumes that all of these samples will be at the end of the 
% data set.
%
% Inputs:
%   sample_data - struct containing the entire data set and dimension data.
%
%   data        - the vector of data to check.
%
%   k           - Index into the sample_data.variables vector.
%
% Outputs:
%   data        - Same as input.
%
%   flags       - Vector the same size as data, with after out-water samples 
%                 flagged. Empty if no values were flagged.
%
%   log         - Empty cell array.
%
% Author: Paul McCarthy <paul.mccarthy@csiro.au>
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

error(nargchk(3, 3, nargin));
if ~isstruct(sample_data),        error('sample_data must be a struct'); end
if ~isvector(data),               error('data must be a vector');        end
if ~isscalar(k) || ~isnumeric(k), error('k must be a numeric scalar');   end

flags = char;
log   = {};

% start index of samples which were taken out of water
start = 0;

dateFmt = readToolboxProperty('exportNetCDF.dateFormat');
time_coverage_end = datenum(sample_data.time_coverage_end, dateFmt);

qc_set  = str2num(readToolboxProperty('toolbox.qc_set'));
flagVal = imosQCFlag('bad', qc_set, 'flag');

origLength = length(data);

% step through the end of the data set until we find a sample 
% which has a time less than or equal to the out water time
time = sample_data.dimensions{1}.data;

endTime = time(end);

for k = length(time):-1:1
  
  if time(k) <= time_coverage_end
    
    start     = k;
    starttime = time(k);
    break;
    
  end
end

% the entire data set is before the out-water time
if start == length(data), return; end
  
% flag the after out-water samples
flags(start+1:length(data)) = flagVal;
