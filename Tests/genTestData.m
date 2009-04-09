function [sample_data cal_data] = genTestData(...
  size,...
  params,...
  in_water_time,...
  out_water_time,...
  min_values,...
  max_values,...
  min_bounds,...
  max_bounds)
%genTestData Generate test data for test cases.
%
% Generates a set of test data for use in test cases, according to the inputs.
% The time values are sequential, from 1 to the size input parameter. The
% in_water_time and out_water_time parameters should be given on this scale.
%
% Inputs:
%   size           - Number of samples
%   params         - String array of parameter names
%   in_water_time  - In water time
%   out_water_time - Out water time
%   min_values     - Vector of min values for each parameter
%   max_values     - Vector of max values for each parameter
%   min_bounds     - Vector of min bounds for each parameter
%   max_bounds     - Vector of max bounds for each parameter
%
% Outputs:
%   sample_data    - struct containing sample data for the given number of
%                    parameters
%
%   cal_data       - struct containing calibration data
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

disp(['generating test data set of ' num2str(size) ' samples']);

sample_data.dimensions.time = 1:size;
sample_data.parameters      = [];
sample_data.log             = {};

cal_data.in_water_time  = in_water_time;
cal_data.out_water_time = out_water_time;
cal_data.qc_set         = 1;
cal_data.parameters     = [];

for k = 1:length(params)
  
  % generate random data set between min_value and max_value
  data = min_values(k) + (max_values(k)-min_values(k)).*rand(1,size);
  
  sample_data.parameters(k).name   = params{k};
  sample_data.parameters(k).data   = data;
  sample_data.parameters(k).flags  = [];
  
  cal_data.parameters(k).name      = params{k};
  cal_data.parameters(k).min_value = min_bounds(k);
  cal_data.parameters(k).max_value = max_bounds(k);
  
end
