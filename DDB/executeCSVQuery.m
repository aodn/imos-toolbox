function result = executeCSVQuery( file, field, value)
%EXECUTECSVQUERY Alternative to executeDDBQuery, uses CSV files.
%
% Uses multiple csv files to obtain information equivalent to
% executeDDBQuery. 
%
% Inputs:
%   file  - The csv file to query.
%
%   field  - Name of field to search for value. If passed in as an 
%            empty matrix, the entire table is returned. 
%
%   value  - Value of field on which to restrict query. 
%
% Outputs:
%   result - Vector of structs, each entry representing one tuple of the
%            query result. 
%
% Author:       Rebecca Cowley <rebecca.cowley@csiro.au>

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
  narginchk(3,3);

  if ~ischar(file), error('file must be a string'); end
  if ~isempty(field) ...
  && ~ischar(field), error('field must be a string'); end

  % in order to reduce the number of queries to the ddb (slow, we store 
  % each result in a global structure so that we don't perform twice the 
  % same query.
  persistent csvStruct;
  if isempty(csvStruct)
      csvStruct = struct;
      csvStruct.table = {};
      csvStruct.field = {};
      csvStruct.value = {};
      csvStruct.result = {};
  else
      iTable = strcmpi(file, csvStruct.table);
      if any(iTable)
          iField = strcmpi(field, csvStruct.field);
          iField = iField & iTable;
          if any(iField)
              iValue = strcmpi(csvStruct.value, num2str(value));
              iValue = iValue & iField;
              if any(iValue)
                  result = csvStruct.result{iValue};
                  return;
              end
          end
      end
  end
  
  %get location of csv files
  dirnm = readProperty('toolbox.ddb');
  
  % complete the file name:
  file = fullfile(dirnm, [file '.csv']);
  
  %check the file exists, if not, prompt user to select file
  if exist(file,'file') == 0
      %open dialog to select a file
      disp(['Deployment CSV file ' file ' not found'])
      return
      % Code it in....
  end
  
  % open the file
  fid = fopen(file);
  
  %figure out how many columns we have:
  header1 = fgetl(fid);
  ncols = length(strfind(header1,',')) + 1;
  fmtHeader = repmat('%q', 1, ncols);
  header1 = textscan(header1, fmtHeader, 'Delimiter', ',', 'CollectOutput',  1);
  header1 = header1{1};
  
  %build the format string
  header2 = fgetl(fid);
  header2 = textscan(header2, fmtHeader, 'Delimiter', ',', 'CollectOutput',  1);
  header2 = header2{1};
  
  iDate = cellfun(@(x) ~strncmpi(x, '%', 1), header2);
  iDateFmt = header2;
  iDateFmt(iDate) = header2(iDate);
  
  [header2{iDate}] = deal('%q');
  
  fmt = cell2mat(header2);
  
  %close and re-open the file
  fclose(fid);
  fid = fopen(file);
  
  %extract all the data
  data = textscan(fid, fmt, ...
      'Delimiter',      ',' , ...
      'HeaderLines',    2);

  nCols = length(data);
  nRows = length(data{1});
  myData = cell(nRows, nCols);
  for i=1:nCols
      if isfloat(data{i})
          myData(:, i) = num2cell(data{i});
      else
%           if iDate(i)
%               iEmpty = cellfun(@isempty, data{i});
%               if any(~iEmpty)
%                   myData(~iEmpty, i) = cellfun(@(x) datenum(x, iDateFmt{i}), data{i}(~iEmpty), 'Uniform', false);
%               end
%           else
              myData(:, i) = data{i};
%           end
      end
  end
  fclose(fid);
    
  result = extractdata(header1, myData, iDate, iDateFmt, field, value);
  
  % save result in structure
  csvStruct.table{end+1} = file;
  csvStruct.field{end+1} = field;
  csvStruct.value{end+1} = num2str(value);
  csvStruct.result{end+1} = result;
end

function result = extractdata(header, data, iDate, iDateFmt, field, value)
% Extract the required values from the data
%headers become field names

if ~isempty(field)
    ifield = strcmp(field,header);
    if ~any(ifield)
        disp(['Field ' field ' not found in the csv file'])
        result = [];
        return
    end
    
    % extract the values in field:
    ivalue =  strcmp(value,data(:,ifield));
    data = data(ivalue,:);
end

% look for dates and convert them
for i = find(iDate)
    iEmpty = cellfun(@isempty, data(:,i));
    if any(~iEmpty)
        data(~iEmpty, i) = cellfun(@(x) datenum(x, iDateFmt{i}), data(~iEmpty,i), 'Uniform', false);
    end
end

%make the structure:
result = cell2struct(data,header,2);

end
