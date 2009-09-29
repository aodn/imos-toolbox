function [data flags log] = timeGapQC( sample_data, data, k, varargin )
%TIMEGAPQC Flags consecutive samples which have a suspiciously large 
% temporal difference.
%
% The timeGapQC  function steps through the time dimension (the first
% entry in sample_data.dimensions), searching for gaps which are larger
% than the specified gapsize.
%
% Inputs:
%   sample_data - struct containing the data set.
%
%   data        - the vector of data to check.
%
%   k           - Index into the sample_data variables vector.
%
%   'gapsize'   - Optional. Minimum time gap (matlab serial time) to be 
%                 flagged. If not provided, a default value of 6 hours is
%                 used.
%
% Outputs:
%   data        - same as input.
%
%   flags       - Vector the same length as data, with flags for gap regions.
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
error(nargchk(3,5,nargin));

if ~isstruct(sample_data),        error('sample_data must be a struct'); end
if ~isvector(data),               error('data must be a vector');        end
if ~isscalar(k) || ~isnumeric(k), error('k must be a numeric scalar');   end

p = inputParser;
% 6/24 == 6 hours in matlab time
p.addOptional('gapsize', 6/24, @isnumeric);

p.parse(varargin{:});

gapsize = p.Results.gapsize;

qc_set = str2num(readToolboxProperty('toolbox.qc_set'));
goodFlag = imosQCFlag('good',        qc_set, 'flag');
gapFlag  = imosQCFlag('discont',     qc_set, 'flag');

log                   = {};
flags(1:length(data)) = goodFlag;

dim  = sample_data.dimensions{1}.data;

for k = 2:length(dim)
  
  if (dim(k)-dim(k-1)) >= gapsize, flags([k-1 k]) = gapFlag; end
end