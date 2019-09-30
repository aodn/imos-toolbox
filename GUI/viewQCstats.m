function viewQCstats(parent, sample_data, mode)
%VIEWQCSTATS Displays QC statistics for the given data set in the given parent
% figure/uipanel.
%
% This function displays QC statistics contained in the given sample_data.meta.QCres 
% struct in the given parent figure/uipanel.
%
% Inputs:
%   parent         - handle to the figure/uipanel in which the metadata should
%                    be displayed.
%   sample_data    - struct containing sample data.
%   mode           - Toolbox data type mode.
%
% Author:       Guillaume Galibert <guillaume.galibert@utas.edu.au>
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
  
  if isempty(sample_data.meta.QCres), return; end
  
  %% arrange QC stats
  % get all the dimensions and variables names from the current sample_data
  lenDims = length(sample_data.dimensions);
  lenVars = length(sample_data.variables);
  QCparamNames = {};
  QCparamTypes = {};
  for k = 1:lenDims
      if isfield(sample_data.dimensions{k}, 'flags')
          QCparamNames{end+1} = sample_data.dimensions{k}.name;
          QCparamTypes{end+1} = 'dimensions';
      end
  end
  
  for k = 1:lenVars
      if isfield(sample_data.variables{k}, 'flags')
          QCparamNames{end+1} = sample_data.variables{k}.name;
          QCparamTypes{end+1} = 'variables';
      end
  end
  
  % get all the QC procedures names from the current sample_data
  procName = fieldnames(sample_data.meta.QCres);
  
  lenProc       = length(procName);
  lenParam      = length(QCparamNames);
  data          = cell(lenProc, lenParam);
  info          = cell(lenProc, lenParam);
  for k=1:lenProc
      for m=1:lenParam
          if isfield(sample_data.meta.QCres.(procName{k}), QCparamNames{m})
              iParam  = getVar(sample_data.(QCparamTypes{m}), QCparamNames{m});
              nData   = numel(sample_data.(QCparamTypes{m}){iParam}.data);
              
              procDetails = sample_data.meta.QCres.(procName{k}).(QCparamNames{m}).procDetails;
              nFlag       = [num2str(sample_data.meta.QCres.(procName{k}).(QCparamNames{m}).nFlag/nData*100, '%3.0f') '% (' ...
                  num2str(sample_data.meta.QCres.(procName{k}).(QCparamNames{m}).nFlag) ')'];
              codeFlag    = sample_data.meta.QCres.(procName{k}).(QCparamNames{m}).codeFlag;
              stringFlag  = sample_data.meta.QCres.(procName{k}).(QCparamNames{m}).stringFlag;
              color       = sample_data.meta.QCres.(procName{k}).(QCparamNames{m}).HEXcolor;
          else
              procDetails = [];
              nFlag       = 'X';
              codeFlag    = NaN;
              stringFlag  = [];
              color       = '808080'; % reshape(dec2hex(round(255*[0.5 0.5 0.5]))', 1, 6)  (~grey)
          end
          data{k, m} = ['<html><table border=0 width=400 bgcolor=#', color, ...
              '><TR><TD>', nFlag, '</TD></TR> </table></html>'];
          if isnan(codeFlag)
              info{k, m} = 'No QC performed.';
          else
              if isempty(procDetails) && isempty(codeFlag)
                  info{k, m} = sprintf('Data points failing test:     %s.\nProcedure''s parameters:   n/a.', nFlag);
              elseif ~isempty(procDetails) && isempty(codeFlag)
                  info{k, m} = sprintf('Data points failing test:     %s.\nProcedure''s parameters:   %s.', nFlag, procDetails);
              elseif isempty(procDetails) && ~isempty(codeFlag)
                  info{k, m} = sprintf('Data points failing test:     %s.\nProcedure''s parameters:   n/a.\nProvided failing flag:         %s (%s).', nFlag, num2str(codeFlag), stringFlag);
              else
                  info{k, m} = sprintf('Data points failing test:     %s.\nProcedure''s parameters:   %s.\nProvided failing flag:         %s (%s).', nFlag, procDetails, num2str(codeFlag), stringFlag);
              end
          end
      end
  end
  
  %% create uitable
  tables = nan(1, 1);
  panels = nan(1, 1);
  [tables(1) panels(1)] = createTable(procName, QCparamNames, data, info, mode);
  
  tableNames =  cell(1, 1);
  tableNames{1} = 'QC statistical results';
  
  % create a tabbedPane which displays each table in a separate tab.
  % for low table numbers use buttons, otherwise use a drop down list
  lenTables = length(tables);
  tabPanel = tabbedPane(parent, panels, tableNames, true);
  

  function [table panel] = createTable(procedure, param, data, info, mode)
  % Creates a uitable which contains the given data. 
    
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
      'RowName',               procedure,...
      'RowStriping',           'on',...
      'ColumnName',            param,...
      'ColumnEditable',        [],...
      'ColumnFormat',          {},...
      'CellSelectionCallback', {@cellSelectCallback, info, procedure, param},...
      'SelectionHighlight',    'off',...
      'TooltipString',         '',...
      'Data',                  data,...
      'Tag',                   'qcTable');
    
    % position table and button
    set(panel,     'Units', 'normalized');
    set(table,     'Units', 'normalized');
    
    set(table,     'Position', posUi2(panel, 1, 10, 1, 1:9, 0));
    
    selectedCells = [];
    
    function cellSelectCallback(source, ev, info, procedure, param)
    %CELLSELECTCALLBACK Updates the selectedCells variable whenever the
    % cell selection changes. The uitable provides no ability to query the
    % currently selected cells, so we have to use this callback.
      selectedCells = ev.Indices;
      hBox = helpdlg(info{selectedCells(1), selectedCells(2)}, ['Info for ' procedure{selectedCells(1)} ' on ' param{selectedCells(2)}]);
      set(hBox, 'Resize', 'on');
      selectedCells = [];
    end
  end
end