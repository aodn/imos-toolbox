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
%   mode        - string, toolbox execution mode.
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
% Copyright (C) 2017, Australian Ocean Data Network (AODN) and Integrated 
% Marine Observing System (IMOS).
%
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation version 3 of the License.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
% GNU General Public License for more details.

% You should have received a copy of the GNU General Public License
% along with this program.
% If not, see <https://www.gnu.org/licenses/gpl-3.0.en.html>.
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
      ppChain = textscan(readProperty(['preprocessManager.preprocessChain.' mode]), '%s');
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
      [ppChain, cancel] = listSelectionDialog('Select Preprocessing routines', ...
          ppRoutines, ppChainIdx, ...
          {@routineConfig, 'Configure routine';
          @setDefaultRoutines, 'Default set'});
      
      % user cancelled dialog
      if isempty(ppChain) || cancel, return; end
      
      % save user's latest selection for next time - turn the ppChain
      % cell array into a space-separated string of the names
      ppChainStr = cellfun(@(x)([x ' ']), ppChain, 'UniformOutput', false);
      writeProperty(['preprocessManager.preprocessChain.' mode], ...
          deblank([ppChainStr{:}]));
  end
  
  if ~isempty(ppChain)
      % let user know what is going on in batch mode
      if auto 
          if strcmpi(qcLevel, 'qc') % so that we only display this once
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
  
  % get the toolbox execution mode
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