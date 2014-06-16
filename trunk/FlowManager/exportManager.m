function exportManager(dataSets, levelNames, output, auto)
%EXPORTMANAGER Manages the export of data to NetCDF or raw data files.
%
% Inputs:
%   dataSets   - Cell array containing the data levels, each of which is a 
%                cell array of sample data structs. All of the sample data 
%                cell arrays must be of the same length.
%
%   levelNames - Cell array containing the names of each data level (e.g. 
%                'raw', 'QC')
%
%   output     - either 'netcdf' or 'raw'.
%
%   auto       - Optional boolean argument. If true, the export process
%                will run automatically (i.e. with no user interaction).
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
  error(nargchk(3,4,nargin));

  if ~iscell(dataSets),      error('dataSets must be a cell array');   end
  if ~iscellstr(levelNames), error('levelNames must be a cell array'); end
  if ~ischar(output),        error('output must be a string');         end
  
  if nargin == 3, auto = false; end
  
  if isempty(dataSets),      error('dataSets cannot be empty');        end
  if length(dataSets) ~= length(levelNames)
    error('dataSets and levelNames must be the same length'); 
  end
  
  numLevels = length(dataSets);
  numSets   = length(dataSets{1});
  for k = 2:length(dataSets)
    if length(dataSets{k}) ~= numSets, error('data set length mismatch'); end
  end
  
  suffix = '';
  varOpts = false;
  switch (output)
    case 'raw', suffix = 'txt';
    case 'netcdf'
      varOpts = true;
      suffix = 'nc';
    otherwise,     error(['unknown output type: ' output]);
  end
    
  % get the toolbox execution mode. Values can be 'timeSeries' and 'profile'. 
  % If no value is set then default mode is 'timeSeries'
  mode = lower(readProperty('toolbox.mode'));
  
  % prompt user for export directory, and data sets to export
  if ~auto
    
    setNames = {};
    for k = 1:numSets
      setNames{k} = genIMOSFileName(dataSets{1}{k}, suffix); 
    end
    
    [exportDir dataSets] = ...
      exportDialog(dataSets, levelNames, setNames, varOpts);
  else
    exportDir = readProperty('exportDialog.defaultDir');
    
    for k = 2:numLevels, dataSets{1} = [dataSets{1} dataSets{k}]; end
    dataSets = dataSets{1};
  end
  
  % user cancelled dialog or selected no data sets
  if isempty(exportDir) || isempty(dataSets), return; end
  
  filenames = {};
  errors    = {};
  
  if ~auto
    progress = waitbar(0, 'Exporting data', ...
      'Name',                  'Exporting',...
      'DefaultTextInterpreter','none');
  end
  
  % write out each of the selected data sets in the specified format
  for k = 1:length(dataSets)
    
    try
      switch (output)
        case 'netcdf'
            filenames{end+1} = exportNetCDF(dataSets{k}, exportDir, mode);
        case 'raw'
            filenames{end+1} = exportRawData(dataSets{k}, exportDir, setNames{k});
      end
      if ~auto
          waitbar(k / length(dataSets), progress, ['Exported ' filenames{end}]);
      end
      
    catch e
      errors = [errors [setNames{ceil(k / numLevels)} ': ' e.message]];
      
      % display the full error message
      fullError = sprintf('%s\r\n', e.message);
      s = e.stack;
      for i=1:length(s)
          fullError = [fullError, sprintf('\t%s\t(%s: %i)\r\n', s(i).name, s(i).file, s(i).line)];
      end
      disp(fullError);
    end
  end
  
  % generate plots
  if any(strcmpi('QC', levelNames)) && strcmpi(mode, 'timeseries')
      exportPlots(dataSets, exportDir);
      
  end
  
  if ~auto
    close(progress);
  
    % display short message to user
    msg = '';
    icon = 'none';
    if isempty(errors)
        msg = 'All files exported';
    else
      if isempty(filenames)
        msg = sprintf('No files exported\n\n');
      else
        msg = sprintf([num2str(length(filenames)) ' file(s) exported\n\n']);
      end
      
      msg  = [msg cellCons(errors, sprintf('\n\n'))];
      icon = 'error';
    end
    
    uiwait(msgbox(msg, 'Export', icon, 'non-modal'));
  end
end

function filename = exportRawData(sample_data, exportDir, dest)
%EXPORTRAWDATA Copies the raw data file for the given sample_data to the
% given exportDir/dest. Relies upon the existence of the field
% sample_data.meta.raw_data_file, which must contain a semi-colon separated
% string of absolute paths to the raw data files associated with the
% sample_data struct.
%
filename = dest;
rawFiles = sample_data.meta.raw_data_file;

rawFiles = textscan(rawFiles, '%s', 'Delimiter', ';');
rawFiles = rawFiles{1};

if length(rawFiles) == 1
    copyfile(rawFiles{1}, [exportDir filesep dest]);
else
    for k = 1:length(rawFiles)
        % ugly hack to follow IMOS convention
        % for splitting over multiple files
        d = [dest(1:end-4) '_PART' num2str(k) '.txt'];
        copyfile(rawFiles{k}, [exportDir filesep dest]);
    end
end
end

function exportPlots(sample_data, exportDir)
%EXPORTPLOTS plot only parameters that have been QC'd per mooring.
%
% Lists all the distinct QC'd variables in every sample_data, for each of the 1D variable of them, 
% when it is found in multiple sample_data then plot all of them on the same axis.
% Output PNG file names would be something close to the dataset filename like 
% IMOS_[sub-facility_code]_[site_code]_FV01_[deployment_code]_[PARAM]_flags_C-[creation_date].png and 
% IMOS_[sub-facility_code]_[site_code]_FV01_[deployment_code]_[PARAM]_good-values_C-[creation_date].png
% respectively ploting the flag colors on top of the original raw data and
% only the values of good data (flags 1 or 2).
%

% get all params from datasets datasets
lenSampleData = length(sample_data);
paramsName = {};
for i=1:lenSampleData
    lenParamsSample = length(sample_data{i}.variables);
    for j=1:lenParamsSample
        if i==1 && j==1
            flags = sample_data{1}.variables{1}.flags;
            if all(all(flags ~= 0)), paramsName{1} = sample_data{1}.variables{1}.name; end
        else
            flags = sample_data{i}.variables{j}.flags;
            if all(all(flags ~= 0)), paramsName{end+1} = sample_data{i}.variables{j}.name; end
        end
    end
end

paramsName = unique(paramsName);
nParams = length(paramsName);
for i=1:nParams
    plotMooring1DVar(sample_data, paramsName{i}, true, true, exportDir);
    scatterMooring1DVarAgainstDepth(sample_data, paramsName{i}, true, true, exportDir);
    pcolorMooring2DVar(sample_data, paramsName{i}, true, true, exportDir);
end

end
