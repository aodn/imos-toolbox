function testInOutWaterQC()
%TESTINOUTWATER Unit test for in/out of water auto QC routines.
%
% Creates a dummy set of sample data, passes it through the inWaterQC
% and outWaterQC routines, and verifies that the in/out of water samples 
% were flagged.
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

sample_data = genTestData(...
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

for k = 1:length(sample_data.variables)
  
  s = sample_data.variables{k};
  data = s.data;
  
  [d iFlags l] = inWaterQC( sample_data, data, k);
  [d oFlags l] = outWaterQC(sample_data, data, k);

  iFlags = find(iFlags);
  oFlags = find(oFlags);
  
  iShouldBe = 1:start_idx-1;
  oShouldBe = end_idx+1:num_samples;
  
  if length(iFlags) ~= length(iShouldBe) || ~all(iFlags == iShouldBe)
    error('in water flags are invalid'); 
  end
  if length(oFlags) ~= length(oShouldBe) || ~all(oFlags == oShouldBe)
    error('out water flags are invalid');
  end
  
  
end

disp('filtered data sets are valid');

