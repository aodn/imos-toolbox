function result = executeQuery( table, field, value)
%EXECUTEQUERY Summary of this function goes here
%   Detailed explanation goes here

% this needs cleaning up

isCSV = false;
  ddb = readProperty('toolbox.ddb');
  if isdir(ddb)
      isCSV = true;
  end
if isCSV
    executeQueryFunc = @executeCSVQuery;
else
    executeQueryFunc = @executeDDBQuery;
end

result = executeQueryFunc(table, field,   value);
  
end

