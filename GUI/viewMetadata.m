function sample_data = viewMetadata( parent, fieldTrip, sample_data )
%VIEWMETADATA Displays metadata for the given data set in the given parent
% figure/uipanel.
%
% This function displays metadata contained in the given sample_data struct 
% in the given parent figure/uipanel.
%
% Inputs:
%   parent      - handle to the figure/uipanel in which the metadata should
%                 be displayed.
%   fieldTrip   - struct containing field trip information.
%   sample_data - struct containing sample data.
%
% Outputs:
%   sample_data -
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

  if ~ishandle(parent),      error('parent must be a handle');      end
  if ~isstruct(fieldTrip),   error('fieldTrip must be a struct');   end
  if ~isstruct(sample_data), error('sample_data must be a struct'); end

  % 2*N cell array - the data which will be put into the table
  data = {};

  % get everything from the sample_data struct
  fields = fieldnames(sample_data);
  for k = 1:length(fields)

    field = fields{k};
    if strcmpi(field, 'variables') || strcmpi(field, 'dimensions')
      continue; 
    end

    data{end+1,1} = field;
    data{end  ,2} = sample_data.(field);
  end

  % create the table
  table = uitable(...
    'Parent',           parent,...
    'RowName',          [],...
    'RowStriping',      'on',...
    'ColumnName',       {'Name', 'Value'},...
    'ColumnEditable',   [false   true],...
    'CellEditCallback', @editCallback,...
    'Data',             data,...
    'Units',            'normalized',...
    'Position',         [0.0, 0.0, 1.0, 1.0]);

  % matlab is a piece of shit; column widths must be specified 
  % in pixels, so we have to get the table position in pixels 
  % to calculate the desired column width
  set(table, 'Units', 'pixels');
  pos = get(table, 'Position');
  set(table, 'Units', 'normalized');
  colWidth    = zeros(1,2);
  colWidth(1) = (pos(3) / 3);
  colWidth(2) = (2*pos(3) / 3)-30; % -30 in case a vertical scrollbar is added
  set(table, 'ColumnWidth', num2cell(colWidth));
  
  function keyPressCallback(source,ev)
    
  end
  
  function editCallback(source,ev)
    
    row = ev.Indices(1);
    field = data(row, 1);
    
  end
end
