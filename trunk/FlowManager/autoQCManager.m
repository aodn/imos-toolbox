function sample_data = autoQCManager( sample_data )
%AUTOQCMANAGER Manages the execution of automatic QC routines over a set
% of data.
%
% Inputs:
%   sample_data - 
%
% Outputs:
%   sample_data - 
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
  error(nargchk(1,1,nargin));

  if ~iscell(sample_data)
    error('sample_data must be a cell array of structs'); 
  end

  qcRoutines = listAutoQCRoutines();
  qcChain    = [];

  % get default filter chain if there is one
  try   qcChain = str2num(readToolboxProperty('autoQCManager.autoQCChain'));
  catch e
  end

  % prompt user to select QC filters to run
  qcChain = listSelectionDialog(...
    'Define the QC filter chain', qcRoutines, qcChain);

  % user cancelled dialog
  if isempty(qcChain), return; end

  % save user's latest selection for next time
  writeToolboxProperty('autoQCManager.autoQCChain', num2str(qcChain));
  
  qcRoutines = {qcRoutines{qcChain}};

  % run each data set through the chain
  for k = 1:length(sample_data),

    s = sample_data{k};

    flagv = 1;

    for m = 1:length(s.variables)
      v = s.variables{m};

      f = 1 + round(length(v.data) * rand(5,1));

      for n = 1:length(f)
        v.flags(f(n)) = num2str(n);
      end

      s.variables{m} = v;
    end
    sample_data{k} = s;

%     for m = 1:length(qcRoutines)
%       sample_data{k} = qcFilter(sample_data{k}, qcRoutines{m});
%     end
  end
end

function sam = qcFilter(sam, filter)
%QCFILTER Runs the given data set through the given automatic QC filter.
%
  
end
