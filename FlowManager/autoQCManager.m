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
  error(nargchk(1,2,nargin));
  
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

  % get default filter chain if there is one
  try
    qcChain = textscan(readProperty('autoQCManager.autoQCChain'), '%s');
    qcChain = qcChain{1};
  catch e
  end
  
  if ~auto
    
    % prompt user to select QC filters to run - the list of initially 
    % selected options is stored in toolboxProperties as routine names, 
    % but must be provided to the list selection dialog as indices
    qcChain = cellfun(@(x)(find(ismember(qcRoutines,x))),qcChain);
    [qcChain, qcCancel] = listSelectionDialog('Select QC filters', qcRoutines, ...
                                  qcChain, @filterConfig, 'Configure');
    
	% save user's latest selection for next time - turn the qcChain
    % cell array into a space-separated string of the names
    if ~isempty(qcChain)
        qcChainStr = cellfun(@(x)([x ' ']), qcChain, 'UniformOutput', false);
        writeProperty('autoQCManager.autoQCChain', deblank([qcChainStr{:}]));
    else
        if ~qcCancel
            writeProperty('autoQCManager.autoQCChain', '');
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
          progress = nan;
      end
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
              sample_data{k}.variables{l}.flags = rawFlag*ones(size(sample_data{k}.variables{l}.flags));
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

%FILTERCONFIG Called via the QC filter list selection dialog when the user
% chooses to configure a filter. If the selected filter has any configurable 
% options, a propertyDialog is displayed, allowing the user to configure
% the filter.
%
function filterConfig(filterName)

  % check to see if the filter has an associated properties file.
  propFileName = fullfile('AutomaticQC', [filterName '.txt']);
  
  % ignore if there is no properties file for this filter
  if ~exist(propFileName, 'file'), return; end
  
  % display a propertyDialog, allowing configuration of the filter
  % properties.
  propertyDialog(propFileName);
end

function sam = qcFilter(sam, filterName, auto, rawFlag, goodFlag, probGoodFlag, probBadFlag, badFlag, cancel)
%QCFILTER Runs the given data set through the given automatic QC filter.
%
  % turn routine name into a function
  filter = str2func(filterName);
  
  % if this filter is a Set QC filter, we pass the entire data set
  if ~isempty(regexp(filterName, 'SetQC$', 'start'))
    
    fsam = filter(sam, auto);
    
    % Currently only flags are copied across; other changes to the data set
    % are discarded. Flags are overwritten - if a later routine flags 
    % the same value as a previous routine with a higher flag, the previous
    % flag is overwritten by the latter.
    type{1} = 'dimensions';
    type{2} = 'variables';
    for m = 1:length(type)
        for k = 1:length(sam.(type{m}))
            
            % Set current flag areas
            canBeFlagGoodIdx      = sam.(type{m}){k}.flags == rawFlag;
            
            canBeFlagProbGoodIdx  = canBeFlagGoodIdx | ...
                sam.(type{m}){k}.flags == goodFlag;
            
            canBeFlagProbBadIdx   = canBeFlagProbGoodIdx | ...
                sam.(type{m}){k}.flags == probGoodFlag;
            
            canBeFlagBadIdx       = canBeFlagProbBadIdx | ...
                sam.(type{m}){k}.flags == probBadFlag;
            
            % Look for the current test flags provided
            goodIdx     = fsam.(type{m}){k}.flags == goodFlag;
            probGoodIdx = fsam.(type{m}){k}.flags == probGoodFlag;
            probBadIdx  = fsam.(type{m}){k}.flags == probBadFlag;
            badIdx      = fsam.(type{m}){k}.flags == badFlag;
            
            % update new flags in current variable
            goodIdx     = canBeFlagGoodIdx & goodIdx;
            probGoodIdx = canBeFlagProbGoodIdx & probGoodIdx;
            probBadIdx  = canBeFlagProbBadIdx & probBadIdx;
            badIdx      = canBeFlagBadIdx & badIdx;
            
            sam.(type{m}){k}.flags(goodIdx)     = fsam.(type{m}){k}.flags(goodIdx);
            sam.(type{m}){k}.flags(probGoodIdx) = fsam.(type{m}){k}.flags(probGoodIdx);
            sam.(type{m}){k}.flags(probBadIdx)  = fsam.(type{m}){k}.flags(probBadIdx);
            sam.(type{m}){k}.flags(badIdx)      = fsam.(type{m}){k}.flags(badIdx);
            
            % add a log entry
            qcSet    = str2double(readProperty('toolbox.qc_set'));
                
            uFlags = unique(fsam.(type{m}){k}.flags);
            % we're just keeping trace of flags given other than 0 or 1
            % (has failed the test)
            uFlags(uFlags == rawFlag) = [];
            uFlags(uFlags == goodFlag) = [];
            
            if isempty(uFlags)
                sam.meta.log{end+1} = [filterName ...
                        ' didn''t fail on any ' ...
                        sam.(type{m}){k}.name ' sample'];
            else
                for i=1:length(uFlags)
                    flagString = ['"' imosQCFlag(uFlags(i),  qcSet, 'desc') '"'];
                    
                    flagIdxI = fsam.(type{m}){k}.flags == uFlags(i);
                    canBeFlagIdx = sam.(type{m}){k}.flags < uFlags(i);
                    flagIdxI = canBeFlagIdx & flagIdxI;
                    nFlag = sum(sum(flagIdxI));
                    sam.meta.log{end+1} = [filterName ...
                        ' flagged ' num2str(nFlag) ' ' ...
                        sam.(type{m}){k}.name ' samples with flag ' flagString];
                end
            end
        end
    end
  
  % otherwise we pass dimensions/variables one at a time
  else
    % check dimensions first, then variables
    type{1} = 'dimensions';
    type{2} = 'variables';
    for m = 1:length(type)
        for k = 1:length(sam.(type{m}))
            
            data  = sam.(type{m}){k}.data;
            flags = sam.(type{m}){k}.flags;
            
            % user cancelled
            if ~isnan(cancel) && getappdata(cancel, 'cancel'), return; end
            
            % log entries and any data changes that the routine generates
            % are currently discarded; only the flags are retained.
            [d f l] = filter(sam, data, k, type{m}, auto);
            
            if isempty(f), continue; end
            
            % Flags are overwritten
            % Set current flag areas
            canBeFlagGoodIdx      = flags == rawFlag;
            
            canBeFlagProbGoodIdx  = canBeFlagGoodIdx | ...
                flags == goodFlag;
            
            canBeFlagProbBadIdx   = canBeFlagProbGoodIdx | ...
                flags == probGoodFlag;
            
            canBeFlagBadIdx       = canBeFlagProbBadIdx | ...
                flags == probBadFlag;
            
            % Look for the current test flags provided
            goodIdx     = f == goodFlag;
            probGoodIdx = f == probGoodFlag;
            probBadIdx  = f == probBadFlag;
            badIdx      = f == badFlag;
            
            % update new flags in current variable
            goodIdx     = canBeFlagGoodIdx & goodIdx;
            probGoodIdx = canBeFlagProbGoodIdx & probGoodIdx;
            probBadIdx  = canBeFlagProbBadIdx & probBadIdx;
            badIdx      = canBeFlagBadIdx & badIdx;
            
            flags(goodIdx)     = f(goodIdx);
            flags(probGoodIdx) = f(probGoodIdx);
            flags(probBadIdx)  = f(probBadIdx);
            flags(badIdx)      = f(badIdx);
            
            sam.(type{m}){k}.flags = flags;
            
            % add a log entry
            qcSet    = str2double(readProperty('toolbox.qc_set'));
            % update count (for log entry)
            uFlags = unique(f)+1; % +1 because uFlags can be 0 and will then be used as an index
            % we're just keeping trace of flags given other than 0 or 1
            uFlags(uFlags-1 == rawFlag) = [];
            uFlags(uFlags-1 == goodFlag) = [];
            
            if isempty(uFlags)
                sam.meta.log{end+1} = [filterName ...
                        ' didn''t fail on any ' ...
                        sam.(type{m}){k}.name ' sample'];
            else
                for i=1:length(uFlags)
                    uFlagIdx = f == uFlags(i)-1;
                    canBeFlagIdx = flags < uFlags(i)-1;
                    uFlagIdx = canBeFlagIdx & uFlagIdx;
                    if ismatrix(data)
                        nFlag = sum(sum(uFlagIdx));
                    else
                        nFlag = sum(uFlagIdx);
                    end
                    flagString = ['"' imosQCFlag(uFlags(i)-1,  qcSet, 'desc') '"'];
                    sam.meta.log{end+1} = [filterName ...
                        ' flagged ' num2str(nFlag) ' ' ...
                        sam.(type{m}){k}.name ' samples with flag ' flagString];
                end
            end
        end
    end
  end
end
