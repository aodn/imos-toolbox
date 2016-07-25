function viewMetadata(parent, sample_data, updateCallback, repCallback, mode)
%VIEWMETADATA Displays metadata for the given data set in the given parent
% figure/uipanel.
%
% This function displays NetCDF metadata contained in the given sample_data 
% struct in the given parent figure/uipanel. The tabbedPane function is used 
% to separate global/dimension/variable attributes. Users are able to
% modify field values. The provided updateCallback function is called when 
% any data is modified.
%
% Inputs:
%   parent         - handle to the figure/uipanel in which the metadata should
%                    be displayed.
%   sample_data    - struct containing sample data.
%   updateCallback - Function handle to a function which is called when
%                    any metadata is modified. The function must be of the
%                    form:
%                    
%                      function updateCallback(sample_data)
%
%   repCallback    - Function which is called when a selection of metadata
%                    fields should be replicated across all data sets. The
%                    function must be of the form:
%
%                      function repCallback(location, names, values)
%
%   mode           - Toolbox data type mode.
%
% Author:       Paul McCarthy <paul.mccarthy@csiro.au>
% Contributor:  Guillaume Galibert <guillaume.galibert@utas.edu.au>
%               Gordon Keith <gordon.keith@csiro.au>
%

%
% Copyright (c) 2016, Australian Ocean Data Network (AODN) and Integrated 
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
%     * Neither the name of the AODN/IMOS nor the names of its contributors 
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
  narginchk(5, 5);

  if ~ishandle(parent),      error('parent must be a handle');           end
  if ~isstruct(sample_data), error('sample_data must be a struct');      end
  if ~isa(updateCallback,    'function_handle')
                             error('updateCallback must be a function'); end
  if ~isa(repCallback,       'function_handle')
                             error('repCallback must be a function');    end
  
  %% create data sets
  dateFmt = readProperty('toolbox.timeFormat');
  
  globs = orderfields(sample_data);
  globs = rmfield(globs, 'meta');
  globs = rmfield(globs, 'variables');
  globs = rmfield(globs, 'dimensions');
 
  if isfield(sample_data.meta, 'channels')
      channels = orderfields(sample_data.meta.channels);
  else
      channels = [];
  end
  lenChans = length(channels);
  
  dims = sample_data.dimensions;
  lenDims = length(dims);
  for k = 1:lenDims
    if isfield(dims{k}, 'flags')
        dims{k} = rmfield(dims{k}, 'flags');
    end
    if isfield(dims{k}, 'typeCastFunc')
        dims{k} = rmfield(dims{k}, 'typeCastFunc');
    end
    dims{k} = orderfields(rmfield(dims{k}, 'data'));
  end
  
  vars = sample_data.variables;
  lenVars = length(vars);
  for k = 1:lenVars
    if isfield(vars{k}, 'typeCastFunc')
        vars{k} = rmfield(vars{k}, 'typeCastFunc');
    end
    vars{k} = orderfields(rmfield(vars{k}, {'data', 'dimensions', 'flags'})); 
  end
  
  % create a cell array containing global attribute data
  globData = [fieldnames(globs) struct2cell(globs)];
  
  chanData = cell(lenChans,1);
  for k=1:lenChans
      chanData{k} = [fieldnames(channels) struct2cell(channels(k))];
  end
  
  % create cell array containing dimension 
  % attribute data (one per dimension)
  dimData  = cell(lenDims, 1);
  for k = 1:lenDims, 
    dimData{k} = [fieldnames(dims{k}) struct2cell(dims{k})];
  end
  
  % create cell array containing variable 
  % attribute data (one per variable)
  varData  = cell(lenVars, 1);
  for k = 1:lenVars
    varData{k} = [fieldnames(vars{k}) struct2cell(vars{k})];
  end
  
  %% create uitables
  % create a uitable for each data set
  tables = nan(lenVars+lenDims+lenChans+1, 1);
  panels = nan(lenVars+lenDims+lenChans+1, 1);
  [tables(1) panels(1)] = createTable(globData, '', 'global', dateFmt, mode);
  
  for k = 1:lenChans
     [tables(k+1) panels(k+1)] = createTable(...
        chanData{k}, ['meta.channels(' num2str(k) ')'], 'global', dateFmt, mode);
  end
  
  for k = 1:lenDims
%     [tables(k+1) panels(k+1)] = createTable(...
%       dimData{k}, ['dimensions{' num2str(k) '}'], lower(dims{k}.name), dateFmt, mode);
    [tables(k+lenChans+1) panels(k+lenChans+1)] = createTable(...
        dimData{k}, ['dimensions{' num2str(k) '}'], 'dimension', dateFmt, mode);
  end
  
  for k = 1:lenVars
    [tables(k+lenDims+lenChans+1) panels(k+lenDims+lenChans+1)] = createTable(...
      varData{k}, ['variables{'  num2str(k) '}'], 'variable', dateFmt, mode);
  end
  
  tableNames =  cell(lenVars+lenDims+lenChans+1, 1);
  tableNames{1} = 'Global attributes';
  for k = 1:lenChans
    tableNames{k+1} = [channels(k).name ' channel attributes']; 
  end
  for k = 1:lenDims
    tableNames{k+lenChans+1} = [dims{k}.name ' dimension attributes']; 
  end
  for k = 1:lenVars
    tableNames{k+lenDims+lenChans+1} = [vars{k}.name ' variable attributes'];
  end
  
  % create a tabbedPane which displays each table in a separate tab.
  % for low table numbers use buttons, otherwise use a drop down list
  lenTables = length(tables);
  if lenTables <= 4
    tabPanel = tabbedPane(parent, panels, tableNames, true);
  else 
    tabPanel = tabbedPane(parent, panels, tableNames, false);
  end
  
  % column widths must be specified 
  % in pixels, so we have to get the table position in pixels 
  % to calculate the desired column width
  for k = 1:lenTables
    set(tables(k), 'Units', 'pixels');
    pos = get(tables(k), 'Position');
    colWidth    = zeros(1,2);
    colWidth(1) = (pos(3) / 3);
    
    % -20 in case a vertical scrollbar is added
    colWidth(2) = (2*pos(3) / 3)-20; 
    set(tables(k), 'ColumnWidth', num2cell(colWidth));
    set(tables(k), 'Units', 'normalized');
  end

  function [table panel] = createTable(data, prefix, tempType, dateFmt, mode)
  % Creates a uitable which contains the given data. 
  
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
          data{i,2} = sprintf('%.10g ', data{i,2});
        
        % make everything else a string - i'm assuming that when 
        % num2str is passed a string, it will return that string 
        % unchanged; this assumption holds for at least r2008, r2009
        otherwise, data{i,2} = num2str(data{i,2});
      end
    end
    
    % create uipanel which contains the table; set the 
    % 'Parent' property for now; the tabbedPane function 
    % will reset it (matlab in this situation, under 
    % linux at least, seems to have serious problems 
    % if the parent property is left unset)
    panel = uipanel(...
      'Parent',     parent,...
      'Visible',    'off',...
      'BorderType', 'none',...
      'Tag',        'metadataPanel'...
    );
    
    % create the table
    table = uitable(...
      'Parent',                panel,...
      'RowName',               [],...
      'RowStriping',           'on',...
      'ColumnName',            {'Name', 'Value'},...
      'ColumnEditable',        [false    true],...
      'ColumnFormat',          {'char', 'char'},...
      'CellEditCallback',      @cellEditCallback,...
      'CellSelectionCallback', @cellSelectCallback,...
      'Data',                  data,...
      'Tag',                   ['metadataTable' prefix]);
    
    % create a button for replicate option
    repButton = uicontrol(...
        'Parent',   panel,...
        'Style',   'pushbutton',...
        'String',  'Replicate',...
        'ToolTip', 'Replicate the content of the selected cell across all imported datasets',...
        'Callback', @repButtonCallback...
        );
    
%     % create a button for adding metadata fields
%     addButton = uicontrol(...
%       'Parent',   panel,... 
%       'Style',   'pushbutton',...
%       'String',  'Add',...
%       'ToolTip', 'Add a new attribute to the current table', ...
%       'Callback', @addButtonCallback...
%     );

    % position table and button
    set(panel,     'Units', 'normalized');
    set(table,     'Units', 'normalized');
    set(repButton, 'Units', 'normalized');
%     set(addButton, 'Units', 'normalized');
    
%     set(table,     'Position', [0.0, 0.0, 0.9, 1.0]);
    set(table,     'Position', posUi2(panel, 1, 10, 1, 1:9, 0));
%     set(repButton, 'Position', [0.9, 0.8, 0.1, 0.2]);
    set(repButton, 'Position', posUi2(panel, 10, 10, 1:2, 10, 0));
%    set(addButton, 'Position', [0.9, 0.6, 0.1, 0.2]);
%     set(addButton, 'Position', posUi2(panel, 10, 10, 3:4, 10, 0));
    
%     set(table,     'Units', 'pixels');
%     set(repButton, 'Units', 'pixels');
%     set(panel,     'Units', 'pixels');
    
    selectedCells = [];
    
    function repButtonCallback(source, ev)
    %REPBUTTONCALLBACK Called when the user pushes the replicate button;
    % passes the list of field names, and the type (global, variable or
    % dimension) to the repCallback function.
    %
      % get the selected field names - the values are retrieved 
      % from the sample_data struct rather than the table data, 
      % as the table data is all strings
      if isempty(selectedCells)
          return;
      else
          names  = data(unique(selectedCells(:,1)),1);
      end
      
      structName = 'sample_data';
      if ~isempty(prefix), structName = [structName '.' prefix]; end
      
      % figure out the location; it is passed to repCallback as:
      %   - 'global'
      %   - 'VARNAME variable'
      %   - 'DIMNAME dimension'
      %
      location = '';
      
      if strcmp(prefix, '')
        location = 'global';
        
      elseif strncmp(prefix, 'variables',  8)
        location = [eval([structName '.name']) ' variable'];
        
      elseif strncmp(prefix, 'dimensions', 9)
        location = [eval([structName '.name']) ' dimension'];
      end
      
      % get the field values from the sample data struct
      lenNames = length(names);
      values = cell(lenNames, 1);
      for j = 1:lenNames
        values{j} = eval([structName '.' names{j}]);
      end
      
      % call repCallback
      repCallback(location, names, values);
    end
    
%     function addButtonCallback(~, ~)
%     %ADDBUTTONCALLBACK Called when the user pushes the add button;
%     % asks the user for the name of a metadata field to add and adds it as
%     % a string attribute
%     
%         name = inputdlg('Name of field to add', 'Add metadata');
%         if ~isempty(name) && ~isempty(name{1})
%             % clean name
%             name = strtrim(name{1});
%             name(name == ' ') = '_';
%             valid = isstrprop(name, 'alphanum') | ...
%                 name == '_';
%             name = name(valid);
%             
%             %check if name exists
%             dat = get(table, 'Data');
%             for d = 1:length(dat)
%                 if strcmp(dat{d,1}, name)
%                     return;
%                 end
%             end
%             
%             % add name
%             dat{end + 1, 1} = name;
%             dat{end, 2} = '';
%             set(table, 'Data', dat);
%         end
%     end
    
    function cellSelectCallback(source,ev)
    %CELLSELECTCALLBACK Updates the selectedCells variable whenever the
    % cell selection changes. The uitable provides no ability to query the
    % currently selected cells, so we have to use this callback. Matlab
    % sucks.
      selectedCells = ev.Indices;
    end

    function cellEditCallback(source,ev)
    %CELLEDITCALLBACK Called when the user edits a cell. 
    %
      row = ev.Indices(1);
      
      fieldName = data{row, 1};
      oldValue  = data{row, 2};
      newValue  = ev.NewData;
      
      % apply the update
      try applyUpdate(prefix, templateDir, fieldName, newValue, tempType);
      
      catch e
          errorString = getErrorString(e);
          fprintf('%s\n',   ['Error says : ' errorString]);
          
          % display an error
          errordlg(e.message, 'Error');
          
          % revert uitable dataset
          set(table, 'Data', data);
          return;
      end
      
      % notify GUI of change to data
      updateCallback(sample_data);
        
      %save the change - the uitable updates itself
      data{row,2} = newValue;
    end
  end

  function applyUpdate(prefix, templateDir, fieldName, fieldValue, tempType)
  %APPLYUPDATE Applies the given field update to the sample_data struct.
  %
  % Inputs:
  %   prefix     - prefix to apply to struct name (e.g. if the field is in
  %                dimensions or variables).
  %   fieldName  - Name of field being edited.
  %   fieldValue - new field value.
  %   tempType   - netcdf attribute template type (passed to the templateType
  %                function).
  %
    
    % figure out the struct to which the changes are being applied
    structName = 'sample_data';
    if ~isempty(prefix), structName = [structName '.' prefix]; end
       
    % cast value to appropriate type; fieldValue remains a 
    % string, but the actual values assigned to the struct 
    % in the eval statements below will sort out the type
    if ~isempty(fieldValue)
      
      % get the type of the attribute
      t = templateType(templateDir, fieldName, tempType, mode);
      switch t

        % dates are matlab serial numeric values
        case 'D'

          try
            % datestr is rubbish - doesn't catch trailing characters
            if length(fieldValue) ~= length(dateFmt)
              error('bad length'); 
            end

            fieldValue = ['datenum(''' fieldValue ''', dateFmt)'];

          % reject poorly formatted date strings
          catch e
            error([fieldName ...
                   ' must be a (UTC) date in this format:  ''' dateFmt '''']);
          end

        % numbers are just numbers
        case 'N'
          temp = str2num(fieldValue); %#ok<ST2NM> str2num used on purpose to deal with arrays

          % reject anything that is not a number
          if isempty(temp)
            error([fieldName ' must be a number']); 
          end

          if length(temp) > 1
            fieldValue = ['[' fieldValue ']'];
          end

        % qc flag is different depending on qc set in use
        case 'Q'

          % i'm assuming that QC modifications will very rarely occur,
          % so the file lookups here shouldn't be too costly
          qcSet  = str2double(readProperty('toolbox.qc_set'));
          qcType = imosQCFlag('', qcSet, 'type');

          switch qcType

            case 'byte'
              temp = int8(str2double(fieldValue));
              if isempty(temp), error([fieldName ' must be a byte']); end

            case 'char'
              fieldValue = ['''' fieldValue ''''];
          end

        % everything else is a string
        otherwise, fieldValue = ['''' fieldValue ''''];
      end
    else fieldValue = '''''';
    end
    
    % apply the change
    eval([structName '.' fieldName ' = ' fieldValue ';']);
  end
end
