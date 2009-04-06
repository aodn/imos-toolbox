function [sample_data] = tukey53HDespikeQC( sample_data, cal_data, varargin )
%TUKEY53HDESPIKEQC Detects spikes in the given data using the Tukey 53H method.
%
% Detects spikes in the given data using the Tukey 53H method, as described in
% 
%   Goring DG & Nikora VI 2002 'Despiking Acoustic Doppler Velocimeter Data',
%   Journal of Hydraulic Engineering, January 2002, vol 128, issue 1, 
%   pp 117-126.
%
% Inputs:
%   sample_data - struct containing a vector of parameter structs, which in
%                 turn contain the data.
%
%   cal_data    - struct which contains calibration and metadata.
%
%   'k_param'   - Filter threshold (see the journal article). If not provided,
%                 a default value of 1.5 is used.
%
% Outputs:
%   sample_data - same as input, with flags added for data spikes.
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
p.addOptional('k_param', 1.5, @isnumeric);

p.parse(varargin{:});

k_param = p.Results.k_param;

flag = imosQCFlag('spike', cal_data.qc_set);

for k = 1:length(sample_data.parameters)
  
  data = sample_data.parameters(k).data;
  
  % remove mean, and apply a mild high pass 
  % filter before applying spike detection
  data = highPassFilter(data, 0.99);
  data = data - mean(data);
  
  stddev = std(data);
  
  for m = 3:(length(data)-2)
    
    u1 = data(m-2:m+2);
    u2 =   u1(  2:  4);
    
    u1(3) = median(u1);
    u2(2) = median(u2);
    
    u3 = 0.25 * (u2(1) + 2*u2(2) + u2(3));
    
    delta = abs(data(m) - u3);
    
    if delta > k_param * stddev
      
      sample_data.parameters(k).flags(end+1).low_idx = m;
      sample_data.parameters(k).flags(end).high_idx  = m;
      sample_data.parameters(k).flags(end).flag      = flag;
      sample_data.parameters(k).flags(end).comment   = ...
                                           'Spike detected (Tukey 53H)';
    end
  end
end
