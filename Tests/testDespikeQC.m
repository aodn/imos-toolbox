function testDespikeQC ( routine )
%FUNCTIONNAME Test case for auto spike detection functions.
%
% Test case for all automatic spike detection functions. It's a little hard to 
% 'test' that a spike detection routine worked, as verifying the results would
% require the use of a spike detection routine. Thus, this test case is a
% little more flexible than a purely automated test case, in that it can be
% executed automatically or manually.
%
% The test case can be executed automatically by passing in no parameters. When
% executed automatically, all despiking routines are executed on a sample data 
% set. The results are not verified for correctness; rather, the test is
% considered successful if no errors are generated.
%
% When the name of a spike detection routine is passed in, that routine is
% executed with a sample data set, and the results are displayed in a graph.
%
% Inputs: routine - Optional. Name of the despiking routine to execute when
%                   executing manually.
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
step = 0.01;

% random data is too random, so we're going to discard the random data which
% is generated, and replace it with a smoother, randomised trigonometric 
% function
sam = genTestData(num_samples, {'TEMP'}, 0, num_samples, 0,0,0,0);

qc_set = str2num(readProperty('toolbox.qc_set'));
spikeFlag = imosQCFlag('spike', qc_set, 'flag');

% parameters for trig function in the range 0.1 to 5
params = 0.1+4.9*rand(1,8);

% new data set
x = 0.0:step*pi:step*pi*(num_samples-1);
sam.variables{1}.data = params(1)*sin(params(2)*x) + ...
                        params(3)*cos(params(4)*x) - ...
                        params(5)*sin(params(6)*x) + ...
                        params(7)*cos(params(8)*x);

disp('data set generated with: ');
disp([num2str(params(1)) '*sin(' num2str(params(2)) '*x) + '...
      num2str(params(3)) '*cos(' num2str(params(4)) '*x) - '...
      num2str(params(5)) '*sin(' num2str(params(6)) '*x) + '...
      num2str(params(7)) '*cos(' num2str(params(8)) '*x)']);
    

maxval = max(sam.variables{1}.data);
minval = min(sam.variables{1}.data);
range = abs(maxval - minval);

% randomly insert 5 % spikes
spikes = int32(1+num_samples*rand(1,int32(0.05*num_samples)));

disp([num2str(num_samples) ' samples, ' ...
      num2str(length(spikes)) ' spikes inserted']);

for k = 1:length(spikes)
  
  if mod(k,2), sam.variables{1}.data(spikes(k)) = maxval + range*rand(1,1);
  else         sam.variables{1}.data(spikes(k)) = minval - range*rand(1,1);
  end
  
end

% no args - automatic
if nargin == 0
  
  files = dir([pwd filesep 'AutomaticQC']);
  
  for k = 1:length(files)
    
    name = files(k).name;

    % ignore if not a despike routine
    if isempty(strfind(name, 'DespikeQC')), continue; end
    
    % get function handle - truncate trailing '.m'
    name = name(1:end-2);
    func = str2func(name);
    
    % run filter
    data = sam.variables{1}.data;
    [data,flags,log] = func(sam,data,1);
    
    flags = find(flags == spikeFlag);
    
    disp([name ' detected ' num2str(length(flags)) ' spikes']);
    
  end

% despike routine specified - show graph
else
  
  routine = [routine 'DespikeQC'];
  spikeFunc = str2func(routine);
 
  data = sam.variables{1}.data;
  [data,flags,log] = spikeFunc(sam, data,1);
  
  flags = find(flags == spikeFlag);
  
  disp([routine ' filter found ' num2str(length(flags)) ' spikes']);

  plot(1:length(data),  data,  'r-', ...
       flags,           0.0,   'k*');
  
end
