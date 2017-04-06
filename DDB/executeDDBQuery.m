function result = executeDDBQuery( table, field, value)
%EXECUTEDDBQUERY Wrapper around Java DDB interface, allowing queries to the
%DDB.
%
% Executes a query against the DDB, of the form:
%
%   select * from table where field = value
%
% See Java/org/imos/ddb/DDB.java for more information.
%
% Inputs:
%   table  - The DDB table to query.
%
%   field  - Name of field on which to restrict query. If passed in as an 
%            empty matrix, the entire table is returned. 
%
%   value  - Value of field on which to restrict query. 
%
% Outputs:
%   result - Vector of structs, each entry representing one tuple of the
%            query result. The struct field names nd values are Matlab 
%            equivalents of the class definitions in 
%            Java/src/org/imos/ddb/schema/.
%
% Author:       Paul McCarthy <paul.mccarthy@csiro.au>
% Contributor:  Gordon Keith <gordon.keith@csiro.au>
%    -now can use the toolbox.ddb.* optional properties if exist
%               Guillaume Galibert <guillaume.galibert@utas.edu.au>
%               Peter Jansen <peter.jansen@csiro.au>
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
  narginchk(3,3);

  if ~ischar(table), error('table must be a string'); end
  if ~isempty(field) ...
  && ~ischar(field), error('field must be a string'); end

  % in order to reduce the number of queries to the ddb (slow, we store 
  % each result in a global structure so that we don't perform twice the 
  % same query.
  persistent ddbStruct;
  if isempty(ddbStruct)
      ddbStruct = struct;
      ddbStruct.table = {};
      ddbStruct.field = {};
      ddbStruct.value = {};
      ddbStruct.result = {};
  else
      iTable = strcmpi(table, ddbStruct.table);
      if any(iTable)
          iField = strcmpi(field, ddbStruct.field);
          iField = iField & iTable;
          if any(iField)
              iValue = strcmpi(ddbStruct.value, num2str(value));
              iValue = iValue & iField;
              if any(iValue)
                  result = ddbStruct.result{iValue};
                  return;
              end
          end
      end
  end
  
  % execute the query - the java method returns 
  % an ArrayList of org.imos.ddb.schema.* objects.
  source     = '';
  driver     = '';
  connection = '';
  dbuser     = '';
  dbpassword = '';
  try 
      source     = readProperty('toolbox.ddb');
      driver     = readProperty('toolbox.ddb.driver');
      connection = readProperty('toolbox.ddb.connection');
      dbuser     = readProperty('toolbox.ddb.user');
      dbpassword = readProperty('toolbox.ddb.password');
  catch e
  end
  
  if isempty(connection)
      ddb = org.imos.ddb.DDB.getDDB(source);
  else
      ddb = org.imos.ddb.DDB.getDDB(driver, connection, dbuser, dbpassword);
  end
  
  result = ddb.executeQuery(table, field, value);
  clear ddb;

  % convert java objects to a vector of matlab structs
  result = java2struct(result);
  
  % save result in structure
  ddbStruct.table{end+1} = table;
  ddbStruct.field{end+1} = field;
  ddbStruct.value{end+1} = num2str(value);
  ddbStruct.result{end+1} = result;
end

function strs = java2struct(list)
%JAVA2STRUCT Converts a Java ArrayList which contains org.imos.ddb.DBObject
% objects into equivalent Matlab structs. java.util.Date objects are
% returned as matlab serial date values.
%
% Inputs:
%   list - a Java ArrayList containing org.imos.ddb.DBObject objects
%
% Outputs:
%   strs - A vector of matlab structs which are equivalent to the java
%          objects.
%
  strs = struct([]);
  
  if list.size() == 0, return; end;
  
  % We turn Java fields of arbitrary types into matlab fields
  for k = 0:list.size()-1
    
    obj = list.get(k);
    
    for m = 0:obj.size()-1
      
      fields = obj.get(m);
      field = char(fields.name);
      val   = fields.o;
      
      % if java field is null
      if isempty(val), strs(k+1).(field) = []; continue; end
      
      % get class type of field
      oClass = class(val);
      
      % turn java field value into matlab field 
      % value, ignoring unsupported types
      switch(oClass)
        
        case 'java.lang.String',
          strs(k+1).(field) = char(val);
        case 'java.lang.Double',
          strs(k+1).(field) = double(val);
        case 'java.lang.Integer',
          strs(k+1).(field) = int32(val.intValue());
        case 'java.lang.Boolean',
          strs(k+1).(field) = double(val.booleanValue());
        case {'java.util.Date','java.sql.Date','java.sql.Timestamp'}
          cal = java.util.Calendar.getInstance();
          cal.setTime(val);
          strs(k+1).(field) = datenum(...
            cal.get(java.util.Calendar.YEAR),...
            cal.get(java.util.Calendar.MONTH)+1,...
            cal.get(java.util.Calendar.DAY_OF_MONTH),...
            cal.get(java.util.Calendar.HOUR_OF_DAY),...
            cal.get(java.util.Calendar.MINUTE),...
            cal.get(java.util.Calendar.SECOND));
        otherwise
          strs(k+1).(field) = val;
      end
    end
  end
end
