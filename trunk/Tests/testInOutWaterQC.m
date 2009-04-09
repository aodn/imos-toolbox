function testInOutWaterQC()
%TESTINOUTWATER Unit test for in/out of water auto QC routines.
%
% Creates a dummy set of sample data, passes it through the inWaterQC
% and outWaterQC routines, and verifies that the in/out of water samples 
% were removed.
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

disp(' ');
disp(['-- ' mfilename ' --']);
disp(' ');

%
% create input sample data
%
params = {'CNDC', 'TEMP', 'PRES'};

num_samples = 1000;
start_idx = 95;
end_idx = 924;

[sample_data cal_data] = genTestData(...
  num_samples,...
  params,...
  start_idx,...
  end_idx,...
  [0,0,0],...
  [1000,1000,1000],...
  [0,0,0],...
  [1000,1000,1000]);

% call in water and out water routines
disp(['running data through inWaterQC and outWaterQC']);
    
filtered_data = inWaterQC( sample_data,   cal_data);
filtered_data = outWaterQC(filtered_data, cal_data);

% verify that they did their jobs

disp('checking filtered data sets');

disp(['time dim length: ' num2str(length(filtered_data.dimensions.time))]);

% check each parameter
for k = 1:length(filtered_data.parameters)
  
  orig = sample_data.parameters(k).data;
  filt = filtered_data.parameters(k).data;
  
  disp([filtered_data.parameters(k).name ...
      ' filtered set length: ' num2str(length(filt))]);
  
  if filt ~= orig(start_idx:end_idx)
    error('data has not been filtered correctly');
  end
  
end

disp('filtered data sets are valid');

