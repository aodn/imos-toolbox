function qc_data = autoQCManager( sample_data, auto )
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
%   auto        - Optional boolean argument. If true, the automatic QC
%                 process is executed automatically (interesting, that),
%                 i.e. with no user interaction.
%
% Outputs:
%   qc_data     - Same as input, after QC routines have been run over it.
%                 Will be empty if the user cancelled/interrupted the QC
%                 process.
%
% Author:       Paul McCarthy <paul.mccarthy@csiro.au>
% Contributor:	Brad Morris <b.morris@unsw.edu.au>
%           	Guillaume Galibert <guillaume.galibert@utas.edu.au>
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
  narginchk(1,2);
  
  if ~iscell(sample_data)
    error('sample_data must be a cell array of structs'); 
  end
  
  if nargin == 1, auto = false; end
  
  qcSet = str2double(readProperty('toolbox.qc_set'));
  rawFlag       = imosQCFlag('raw',  qcSet, 'flag');
  goodFlag      = imosQCFlag('good', qcSet, 'flag');
  probGoodFlag  = imosQCFlag('probablyGood', qcSet, 'flag');
  probBadFlag   = imosQCFlag('probablyBad', qcSet, 'flag');
  badFlag       = imosQCFlag('bad', qcSet, 'flag');
  
  qc_data = {};

  % get all QC routines that exist
  qcRoutines = listAutoQCRoutines();
  qcChain    = {};

  % get last filter chain if there is one
  try
      % get the toolbox execution mode
      mode = readProperty('toolbox.mode');
      qcChain = textscan(readProperty(['autoQCManager.autoQCChain.' mode]), '%s');
      qcChain = qcChain{1};
  catch e
  end
  
  if ~auto
    
    % prompt user to select QC filters to run - the list of initially 
    % selected options is stored in toolboxProperties as routine names, 
    % but must be provided to the list selection dialog as indices
    qcChain = cellfun(@(x)(find(ismember(qcRoutines,x))),qcChain);
    [qcChain, qcCancel] = listSelectionDialog('Select QC routines', ...
        qcRoutines, qcChain, ...
        {@routineConfig, 'Configure routine';
        @setDefaultRoutines, 'Default set'});
    
	% save user's latest selection for next time - turn the qcChain
    % cell array into a space-separated string of the names
    if ~isempty(qcChain)
        qcChainStr = cellfun(@(x)([x ' ']), qcChain, 'UniformOutput', false);
        writeProperty(['autoQCManager.autoQCChain.' mode], deblank([qcChainStr{:}]));
    else
        if ~qcCancel
            writeProperty(['autoQCManager.autoQCChain.' mode], '');
        end
    end
    
    % no QC routines to run
    if qcCancel, return; end
  end
 
  if ~isempty(qcChain)
      if ~auto
          progress = waitbar(...
              0, 'Running QC routines', ...
              'Name', 'Running QC routines',...
              'CreateCancelBtn', ...
              ['waitbar(1,gcbf,''Cancelling - please wait...'');'...
              'setappdata(gcbf,''cancel'',true)']);
          setappdata(progress,'cancel',false);
      else
          %BDM - 17/08/2010 - Added disp to let user know what is going on in
          %batch mode
          qcChainStr = cellfun(@(x)([x ' ']), qcChain, 'UniformOutput', false);
          fprintf('%s\n', ['Quality control using : ' qcChainStr{:}]);
          progress = [];
      end
  end

  for k = 1:length(sample_data)
      % reset QC flags to 0
      type{1} = 'dimensions';
      type{2} = 'variables';
      for m = 1:length(type)
          for l = 1:length(sample_data{k}.(type{m}))
              if ~isfield(sample_data{k}.(type{m}){l}, 'flags'), continue; end
              sample_data{k}.(type{m}){l}.flags(:) = 0;
          end
      end
      
      % reset QC results
      sample_data{k}.meta.QCres = {};
  end
  
  % run each data set through the chain
  try
    for k = 1:length(sample_data)
      
      for m = 1:length(qcChain)

        if ~auto
          % user cancelled progress bar
          if getappdata(progress, 'cancel'), sample_data = {}; break; end

          % update progress bar
          progVal = ...
            ((k-1)*length(qcChain)+m) / (length(qcChain)*length(sample_data));
          progStr = [sample_data{k}.meta.instrument_make ' '...
                     sample_data{k}.meta.instrument_model ' ' qcChain{m}];
          waitbar(progVal, progress, progStr);
        end

        % run current QC routine over the current data set
        sample_data{k} = qcFilter(...
          sample_data{k}, qcChain{m}, auto, rawFlag, goodFlag, probGoodFlag, probBadFlag, badFlag, progress);

      
      
        % set level and file version on each QC'd data set
        sample_data{k}.meta.level = 1; 
        sample_data{k}.file_version = ...
          imosFileVersion(1, 'name');
        sample_data{k}.file_version_quality_control = ...
          imosFileVersion(1, 'desc');
      end
      
      if isempty(qcChain)
          rawFlag  = imosQCFlag('raw',  qcSet, 'flag');
          for l=1:length(sample_data{k}.variables)
              sample_data{k}.variables{l}.flags = rawFlag*ones(size(sample_data{k}.variables{l}.flags), 'int8');
          end
          
          % set level and file version on each unQC'd data set
          sample_data{k}.meta.level = 0;
          sample_data{k}.file_version = ...
              imosFileVersion(0, 'name');
          sample_data{k}.file_version_quality_control = ...
              imosFileVersion(0, 'desc');
      end
    end
  catch e
      %BDM - 16/08/2010 - Added if statement to stop error on auto runs
      if ishandle(progress)
          delete(progress);
      end
    rethrow(e);
  end
  
  if ~auto && ~isempty(qcChain), delete(progress); end

  qc_data = sample_data;
end

%ROUTINECONFIG Called via the QC routine list selection dialog when the user
% chooses to configure a routine. If the selected routine has any configurable 
% options, a propertyDialog is displayed, allowing the user to configure
% the routine.
%
function [dummy1, dummy2] = routineConfig(routineName)

  dummy1 = {};
  dummy2 = {};

  % check to see if the routine has an associated properties file.
  propFileName = fullfile('AutomaticQC', [routineName '.txt']);
  
  % ignore if there is no properties file for this routine
  if ~exist(propFileName, 'file'), return; end
  
  % display a propertyDialog, allowing configuration of the routine
  % properties.
  propertyDialog(propFileName);
end

%SETDEFAULTROUTINES Called via the QC routine list selection dialog when the user
% chooses to set the list of routines to default.
%
function [qcRoutines, qcChain] = setDefaultRoutines(filterName)

  % get all QC routines that exist
  qcRoutines = listAutoQCRoutines();
  qcChain    = {};
  
  % get the toolbox execution mode
  mode = readProperty('toolbox.mode');
  
  % get default filter chain if there is one
  try
      qcChain = textscan(readProperty(['autoQCManager.autoQCDefaultChain.' mode]), '%s');
      qcChain = qcChain{1};
      
      % set last filter list to default
      qcChainStr = cellfun(@(x)([x ' ']), qcChain, 'UniformOutput', false);
      writeProperty(['autoQCManager.autoQCChain.' mode], deblank([qcChainStr{:}]));
  catch e
  end
  
end