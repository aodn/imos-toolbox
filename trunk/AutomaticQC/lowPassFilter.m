function lpf = lowPassFilter (data, alpha)
%LOWPASSFILTER Simple low pass RC filter.
%
% Runs a low pass RC filter over the given data. The filter used is as
% described in:
%
%   Otnes RK & Enochson Loren, 1978 'Applied Time Series Analysis Volume 1:
%   Basic Techniques', pgs 108-109, Wiley.
%
% Inputs:
%
%   data  - Array of data.
%
%   alpha - Smoothing factor between 0.0 (exclusive) and 1.0 (inclusive). A 
%           higher value means more filtering. A value of 1.0 equals no 
%           filtering. Optional - if omitted, defaults to 0.5.
%
%   auto  - logical, run QC in batch mode
%
% Outputs:
%   lpf   - Filtered data
%
% Author:       Paul McCarthy <paul.mccarthy@csiro.au>
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

% check mandatory parameters
error(nargchk(1,2,nargin));
if ~isvector(data), error('data must be a vector'); end

% check or set optional alpha parameter
if nargin == 1
  alpha = 0.5;
else
  if ~isnumeric(alpha)...
  || ~isscalar( alpha), error('alpha must be a scalar numeric'); end

  if (alpha <= 0.0)... 
  || (alpha > 1.0),     error('alpha must be 0.0 < alpha <= 1.0'); end
end

% subtract mean before applying filter
mn = mean(data);
data = data - mn;

lpf = zeros(size(data));

lpf(1) = data(1);

for k = 2:length(data)
  
  lpf(k) = (1 - alpha) * data(k) + (alpha) * lpf(k-1);
  
end

% add mean back to filtered data
lpf = lpf+mn;
