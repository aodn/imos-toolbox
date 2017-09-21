function updateViewMetadata(parent, sample_data, mode)
%UPDATEVIEWMETADATA Updates the display of metadata for the given data set in the given parent
% figure/uipanel.
%
% This function displays NetCDF metadata contained in the given sample_data 
% struct in the given parent figure/uipanel. The tabbedPane function is used 
% to separate global/dimension/variable attributes. Users are able to
% modify field values.
%
% Inputs:
%   parent         - handle to the figure/uipanel in which the metadata should
%                    be displayed.
%   sample_data    - struct containing sample data.
%   mode           - Toolbox data type mode.
%
% Author: Guillaume Galibert <guillaume.galibert@utas.edu.au>
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
  narginchk(3, 3);

  if ~ishandle(parent),      error('parent must be a handle');           end
  if ~isstruct(sample_data), error('sample_data must be a struct');      end
  
  %% create data sets
  
  dateFmt = readProperty('toolbox.timeFormat');
  
  globs = orderfields(sample_data);
  globs = rmfield(globs, 'meta');
  globs = rmfield(globs, 'variables');
  globs = rmfield(globs, 'dimensions');
  
  dims = sample_data.dimensions;
  lenDims = length(dims);
  for k = 1:lenDims
      fieldsToBeRemoved = {'data', 'typeCastFunc', 'flags'};
      iToBeRemoved = isfield(dims{k}, fieldsToBeRemoved);
      if any(iToBeRemoved)
          dims{k} = rmfield(dims{k}, fieldsToBeRemoved(iToBeRemoved));
      end
      dims{k} = orderfields(dims{k});
  end
  
  vars = sample_data.variables;
  lenVars = length(vars);
  for k = 1:lenVars
      fieldsToBeRemoved = {'data', 'dimensions', 'typeCastFunc', 'flags'};
      iToBeRemoved = isfield(vars{k}, fieldsToBeRemoved);
      if any(iToBeRemoved)
          vars{k} = rmfield(vars{k}, fieldsToBeRemoved(iToBeRemoved));
      end
      vars{k} = orderfields(vars{k});
  end
  
  % create a cell array containing global attribute data
  globData = [fieldnames(globs) struct2cell(globs)];
  
  if strcmpi(mode, 'timeSeries')
      % create cell array containing dimension
      % attribute data (one per dimension)
      dimData  = cell(lenDims, 1);
      for k = 1:lenDims
          dimData{k} = [fieldnames(dims{k}) struct2cell(dims{k})];
      end
  end
  
  % create cell array containing variable 
  % attribute data (one per variable)
  varData  = cell(lenVars, 1);
  for k = 1:lenVars
    varData{k} = [fieldnames(vars{k}) struct2cell(vars{k})];
  end
  
  %% update uitables
  
  % update a uitable for each data set
  updateTable(globData, '', 'global', dateFmt, mode);
  
  % get path to templates subdirectory
  path = readProperty('toolbox.templateDir');
  if isempty(path) || ~exist(path, 'dir')
    path = '';
    if ~isdeployed, [path, ~, ~] = fileparts(which('imosToolbox.m')); end
    if isempty(path), path = pwd; end
    path = fullfile(path, 'NetCDF', 'template');
  end
  
  if strcmpi(mode, 'timeSeries')
      for k = 1:length(dims)
          temp = fullfile(path, [lower(dims{k}.name) '_attributes.txt']);
          if exist(temp, 'file')
              updateTable(...
                  dimData{k}, ['dimensions{' num2str(k) '}'], lower(dims{k}.name), dateFmt, mode);
          else
              updateTable(...
                  dimData{k}, ['dimensions{' num2str(k) '}'], 'dimension', dateFmt, mode);
          end
      end
  end
  
  for k = 1:length(vars)
    updateTable(...
      varData{k}, ['variables{'  num2str(k) '}'], 'variable', dateFmt, mode);
  end

  function updateTable(data, prefix, tempType, dateFmt, mode)
  % Updates a uitable which contains the given data. 
  
    % format data - they're all made into strings, and cast 
    % back when edited. also we want date fields to be 
    % displayed nicely, not to show up as a numeric value
    templateDir = readProperty('toolbox.templateDir');
    for i = 1:size(data, 1)
      
      % get the type of the attribute
      t = templateType(templateDir, data{i,1}, tempType, mode);
      
      switch t
        
        % format dates
        case 'D',  
          data{i,2} = datestr(data{i,2}, dateFmt);
        
        % make sure numeric values are not rounded (too much)
        case 'N',
          data{i,2} = sprintf('%.10f ', data{i,2});
        
        % make everything else a string - i'm assuming that when 
        % num2str is passed a string, it will return that string 
        % unchanged; this assumption holds for at least r2008, r2009
        otherwise, data{i,2} = num2str(data{i,2});
      end
    end
    
    % get the table and update it
    hTable = findobj('Tag', ['metadataTable' prefix]);
    set(hTable, 'Data', data);
  end
end