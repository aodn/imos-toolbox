function sample_data = genTestData(...
  nsamples,...
  vars,...
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
%   nsamples       - Number of samples
%   vars           - String array of variable names
%   in_water_time  - In water time
%   out_water_time - Out water time
%   min_values     - Vector of min values for each variable
%   max_values     - Vector of max values for each variable
%   min_bounds     - Vector of min bounds for each variable
%   max_bounds     - Vector of max bounds for each variable
%
% Outputs:
%   sample_data    - struct containing sample data for the given number of
%                    variables
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

disp(['generating test data set of ' num2str(nsamples) ' samples']);

datefmt = readToolboxProperty('exportNetCDF.dateFormat');
qcSet   = str2double(readToolboxProperty('toolbox.qc_set'));

sample_data.dimensions             = {};
sample_data.dimensions{1}.name     = 'TIME';
sample_data.dimensions{1}.data     = (1:nsamples)';
sample_data.dimensions{1}.flags    = zeros(nsamples, 1);
sample_data.dimensions{1}.flags(:) = '0';
sample_data.variables              = {};
sample_data.level                  = 0;

sample_data.quality_control_set  = qcSet;
sample_data.time_coverage_start  = datestr(in_water_time, datefmt);
sample_data.time_coverage_end    = datestr(out_water_time, datefmt);
sample_data.date_created         = datestr(now, datefmt);

for k = 1:length(vars)
  
  % generate random data set between min_value and max_value
  data = min_values(k) + (max_values(k)-min_values(k)).*rand(1,nsamples);
  data = data';
  
  sample_data.variables{k}.deployment_id = '0A0370A6-93E7-4B1F-BB47-3FB935F298F7';
  sample_data.variables{k}.name          = vars{k};
  sample_data.variables{k}.dimensions    = [1];
  sample_data.variables{k}.data          = data;
  sample_data.variables{k}.flags         = zeros(size(data));
  sample_data.variables{k}.flags(:)      = '0';
  sample_data.variables{k}.valid_min     = min_bounds(k);
  sample_data.variables{k}.valid_max     = max_bounds(k);
  
end
