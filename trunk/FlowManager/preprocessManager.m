function sample_data = preprocessManager( sample_data )
%PREPROCESSMANAGER Runs preprocessing filters over the given sample data 
% structs.
%
% Given a cell array of sample_data structs, prompts the user to run
% preprocessing routines over the data.
%
% Inputs:
%   sample_data - cell array of sample_data structs.
%
% Outputs:
%   sample_data - same as input, potentially with preprocessing
%                 modifications.
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

  if ~iscell(sample_data), error('sample_data must be a cell array'); end

  % nothing to do
  if isempty(sample_data), return; end

  % read in preprocessing-related properties
  ppPrompt = true;
  ppChain  = {};

  try
    ppPrompt = eval(readToolboxProperty('preprocessManager.preprocessPrompt'));
  catch e
  end

  % get default filter chain if there is one
  try
    ppChain = ...
      textscan(readToolboxProperty('preprocessManager.preprocessChain'), '%s');
    ppChain = ppChain{1};
  catch e
  end

  % if ppPrompt property is false, preprocessing is disabled
  if ~ppPrompt, return; end

  % get all preprocessing routines that exist
  ppRoutines = listPreprocessRoutines();

  % prompt user to select preprocessing filters to run - the list of 
  % initially selected options is stored in toolboxProperties as 
  % routine names, but must be provided to the list selection dialog 
  % as indices
  ppChainIdx = cellfun(@(x)(find(ismember(ppRoutines,x))),ppChain);
  ppChain = listSelectionDialog(...
    'Select Preprocess routines', ppRoutines, ppChainIdx);
  
  % user cancelled dialog
  if isempty(ppChain), return; end
  
  % save user's latest selection for next time - turn the ppChain
  % cell array into a space-separated string of the names
  ppChainStr = cellfun(@(x)([x ' ']), ppChain, 'UniformOutput', false);
  writeToolboxProperty('preprocessManager.preprocessChain', ...
    deblank([ppChainStr{:}]));
  
  for k = 1:length(ppChain)
    
    ppFunc = str2func(ppChain{k});
    
    sample_data = ppFunc(sample_data);
  end

end