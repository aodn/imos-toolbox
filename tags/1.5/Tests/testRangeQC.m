function testRangeQC ()
%TESTRANGEQC Unit test for the auto range-checking QC routine.
%
% Creates a dummy data set, passes it to the rangeQC routine, then verifies
% that the routine successfully flagged all out of bounds values.
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

% generate test data, ensuring that some values will be out of bounds
sample_data = genTestData(...
  2000,...
  {'TEMP','COND','PRES'},...
  1,...
  2000,...
  [0,0,0],...
  [1000,1000,1000],...
  [150,150,150],...
  [900,900,900]);

disp('running data through rangeQC filter');

qc_set = str2num(readToolboxProperty('toolbox.qc_set'));
rangeFlag = imosQCFlag('bound', qc_set, 'flag');
goodFlag  = imosQCFlag('good', qc_set, 'flag');

for k = 1:length(sample_data.variables)
  
  data = sample_data.variables{k}.data;

  % run the data through the range filter
  [data flags log] = rangeQC(sample_data, data, k);

  % run through the data, ensuring that the range routine flagged every value
  % that is out of bounds, and no more
  s = sample_data.variables{k};
  
  disp(['checking ' s.name]);
  disp(['num flags for ' s.name ' is ' num2str(length(flags))]);
  
  % check that the filter didn't modify the data
  if ~(s.data == data), error('filter changed the data'); end
  
  % for every value
  for m = 1:length(data)
    
    d = data( m);
    f = flags(m);
    
    % if out of bounds, check that it has been flagged
    if d < s.valid_min || d > s.valid_max
  
      if f ~= rangeFlag
        error(['out of range value (d(' ...
               num2str(m) ')=' num2str(d) ...
               ') has not been flagged']); 
      end
      
    % if within bounds, check that it has not been flagged
    else
      
      if f ~= goodFlag
        error(['good value (d(' ...
               num2str(m) ')=' num2str(d) ...
               ') has been flagged']); 
      end
    end
  end
  
  disp(['flags for ' s.name ' are valid']);
  
end
