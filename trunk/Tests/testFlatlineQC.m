function testFlatlineQC ()
%TESTFLATLINEQC Unit test for the auto flatline QC routine.
%
% Creates a dummy data set, passes it to the flatlineQC routine, then verifies
% that the routine successfully flagged all flatline regions.
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

num_samples = 1000;
min_flatline_size = 5;

% generate test data
[sample_data cal_data] = genTestData(...
  num_samples,{'TEMP', 'COND', 'PRES'},1,num_samples,...
  [10,10,10],[100,100,100],[10,10,10],[100,100,100]);

% each element is a Nx2 matrix, one for each parameter
% N == num flatline regions for this parameter
% first column is start flatline index, second column is end flatline index
flatlines = {};

% insert some flatlines
for k = 1:length(sample_data.parameters)
  
  pflatlines = [];
  
  for m = 1:num_samples* 0.1
    
    % size of this flatline region - may be up to twice 
    % the minimum size that the filter should detect
    size = min_flatline_size + int32(min_flatline_size*rand(1,1));

    % insert flatline at random location in the dataset
    start = 1 + int32((num_samples-1-size)*rand(1,1));
    
    % insert flatline of consecutive random value
    sample_data.parameters(k).data(start:size + start-1) = 0.0;
    
    % save for later validation  
    pflatlines(end+1,1) = start;
    pflatlines(end,  2) = start+size-1;
    
  end
  
  % combine any overlapping flatline regions
  pflatlines = sortrows(pflatlines);
  
  m = 2;
  while m <= length(pflatlines(:,1))

    if pflatlines(m,1) <= pflatlines(m-1,2)+1

      end_idx = max(pflatlines(m,2),pflatlines(m-1,2));
      pflatlines(m-1,2) = end_idx;
      pflatlines(m,:) = [];

    else m = m + 1; end

  end
  
  disp([num2str(length(pflatlines(:,1))) ' flatlines inserted for ' ...
        sample_data.parameters(k).name]);
  
  flatlines{end+1} = pflatlines;
end

% run dataset through the flatline filter
filtered_data = ...
  flatlineQC(sample_data, cal_data, 'nsamples', min_flatline_size);

% check that flags have been created for each of the flatlines, and no more
for k = 1:length(filtered_data.parameters)
  
  pflatlines = flatlines{k};
  
  flags = filtered_data.parameters(k).flags;
  
  disp([num2str(length(flags)) ' flatlines detected for ' ...
        filtered_data.parameters(k).name]);
  
  % check that the correct number of flatlines were detected
  if length(flags) ~= length(pflatlines(:,1))
    error(['invalid number of flatlines detected for ' ...
           filtered_data.parameters(k).name ': ' num2str(length(flags))...
           ' (should be ' num2str(length(pflatlines)) ')']);
  end
  
  % check that each flatline is valid
  for m = 1:length(flags)
    
    lidx = find(pflatlines(:,1) == flags(m).low_idx);
    
    % low index check
    if isempty(lidx)
      error(['invalid flatline flag (low_idx) for ' ...
        filtered_data.parameters(k).name ': '...
        num2str(flags(m).low_idx)  '-' num2str(flags(m).high_idx)]);
    end
    
    hidx = pflatlines(lidx,2);
    
    % high index check
    if flags(m).high_idx ~= hidx
      error(['invalid flatline flag (high_idx) for ' ...
        filtered_data.parameters(k).name ': '...
        num2str(flags(m).low_idx) '-' num2str(flags(m).high_idx)]);
    end
  end
end

disp('all flatlines detected');
