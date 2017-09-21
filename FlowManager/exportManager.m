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
    
  % get the toolbox execution mode
  mode = readProperty('toolbox.mode');
  
  setNames = cell(numSets, 1);
  for k = 1:numSets
      setNames{k} = genIMOSFileName(dataSets{1}{k}, suffix);
  end
    
  % prompt user for export directory, and data sets to export
  if ~auto
    [exportDir, dataSets] = ...
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
  
  progress = [];
  if ~auto
    progress = waitbar(0, 'Exporting data files', ...
      'Name',                  'Exporting files',...
      'DefaultTextInterpreter','none');
  end
  
  % write out each of the selected data sets in the specified format
  nDataSets = length(dataSets);
  for k = 1:nDataSets
    
    try
      switch (output)
        case 'netcdf'
            filenames{end+1} = exportNetCDF(dataSets{k}, exportDir, mode);
        case 'raw'
            filenames{end+1} = exportRawData(dataSets{k}, exportDir, setNames{k});
      end
      if ~auto
          [~, radFile, ext] = fileparts(filenames{end});
          waitbar(k / nDataSets, progress, [radFile ext]);
      end
      
    catch e
      % display file name for which we have an error
      errorFile = [setNames{ceil(k / numLevels)} ': ' e.message];
      errors = [errors errorFile];
      disp(errorFile);
      % display the full error message
      fullError = sprintf('%s\r\n', e.message);
      s = e.stack;
      for i=1:length(s)
          fullError = [fullError, sprintf('\t%s\t(%s: %i)\r\n', s(i).name, s(i).file, s(i).line)];
      end
      disp(fullError);
    end
  end
  
  % retrieve visualQC config
  try
      export = eval(readProperty('visualQC.export'));
  catch e %#ok<NASGU>
      export = true;
  end
  
  if export
      % generate QC'd plots
      exportQCPlots(dataSets, exportDir, mode, auto, progress);
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

function exportQCPlots(sample_data, exportDir, mode, auto, progress)
%EXPORTQCPLOTS only plot parameters that have been QC'd.
%
% Lists all the distinct QC'd variables in every sample_data, for each of the 1D variable of them, 
% when it is found in multiple sample_data then plot all of them on the same axis.
% Output PNG file names are specific and plot only the values of good data (flags 1 or 2).
%

% only keep FV01 sample_data
nSampleData = length(sample_data);
for i=1:nSampleData
    if sample_data{i}.meta.level == 0
        sample_data{i} = [];
    end
end

iEmptySample = cellfun(@isempty, sample_data);
if any(iEmptySample)
    sample_data(iEmptySample) = [];
end

if isempty(sample_data)
    return;
end

% get all params from dataset
paramsName = {};
nSampleData = length(sample_data);
for i=1:nSampleData
    lenParamsSample = length(sample_data{i}.variables);
    for j=1:lenParamsSample
        if i==1 && j==1
            flags = sample_data{i}.variables{1}.flags;
            if all(all(flags ~= 0)), paramsName{1} = sample_data{i}.variables{1}.name; end
        else
            flags = sample_data{i}.variables{j}.flags;
            if all(all(flags ~= 0)), paramsName{end+1} = sample_data{i}.variables{j}.name; end
        end
    end
end


if ~auto
    waitbar(0, progress, 'Exporting plot files');
end

paramsName = unique(paramsName);

try
    switch mode
        case 'timeSeries'
            % we get rid of specific parameters
            notNeededParams = {'TIMESERIES', 'PROFILE', 'TRAJECTORY', 'LATITUDE', 'LONGITUDE', 'NOMINAL_DEPTH'};
            for i=1:length(notNeededParams)
                iNotNeeded = strcmpi(paramsName, notNeededParams{i});
                paramsName(iNotNeeded) = [];
            end
            
            % timeseries specific plots
            checkMooringPlannedDepths(sample_data, true, true, exportDir);
            nParams = length(paramsName);
            for i=1:nParams
                if ~auto
                    waitbar(i / nParams, progress, ['Exporting ' paramsName{i} ' plots']);
                end
                lineMooring1DVar(sample_data, paramsName{i}, true, true, exportDir);
                scatterMooring1DVarAgainstDepth(sample_data, paramsName{i}, true, true, exportDir);
                scatterMooring2DVarAgainstDepth(sample_data, paramsName{i}, true, true, exportDir);
                diagramMooring1DVarAgainstOther(sample_data, paramsName{i}, 'DEPTH', true, true, exportDir);
                diagramMooring2DVarAgainstOther(sample_data, paramsName{i}, 'DEPTH', true, true, exportDir);
            end
            
        case 'profile'
            % profile specific plots
            lineCastVar(sample_data, paramsName, true, true, exportDir);

    end
catch e
    errorString = getErrorString(e);
    fprintf('%s\n',   ['Error says : ' errorString]);
end

end
