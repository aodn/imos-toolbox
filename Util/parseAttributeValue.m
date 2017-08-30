function value = parseAttributeValue(line, sample_data, k)
%PARSEATTRIBUTEVALUE Parse an attribute value.
%
% Parses an attribute value as read from a template file. Searches for and 
% interprets 'tokens' which point to the deployment database or which contain 
% a matlab expression.
%
% Inputs:
%
%   line        - the line to parse.
%   sample_data - A single struct containing sample data. 
%   k           - Index into sample_data.variable vector.
%
% Outputs:
%
%   value       - String containing the attribute value.
%
% Author: Paul McCarthy <paul.mccarthy@csiro.au>
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
  sIdx = 1;
  
  value = line;
 
  if isempty(value), return; end

  while true
    
    % end of string reached
    if sIdx >= length(value), break; end
    
    % look at the next character
    c = value(sIdx);
    
    % if not the start of a token, move on to the next character
    if c ~= '['
        sIdx = sIdx + 1;
    % otherwise parse the token
    else
      
      % find the end of the token by searching 
      % for the matching end bracket
      depth = 1;
      for eIdx = sIdx+1:length(value)
        
        if     value(eIdx) == '[', depth = depth + 1;
        elseif value(eIdx) == ']', depth = depth - 1;
        end
        
        if depth == 0, break; end
      end
      
      % parentheses must be balanced
      if depth ~= 0, error('parentheses imbalance'); end
      
      % valid token found, so parse it
      tknResult = parseToken(value(sIdx:eIdx), sample_data, k);
      
      % need to deal with error mesage from non existent fields in struct
      if any(strfind(tknResult, 'Reference to non-existent field'))
          tknResult = [];
      end
      
      % replace the token with the interpreted value
      value = [value(1:sIdx-1) tknResult value(eIdx+1:end)];
      
      % continue steppping through the string, 
      % after the token that was just parsed
      sIdx = sIdx + length(tknResult);
    end
  end
end

function result = parseToken(tkn, sample_data, k)
%PARSETOKEN Evaluates a single token from an attribute value.
%
% This function makes a recursive call to parseAttributeValue, to account for 
% any nested tokens.
%
% Inputs:
%
%   line        - the token to parse.
%   sample_data - A single struct containing sample data. 
%   k           - Index into sample_data.variable vector.
%
% Outputs:
%
%   value       - String containing the evaluated token value.
%

  result = tkn;
  
  % minimum length for a valid token 
  % is 6 characters (e.g. '[ddb ]')
  if length(tkn) < 6, return; end

  % get the token type, and its contents
  type = tkn(2:4);
  tkn  = tkn(6:end-1);
  
  % run through token contents recursively 
  % to replace any nested tokens
  switch type
    case 'ddb', tkn = parseAttributeValue(tkn,             sample_data, k);
    case 'mat', tkn = parseAttributeValue(tkn,             sample_data, k);
    otherwise,  tkn = parseAttributeValue(result(2:end-1), sample_data, k);
  end
  
  switch type
    case 'ddb', result = stringify(parseDDBToken(tkn, sample_data, k));
    case 'mat', result = stringify(parseMatToken(tkn, sample_data, k));
    otherwise,  result = [result(1) tkn result(end)];
  end
end

function value = parseDDBToken(token, sample_data, k)
%PARSEDDBTOKEN Parse a token pointing to the DDB.
%
% Interprets a token which contains a pointer to an entry in the deployment
% database. The token is translated into a DDB query. The result of that query
% is returned.
%
% Inputs:
%
%   sample_data - A single struct containing sample data. 
%   k           - Index into sample_data.variables vector.
%
% Outputs:
%
%   value       - the value of the token as contained in the DDB.
%

  value = '';
  
  % if there is no deployment database, set the value to an empty matrix
  ddb = readProperty('toolbox.ddb');
  driver = readProperty('toolbox.ddb.driver');
  connection = readProperty('toolbox.ddb.connection');
  if isempty(ddb) && (isempty(driver) || isempty(connection)), return; end

  % get the relevant deployment/CTD cast
  if isfield(sample_data.meta, 'profile')    
      deployment = sample_data.meta.profile;
  else
      deployment = sample_data.meta.deployment;
  end

  % split the token up into its individual elements
  tkns = regexp(token, '\s+', 'split');

  switch length(tkns)

    case 1
      simple_query = 1;
      field = tkns{1};
    case 3
      simple_query = 0;
      field         = tkns{1};
      related_table = tkns{2};
      related_pkey  = field;
      related_field = tkns{3};
    case 4
      simple_query = 0;
      field         = tkns{1};
      related_table = tkns{2};
      related_pkey  = tkns{3};
      related_field = tkns{4};
    otherwise
      return;
  end

  % simple query - just a field in the DeploymentData/CTDData table
  if simple_query, value = deployment.(field); return; end

  % complex query - join with another table, get the field from that table
  field_value = deployment.(field);
  
  % if the field value is empty, we can't use it as 
  % a foreign key, so our only choice is to give up
  if isempty(field_value), return; end
  
  result = executeQuery(related_table, related_pkey, field_value);
  
  if length(result) ~= 1, return; end

  value = result.(related_field);

end

function value = parseMatToken(token, sample_data, k)
%PARSEMATTOKEN Parse a token containing a matlab expression.
%
% Parses a token, which has been extracted from an attribute value, and which 
% contains a matlab expression. Returns the value of that matlab expression.
%
% Inputs:
%
%   sample_data - A single struct containing sample data. 
%   k           - Index into sample_data.variables vector.
%
% Outputs:
%
%   value       - the result of the matlab statement.
%

  % if the expression is erroneous, ignore it
  try      value = eval(token);
  catch e, value = e.message;
  end
end

function value = stringify(value)
%STRINGIFY Given a numeric, turns it into a string. If an empty matrix, turns
% it into an empty string. Otherwise leaves it unchanged.
%
% Intputs:
%
%   value - Anything.
%
% Outputs:
%
%   value - If the input was a numeric or emptry matrix, returns a string 
%           representation the input. Otherwise returns the input unchanged.
%
  if     isempty(value), value = '';
  elseif isnumeric(value), value = sprintf('%.10f', value); 
  end

end
