function sample_data = flatlineQC( sample_data, cal_data, varargin )
%FLATLINEQC Flags flatline regions in the given data set.
%
% Simple filter which finds and flags any 'flatline' regions in the given data.
% A flatline is defined as a consecutive set of samples which have the same
% value.
%
% Inputs:
%   sample_data - struct containing a vector of parameter structs, which in
%                 turn contain the data.
%
%   cal_data    - struct which contains calibration and metadata.
%
%   'nsamples'  - Minimum number of consecutive samples with the same value
%                 that will be detected by the filter. If not provided, a
%                 default value of 5 is used. If provided, and less than 2, a
%                 value of 2 is used.
%
% Outputs:
%   sample_data - same as input, with flags added for flatline regions.
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

error(nargchk(2, 4, nargin));
if ~isstruct(sample_data), error('sample_data must be a struct'); end
if ~isstruct(cal_data),    error('cal_data must be a struct');    end

p = inputParser;
p.addOptional('nsamples', 5, @isnumeric);

p.parse(varargin{:});

nsamples = p.Results.nsamples;
if nsamples < 2, nsamples = 2; end

flag = imosQCFlag('probablyBad', cal_data.qc_set);

% size of the current flatline region we are stepping through
flatlineSize = 1;

% check data in every parameter
for k = 1:length(sample_data.parameters)
  
  data = sample_data.parameters(k).data;
  
  for m = 2:length(data)
    
    % this data point is the same as the last one
    if data(m-1) == data(m)
      
      % increase current number of consecutive points
      flatlineSize = flatlineSize + 1;
      
      % the number of consecutive points is big 
      % enough to warrent flagging it as a flatline
      if flatlineSize == nsamples
        
        sample_data.parameters(k).flags(end+1).low_idx = m - nsamples + 1;
        sample_data.parameters(k).flags(end).high_idx  = m;
        sample_data.parameters(k).flags(end).flag      = flag;
        sample_data.parameters(k).flags(end).comment   = 'flatline detected';
      
      % extend the flag range as long as the 
      % flatline continues; don't reflag it
      elseif flatlineSize > nsamples
        
        sample_data.parameters(k).flags(end).high_idx = m;
        
      end
    
    % this data point is different from the last one - reset the count
    else flatlineSize = 1; end
    
  end
end
