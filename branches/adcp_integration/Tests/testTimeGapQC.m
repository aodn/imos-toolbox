function testTimeGapQC()
%TESTTIMEGAPQC Tests the time gap QC filter.
%
% Creates a sample data set, runs it through the time gap QC filter, checks
% that the filter correctly flagged bad values.
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

qc_set = str2double(readToolboxProperty('toolbox.qc_set'));
goodFlag = imosQCFlag('good',        qc_set, 'flag');
gapFlag  = imosQCFlag('discont',     qc_set, 'flag');

nsamples = 5000;
ngaps    = 16;
gapsize  = 13;

sam = genTestData(nsamples, {'TEMP'}, 1, nsamples, 1, 100, 1, 100);

% randomly insert some gaps
gapStarts = [];

for k = 1:ngaps
  
  gapStarts(k) = int16((nsamples-gapsize) * rand(1,1));

  % make sure the gaps are separated
  if k > 2
    while any(abs(gapStarts(k)-gapStarts(1:k-1)) <= gapsize*2)
      gapStarts(k) = int16((nsamples-gapsize) * rand(1,1));
    end
  end
end

% insert the gaps
gapStarts = sort(gapStarts, 'descend');
for k = 1:ngaps
  sam.variables{1} .data(gapStarts(k):gapStarts(k)+gapsize-1) = [];
  sam.dimensions{1}.data(gapStarts(k):gapStarts(k)+gapsize-1) = [];
  
  % offset gaps that have already been inserted to keep them valid
  gapStarts(1:k-1) = gapStarts(1:k-1) - gapsize;
  gapStarts(k)     = gapStarts(k)     - 1;
end

% run the data set through the filter
[data flags log] = ...
  timeGapQC(sam, sam.variables{1}.data, 1, 'gapsize', gapsize);

% check that the gaps were flagged
gaps = [gapStarts gapStarts+1];

gapFlags        = flags(gaps);
goodFlags       = flags;
goodFlags(gaps) = [];

if ~all(gapFlags == gapFlag)
  error('gap region has not been flagged'); 
end

if ~all(goodFlags == goodFlag)
  error('non-gap region has been flagged'); 
end

disp('all gaps were flagged');
