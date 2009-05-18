function viewMetadata(parent, fieldTrip, sample_data, updateCallback)
%VIEWMETADATA Displays metadata for the given data set in the given parent
% figure/uipanel.
%
% This function displays metadata contained in the given sample_data struct 
% in the given parent figure/uipanel. The tabbedPane function is used to
% separate global/dimension/variable attributes. Users are able to
% add/delete/modify field names and values. The provided updateCallback 
% function is called when any data is modified.
%
% Inputs:
%   parent         - handle to the figure/uipanel in which the metadata should
%                    be displayed.
%   fieldTrip      - struct containing field trip information.
%   sample_data    - struct containing sample data.
%   updateCallback - Function handle to a function which is called when
%                    any metadata is modified. The function must be of the
%                    form:
%                    
%                      function updateCallback(sample_data)
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
  error(nargchk(4, 4, nargin));

  if ~ishandle(parent),      error('parent must be a handle');           end
  if ~isstruct(fieldTrip),   error('fieldTrip must be a struct');        end
  if ~isstruct(sample_data), error('sample_data must be a struct');      end
  if ~isa(updateCallback,    'function_handle')
                             error('updateCallback must be a function'); end
  
  tables   = [];
  globdata = {};
  varData  = {};
  dimData  = {};
  
  %% create data sets
  
  globs = sample_data;
  globs = rmfield(globs, 'variables');
  globs = rmfield(globs, 'dimensions');
  
  dims = sample_data.dimensions;
  dims = rmfield(dims, 'data');
  
  vars = sample_data.variables;
  vars = rmfield(vars, 'data');
  vars = rmfield(vars, 'dimensions');
  
  % create a cell array containing global attribute data
  globData = [...
    fieldnames(globs)... 
    cellfun(@num2str,struct2cell(globs), 'UniformOutput', false)];
  
  % create cell array containing dimension 
  % attribute data (one per dimension)
  for k = 1:length(dims)
    
    dimData{k} = [...
      fieldnames(dims(k))...
      cellfun(@num2str,struct2cell(dims(k)), 'UniformOutput', false)];
  end
  
  % create cell array containing variable 
  % attribute data (one per variable)
  for k = 1:length(vars)
    
    varData{k} = [...
      fieldnames(vars(k))...
      cellfun(@num2str,struct2cell(vars(k)), 'UniformOutput', false)];
  end
  
  %% create uitables
  
  % create a uitable for each data set
  tables(1) = createTable(globData, '');
  
  for k = 1:length(dims)
    tables(end+1) = ...
      createTable(dimData{k}, ['dimensions(' num2str(k) ')']);
  end
  
  for k = 1:length(vars)
    tables(end+1) = ...
      createTable(varData{k}, ['variables('  num2str(k) ')']);
  end
  
  tableNames = {'Global'};
  for k = 1:length(dims), tableNames{end+1} = [dims(k).name ' dimension']; end
  for k = 1:length(vars), tableNames{end+1} = [vars(k).name ' variable'];  end
  
  % create a tabbedPane which displays each table in a separate tab
  panel = tabbedPane(parent, tables, tableNames, true);

  set(panel, 'Position', [0.0, 0.0, 1.0, 1.0]);
  
  % matlab is a piece of shit; column widths must be specified 
  % in pixels, so we have to get the table position in pixels 
  % to calculate the desired column width
  for k = 1:length(tables)
    
    set(tables(k), 'Units', 'pixels');
    pos = get(tables(k), 'Position');
    set(tables(k), 'Units', 'normalized');
    colWidth    = zeros(1,2);
    colWidth(1) = (pos(3) / 3);
    
    % -30 in case a vertical scrollbar is added
    colWidth(2) = (2*pos(3) / 3)-30; 
    set(tables(k), 'ColumnWidth', num2cell(colWidth));
  end

  function table = createTable(data, prefix)
  % Creates a uitable which contains the given data. 
    
    % create an empty cell at the end for user-added fields
    data{end+1,1} = '';
    data{end  ,2} = '';
    
    % create the table
    table = uitable(...
      'Visible',           'off',...
      'RowName',          [],...
      'RowStriping',      'on',...
      'ColumnName',       {'Name', 'Value'},...
      'ColumnEditable',   [true    true],...
      'ColumnFormat',     {'char', 'char'},...
      'CellEditCallback', @cellEditCallback,...
      'Data',             data);

    function cellEditCallback(source,ev)
    %CELLEDITCALLBACK Called when the user edits a cell. 
    %
      row = ev.Indices(1);
      col = ev.Indices(2);
      
      oldName  = data{row, 1};
      oldValue = data{row, 2};
      
      % user either edited the field name or the field value
      if col == 1
        newName  = ev.NewData;
        newValue = oldValue;
      else
        newName  = oldName;
        newValue = ev.NewData;
      end
      
      % apply the update
      applyUpdate(prefix, oldName, newName, newValue);
      
      % notify GUI of change to data
      updateCallback(sample_data);
        
      % user modified field name
      if col == 1 

        % user deleted a field? remove it 
        if isempty(newName)

          data(row,:) = [];
          set(table, 'Data', data);

        % user added a field? save it and add 
        % a new, empty row at the bottom
        elseif row == length(data)

          data{row,col} = ev.NewData;
          data{end+1,1} = '';
          data{end  ,2} = '';
          set(table, 'Data', data);
        end

      % user modified field value
      else

        % user tried to add a new field value 
        % without specifying the name? ignore it
        if row == length(data), set(table, 'Data', data);

        %otherwise save the change
        else data{row,col} = ev.NewData;
        end
      end
    end
  end

  function applyUpdate(prefix, oldName, newName, newValue)
  %APPLYUPDATE Applies the given field update to the sample_data struct.
  %
  % Inputs:
  %   prefix   - prefix to apply to struct name (e.g. if the field is in
  %              dimensions or variables).
  %   oldName  - old field name. If the field is a new field, this will be
  %              empty.
  %   newName  - new field name. If the field has been removed, this will
  %              be empty.
  %   newValue - new field value.
  %
    disp(' ');
    disp(['oldName: *' oldName  '*']);
    disp(['newName: *' newName  '*']);
    disp(['newValu: *' newValue '*']);
    
    % figure out the struct to which the changes are being applied
    structName = 'sample_data';
    if ~isempty(prefix), structName = [structName '.' prefix]; end

    % validate input - ignore bad input
    if  isempty(oldName) && isempty(newName),              return; end
    if ~isempty(oldName) && ...
       ~eval(['isfield(' structName ',''' oldName ''')']), return; end
    
    % cast value to numeric if needed/possible
    if ~isempty(newValue)

      % if an existing field, check the type of the old value
      if ~isempty(oldName)

        oldVal = eval([structName '.' oldName]);
        if ischar(oldVal) || isempty(oldVal)
          newValue = ['''' newValue '''']; 
        end

      % if a new field, try to cast; if fail, revert to string
      else
        temp = str2double(newValue);
        if isempty(temp), newValue = ['''' newValue '''']; end
      end
    else
      newValue = '''''';
    end
    
    % apply the change
    
    % new field
    if isempty(oldName)
      eval([structName '.' newName ' = ' newValue ';']);
      disp([structName '.' newName ' = ' newValue ';']);
    
    % delete field
    elseif isempty(newName)
      eval([structName ' = rmfield(' structName, ',''' oldName ''');']);
      disp([structName ' = rmfield(' structName, ',''' oldName ''');']);

    % existing value change
    elseif strcmp(oldName, newName)
      eval([structName '.' newName ' = ' newValue ';']);
      disp([structName '.' newName ' = ' newValue ';']);

    % field name change
    else
      disp([structName ' = rmfield(' structName ',''' oldName ''');']);
      eval([structName ' = rmfield(' structName ',''' oldName ''');']);
      disp([structName '.' newName ' = ' newValue ';']);
      eval([structName '.' newName ' = ' newValue ';']);
    end
  end
end
