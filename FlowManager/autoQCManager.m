function qc_data = autoQCManager( sample_data )
%AUTOQCMANAGER Manages the execution of automatic QC routines over a set
% of data.
%
% The user is prompted to select a chain of QC routines through which to
% pass the data. The data is then passed through the selected filter chain
% and returned.
%
% Inputs:
%   sample_data - Cell array of sample data structs, containing the data
%                 over which the qc routines are to be executed.
%
% Outputs:
%   qc_data     - Same as input, after QC routines have been run over it.
%                 Will be empty if the user cancelled/interrupted the QC
%                 process.
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
  
  qcSet = str2double(readToolboxProperty('toolbox.qc_set'));
  rawFlag  = imosQCFlag('raw',  qcSet, 'flag');
  goodFlag = imosQCFlag('good', qcSet, 'flag');
  
  qc_data = {};

  % get all QC routines that exist
  qcRoutines = listAutoQCRoutines();
  qcChain    = {};

  % get default filter chain if there is one
  try
    qcChain = textscan(readToolboxProperty('autoQCManager.autoQCChain'), '%s');
    qcChain = qcChain{1};
  catch e
  end

  % prompt user to select QC filters to run - the list of initially 
  % selected options is stored in toolboxProperties as routine names, 
  % but must be provided to the list selection dialog as indices
  qcChainIdx = cellfun(@(x)(find(ismember(qcRoutines,x))),qcChain);
  qcChain = listSelectionDialog(...
    'Select QC filters', qcRoutines, qcChainIdx);

  % user cancelled dialog
  if isempty(qcChain), return; end

  % save user's latest selection for next time - turn the qcChain
  % cell array into a space-separated string of the names
  qcChainStr = cellfun(@(x)([x ' ']), qcChain, 'UniformOutput', false);
  writeToolboxProperty('autoQCManager.autoQCChain', deblank([qcChainStr{:}]));
  
  progress = waitbar(...
    0, 'Running QC routines', ...
    'Name', 'Running QC routines',...
    'CreateCancelBtn', ...
    ['waitbar(1,gcbf,''Cancelling - please wait...'');'...
     'setappdata(gcbf,''cancel'',true)']);
  setappdata(progress,'cancel',false);

  % run each data set through the chain
  for k = 1:length(sample_data),
    
    % user cancelled progress bar
    if getappdata(progress, 'cancel'), sample_data = {}; break; end
    
    for m = 1:length(qcChain)
      
      % user cancelled progress bar
      if getappdata(progress, 'cancel'), break; end
      
      % update progress bar
      progVal = ...
        ((k-1)*length(qcChain)+m) / (length(qcChain)*length(sample_data));
      progStr = [sample_data{k}.meta.instrument_make ' '...
                 sample_data{k}.meta.instrument_model ' ' qcChain{m}];
      waitbar(progVal, progress, progStr);
      
      % run current QC routine over the current data set
      sample_data{k} = qcFilter(sample_data{k}, qcChain{m}, rawFlag, goodFlag);
    end
  end
  
  delete(progress);

  qc_data = sample_data;
end

function sam = qcFilter(sam, filterName, rawFlag, goodFlag)
%QCFILTER Runs the given data set through the given automatic QC filter.
%
  % turn routine name into a function
  filter = str2func(filterName);

  for k = 1:length(sam.variables)

    data  = sam.variables{k}.data;
    flags = sam.variables{k}.flags;
    len = length(data);

    % the QC filters work on single vectors of data; 
    % we must 'slice' the data up along its dimensions
    data = data(:);
    slices = length(data) / len;

    flags = flags(:);

    for m = 1:slices

      slice     = data( len*(m-1)+1:len*(m));
      flagSlice = flags(len*(m-1)+1:len*(m));

      % log entries and any data changes that the routine generates
      % are currently discarded; only the flags are retained. 
      [d f l] = filter(sam, slice, k);

      % Flags are not overwritten - if a later routine flags the same 
      % value as a previous routine, the latter value is discarded.
      sliceIdx = find(flagSlice == rawFlag);
      flagIdx  = find(f         ~= goodFlag);
      idx = intersect(sliceIdx,flagIdx);
      
      % set the flags
      flagSlice(idx) = f(idx);
      flags(len*(m-1)+1:len*(m)) = flagSlice;

    end

    sam.variables{k}.flags = reshape(flags, size(sam.variables{k}.flags));
  end
end
