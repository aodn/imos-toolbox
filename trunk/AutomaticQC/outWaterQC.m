function sample_data = outWaterQC( sample_data, cal_data )
%OUTWATERQC Flags samples which were taken after the instrument was taken
% out of the water.
%
% Flags all samples from the data set which have a time that is after the 
% out water time. Assumes that all of these samples will be at the end of the 
% data set.
%
% Inputs:
%   sample_data - struct containing a vector of parameter structs, which in
%   turn contain the data.
%
%   cal_data - struct which contains the out water time, and the qc set in use.
%
% Outputs:
%   sample_data - same as input, with out water samples flagged.
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

% start index of samples which were taken out of water
start = 0;

% step through the end of the data set until we find a sample 
% which has a time less than or equal to the out water time
for k = length(sample_data.time):-1:1
  
  if sample_data.time(k) <= cal_data.out_water_time
    
    start = k;
    break;
    
  end
end

% add flags for each of the parameters
for k = 1:length(sample_data.parameters)
  
  sample_data.parameters(k).flags(end+1).low_index = start;
  sample_data.parameters(k).flags(end).high_index  = length(sample_data.time);
  sample_data.parameters(k).flags(end).comment     = 'taken after out of water';
  sample_data.parameters(k).flags(end).flag        = imosQCFlag(...
                                                     'bound', cal_data.qc_set);
end
