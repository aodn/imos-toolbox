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
% Author: Paul McCarthy <paul.mccarthy@csiro.au>
% Contributor: Gordon Keith <gordon.keith@csiro.au>
%    -now can use the toolbox.ddb.* optional properties if exist
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
  error(nargchk(3,3,nargin));

  if ~ischar(table), error('table must be a string'); end
  if ~isempty(field) ...
  && ~ischar(field), error('field must be a string'); end

  % execute the query - the java method returns 
  % an ArrayList of org.imos.ddb.schema.* objects.
  connection = '';
  dbuser     = '';
  dbpassword = '';
  try 
      driver     = readProperty('toolbox.ddb.driver');
      connection = readProperty('toolbox.ddb.connection');
      dbuser     = readProperty('toolbox.ddb.user');
      dbpassword = readProperty('toolbox.ddb.password');
  catch e
  end
  
  if isempty(connection)
      ddb = org.imos.ddb.DDB.getDDB(readProperty('toolbox.ddb'));
  else
      ddb = org.imos.ddb.DDB.getDDB(driver, connection, dbuser, dbpassword);
  end
  
  result = ddb.executeQuery(table, field, value);
  clear ddb;

  % convert java objects to a vector of matlab structs
  result = java2struct(result);

end

function strs = java2struct(list)
%JAVA2STRUCT Converts a Java ArrayList which contains org.imos.ddb.schema.*
% objects into equivalent Matlab structs. java.util.Date objects are
% returned as matlab serial date values.
%
% Inputs:
%   list - a Java ArrayList containing org.imos.ddb.schema.* objects
%
% Outputs:
%   strs - A vector of matlab structs which are equivalent to the java
%          objects.
%
  strs = [];
  
  if list.size() == 0, return; end;
  
  dateFmt = readProperty('exportNetCDF.dateFormat');

  % it's horribly ugly, but this is the only way that I know of to turn
  % Java fields of arbitrary types into matlab fields: a big, ugly switch
  % statement :( at least the fieldnames function works on java objects.
  for k = 0:list.size()-1
    
    obj = list.get(k);
    
    % for each field in the java object
    fields = fieldnames(obj);
    for m = 1:length(fields)
      
      field = fields{m};
      val   = obj.(field);
      
      % if java field is null
      if isempty(val), strs(k+1).(field) = []; continue; end
      
      % get class type of field
      class = char(val.getClass().getName());
      
      % turn java field value into matlab field 
      % value, ignoring unsupported types
      switch(class)
        
        case 'java.lang.String',
          strs(k+1).(field) = char(val);
        case 'java.lang.Double',
          strs(k+1).(field) = double(val);
        case 'java.lang.Integer',
          strs(k+1).(field) = int32(val.intValue());
        case 'java.lang.Boolean',
          strs(k+1).(field) = double(val.booleanValue());
        case 'java.util.Date',
          cal = java.util.Calendar.getInstance();
          cal.setTime(val);
          strs(k+1).(field) = datenum(...
            cal.get(java.util.Calendar.YEAR),...
            cal.get(java.util.Calendar.MONTH)+1,...
            cal.get(java.util.Calendar.DAY_OF_MONTH),...
            cal.get(java.util.Calendar.HOUR_OF_DAY),...
            cal.get(java.util.Calendar.MINUTE),...
            cal.get(java.util.Calendar.SECOND));
        case 'java.sql.Timestamp',
          cal = java.util.Calendar.getInstance();
          cal.setTime(val);
          strs(k+1).(field) = datenum(...
            cal.get(java.util.Calendar.YEAR),...
            cal.get(java.util.Calendar.MONTH)+1,...
            cal.get(java.util.Calendar.DAY_OF_MONTH),...
            cal.get(java.util.Calendar.HOUR_OF_DAY),...
            cal.get(java.util.Calendar.MINUTE),...
            cal.get(java.util.Calendar.SECOND));
      end
    end
  end
end
