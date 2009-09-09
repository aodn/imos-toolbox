function viewMetadata(parent, sample_data, updateCallback)
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
  error(nargchk(3, 3, nargin));

  if ~ishandle(parent),      error('parent must be a handle');           end
  if ~isstruct(sample_data), error('sample_data must be a struct');      end
  if ~isa(updateCallback,    'function_handle')
                             error('updateCallback must be a function'); end
  
  tables   = [];
  globdata = {};
  varData  = {};
  dimData  = {};
  
  %% create data sets
  
  dateFmt = readToolboxProperty('toolbox.timeFormat');
  
  globs = sample_data;
  globs = rmfield(globs, 'meta');
  globs = rmfield(globs, 'variables');
  globs = rmfield(globs, 'dimensions');
  
  dims = sample_data.dimensions;
  for k = 1:length(dims), dims{k} = rmfield(dims{k}, {'data', 'flags'}); end
  
  vars = sample_data.variables;
  for k = 1:length(vars), 
    vars{k} = rmfield(vars{k}, {'data', 'dimensions', 'flags'}); 
  end
  
  % create a cell array containing global attribute data
  globData = [fieldnames(globs) struct2cell(globs)];
  
  % create cell array containing dimension 
  % attribute data (one per dimension)
  for k = 1:length(dims), 
    dimData{k} = [fieldnames(dims{k}) struct2cell(dims{k})];
  end
  
  % create cell array containing variable 
  % attribute data (one per variable)
  for k = 1:length(vars)
    
    varData{k} = [fieldnames(vars{k}) struct2cell(vars{k})];
  end
  
  %% create uitables
  
  % create a uitable for each data set
  tables(1) = createTable(globData, '', 'global', dateFmt);
  
  for k = 1:length(dims)
    tables(end+1) = createTable(...
      dimData{k}, ['dimensions{' num2str(k) '}'], lower(dims{k}.name), dateFmt);
  end
  
  for k = 1:length(vars)
    tables(end+1) = createTable(...
      varData{k}, ['variables{'  num2str(k) '}'], 'variable', dateFmt);
  end
  
  tableNames = {'Global'};
  for k = 1:length(dims), tableNames{end+1} = [dims{k}.name ' dimension']; end
  for k = 1:length(vars), tableNames{end+1} = [vars{k}.name ' variable'];  end
  
  % create a tabbedPane which displays each table in a separate tab
  panel = tabbedPane(parent, tables, tableNames, true);
  
  % matlab is a piece of shit; column widths must be specified 
  % in pixels, so we have to get the table position in pixels 
  % to calculate the desired column width
  for k = 1:length(tables)
    
    pos = get(tables(k), 'Position');
    colWidth    = zeros(1,2);
    colWidth(1) = (pos(3) / 3);
    
    % -30 in case a vertical scrollbar is added
    colWidth(2) = (2*pos(3) / 3)-30; 
    set(tables(k), 'ColumnWidth', num2cell(colWidth));
  end

  function table = createTable(data, prefix, tempType, dateFmt)
  % Creates a uitable which contains the given data. 
    
    % format data - they're all made into strings, and cast 
    % back when edited. also we want date fields to be 
    % displayed nicely, not to show up as a numeric value
    for k = 1:length(data)
      
      % get the type of the attribute
      t = templateType(data{k,1}, tempType);
      
      switch t
        
        % format dates
        case 'D',  
          data{k,2} = datestr(data{k,2}, dateFmt);
        
        % make everything else a string - i'm assuming that when 
        % num2str is passed a string, it will return that string 
        % unchanged; this assumption holds for at least r2008, r2009
        otherwise, data{k,2} = num2str(data{k,2});
      end
    end
    
    % create the table
    table = uitable(...
      'Visible',                'off',...
      'RowName',               [],...
      'RowStriping',           'on',...
      'ColumnName',            {'Name', 'Value'},...
      'ColumnEditable',        [false    true],...
      'ColumnFormat',          {'char', 'char'},...
      'CellEditCallback',      @cellEditCallback,...
      'CellSelectionCallback', @cellSelectCallback,...
      'Data',                  data);
    
    selectedCells = [];
    
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
      try applyUpdate(prefix, fieldName, newValue, tempType);
      
      catch e
        
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

  function applyUpdate(prefix, fieldName, fieldValue, tempType)
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
      t = templateType(fieldName, tempType);
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
          temp = str2num(fieldValue);

          % reject anything that is not a number
          if isempty(temp)
            error([fieldName ' must be a number']); 
          end

        % qc flag is different depending on qc set in use
        case 'Q'

          % i'm assuming that QC modifications will very rarely occur,
          % so the file lookups here shouldn't be too costly
          qcSet  = str2double(readToolboxProperty('toolbox.qc_set'));
          qcType = imosQCFlag('', qcSet, 'type');

          switch qcType

            case 'byte'
              temp = uint8(str2num(fieldValue));
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
