function [sample_data, cancel] = preprocessManager( sample_data, qcLevel, mode, auto )
%PREPROCESSMANAGER Runs preprocessing filters over the given sample data 
% structs.
%
% Given a cell array of sample_data structs, prompts the user to run
% preprocessing routines over the data.
%
% Inputs:
%   sample_data - cell array of sample_data structs.
%   qcLevel     - string, 'raw' or 'qc'. Some pp not applied when 'raw'.
%   mode        - string, 'timeSerie' or 'profile'.
%   auto        - logical, check if pre-processing in batch mode.
%
% Outputs:
%   sample_data - same as input, potentially with preprocessing
%                 modifications.
%   cancel      - logical, whether pre-processing has been cancelled or
%                 not.
%
% Author:       Paul McCarthy <paul.mccarthy@csiro.au>
% Contributor:	Brad Morris <b.morris@unsw.edu.au>
%				Guillaume Galibert <guillaume.galibert@utas.edu.au>
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
  narginchk(3,4);

  %BDM - 12/08/2010 - added auto logical in input to enable running under
  %batch processing
  if nargin < 4, auto = false; end
    
  if ~iscell(sample_data), error('sample_data must be a cell array'); end

  cancel = false;
  
  % nothing to do
  if isempty(sample_data), return; end

  % read in preprocessing-related properties
  ppPrompt = true;
  ppChain  = {};

  %BDM - 12/08/2010 - added if statement to run batch
  if ~auto
      try
          ppPrompt = eval(readProperty('preprocessManager.preprocessPrompt'));
      catch e
      end
  end
  
  % get default filter chain if there is one
  try
      switch mode
          case 'profile'
              ppChain = ...
                  textscan(readProperty('preprocessManager.preprocessChain.profile'), '%s');
          otherwise
              ppChain = ...
                  textscan(readProperty('preprocessManager.preprocessChain.timeSeries'), '%s');
      end
      ppChain = ppChain{1};
  catch e
  end

  % if ppPrompt property is false, preprocessing is disabled
  if ~ppPrompt, return; end

    %BDM - 12/08/2010 - added if statement to run batch without dialogue
    %box
  if ~auto
      % get all preprocessing routines that exist
      ppRoutines = listPreprocessRoutines();
      
      % prompt user to select preprocessing filters to run - the list of
      % initially selected options is stored in toolboxProperties as
      % routine names, but must be provided to the list selection dialog
      % as indices
      ppChainIdx = cellfun(@(x)(find(ismember(ppRoutines,x))),ppChain);
      [ppChain, cancel] = listSelectionDialog('Select Preprocess routines', ...
          ppRoutines, ppChainIdx, ...
          {@routineConfig, 'Configure routine';
          @setDefaultRoutines, 'Default set'});
      
      % user cancelled dialog
      if isempty(ppChain) || cancel, return; end
      
      % save user's latest selection for next time - turn the ppChain
      % cell array into a space-separated string of the names
      ppChainStr = cellfun(@(x)([x ' ']), ppChain, 'UniformOutput', false);
      switch mode
          case 'profile'
              writeProperty('preprocessManager.preprocessChain.profile', ...
                  deblank([ppChainStr{:}]));
          otherwise
              writeProperty('preprocessManager.preprocessChain.timeSeries', ...
                  deblank([ppChainStr{:}]));
      end
  end
  
  if ~isempty(ppChain)
      % let user know what is going on in batch mode
      if auto 
          if strcmpi(qcLevel, 'raw')
              ppChainStr = cellfun(@(x)([x ' ']), ppChain, 'UniformOutput', false);
              fprintf('%s\n', ['Preprocessing using : ' ppChainStr{:}]);
          end
          progress = [];
      else
          progress = waitbar(...
              0, 'Running PP routines', ...
              'Name', 'Running PP routines',...
              'CreateCancelBtn', ...
              ['waitbar(1,gcbf,''Cancelling - please wait...'');'...
              'setappdata(gcbf,''cancel'',true)']);
          setappdata(progress,'cancel',false);
      end
  end
  
  for k = 1:length(ppChain)
      
      if ~auto
          % user cancelled progress bar
          if getappdata(progress, 'cancel'), sample_data = {}; break; end
          
          % update progress bar
          progVal = k / length(ppChain);
          progStr = ppChain{k};
          waitbar(progVal, progress, progStr);
      end
      
      ppFunc = str2func(ppChain{k});
      
      sample_data = ppFunc(sample_data, qcLevel, auto);
  end

  if ~auto && ~isempty(ppChain), delete(progress); end
end

%ROUTINECONFIG Called via the PP routine list selection dialog when the user
% chooses to configure a routine. If the selected routine has any configurable 
% options, a propertyDialog is displayed, allowing the user to configure
% the routine.
%
function [dummy1, dummy2] = routineConfig(routineName)

  dummy1 = {};
  dummy2 = {};
  
  % check to see if the routine has an associated properties file.
  propFileName = fullfile('Preprocessing', [routineName '.txt']);
  
  % ignore if there is no properties file for this routine
  if ~exist(propFileName, 'file'), return; end
  
  % display a propertyDialog, allowing configuration of the routine
  % properties.
  if strcmpi(routineName, 'depthPP')
      propertyDialog(propFileName, ',');
  else
      propertyDialog(propFileName);
  end
end

%SETDEFAULTROUTINES Called via the PP routine list selection dialog when the user
% chooses to set the list of routines to default.
%
function [ppRoutines, ppChain] = setDefaultRoutines(filterName)

  % get all PP routines that exist
  ppRoutines = listPreprocessRoutines();
  ppChain    = {};
  
  % get the toolbox execution mode. Values can be 'timeSeries' and 'profile'. 
  % If no value is set then default mode is 'timeSeries'
  mode = readProperty('toolbox.mode');
  
  % get default filter chain if there is one
  try
      ppChain = textscan(readProperty(['preprocessManager.preprocessDefaultChain.' mode]), '%s');
      ppChain = ppChain{1};
      
      % set last filter list to default
      qcChainStr = cellfun(@(x)([x ' ']), ppChain, 'UniformOutput', false);
      writeProperty(['preprocessManager.preprocessChain.' mode], deblank([qcChainStr{:}]));
  catch e
  end
  
end