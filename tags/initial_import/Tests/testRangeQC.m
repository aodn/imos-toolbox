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

function testRangeQC ()
%TESTRANGEQC Unit test for the auto range-checking QC routine.
%
% Creates a dummy data set, passes it to the rangeQC routine, then verifies
% that the routine successfully flagged all out of bounds values.
%
% Author: Paul McCarthy <paul.mccarthy@csiro.au>
%

disp(' ');
disp(['-- ' mfilename ' --']);
disp(' ');

% generate test data, ensuring that some values will be out of bounds
[sample_data cal_data] = genTestData(...
  20,...
  {'TEMP','COND','PRES'},...
  1,...
  20,...
  [0,0,0],...
  [1000,1000,1000],...
  [20,20,20],...
  [900,900,900]);

disp('running data through rangeQC filter');

% run the data through the range filter
filtered_data = rangeQC(sample_data, cal_data);

% run through the data, ensuring that the range routine flagged every value
% that is out of bounds, and no more

for k = 1:length(sample_data.parameters)
  s = sample_data.parameters(k);
  c = cal_data.parameters(k);
  fd = filtered_data.parameters(k);
  
  outOfBounds = [find(s.data > c.max_value) find(s.data < c.min_value)];
  
  disp(['checking ' s.name ...
        ' - num flags should be ' num2str(length(outOfBounds))]);
  disp(['num flags for ' s.name ' is ' num2str(length(fd.flags))]);
  
  % first check that the number of flagged values is correct
  if ~length(outOfBounds) == length(fd.flags)
    error(['flagged values for ' s.name ' don''t match']);
  end
  
  % for each out of bound value
  for m = 1:length(outOfBounds)
    
    % check that the corresponding flag is valid
    f = fd.flags(m);
    
    if f.low_idx ~= outOfBounds(m) || f.high_idx ~= outOfBounds(m)
     error('invalid flag found');
    end
    
  end
  
  disp(['flags for ' s.name ' are valid']);
  
  
end
