function template = parseNetCDFTemplate ( file, sample_data, k )
%PARSETEMPLATE Parses the given NetCDF attribute template file.
%
% Parses the given NetCDF attribute template file, inserting data into 
% the given sample_data struct where required. 
%
% A number of template files exist in the NetCDF/template subdirectory. These
% files list the NetCDF attribute names and provide default values to be
% exported in the output NetCDF files.
%
%   == Attribute definition ==
%
% The syntax of an attribute definition is of the form:
%
%   type, attribute_name = attribute_value
%
% where type is the type of the attribut, attribute_name is the IMOS 
% compliant NetCDF attribute name, and attribute_value is the value that the 
% attribute should be given. Attributes can be one of the following types:
%
%   S - String
%   N - Numeric
%   D - Date
%   Q - Quality control (either byte or char, depending on the QC set in use)
%
% When specifying a date value literally, you may either specify a matlab 
% serial date (i.e.a number), or use the format specified by the 
% toolbox.timeFormat property.
%
%   == Value definition ==
%
% The attribute_value field has a syntax of its own. It can be a plain string
% (without quotes), and can also contain 'tokens' which either point to a field 
% within the deployment database, or contain a one line matlab statement.
% Tokens are parts of the attribute value which are contained within square
% braces (i.e. '[]').
%
%   === DDB tokens ===
%
% The token syntax for setting an attribute value to be the value of a field 
% within the deployment database is (the inner square brackets 
% indicate optional sections):
%
%   attribute_value  = [ddb field [related_table [related_pkey] related_field]]
%
% where 
%
%   - field         is a field within the DeploymentData table, the value of
%                   which is to be used as the attribute value (unless 
%                   related_table and related_field are specified).
%
%   - related_table is the name of a table to which the field should be 
%                   considered a foreign key.
%
%   - related_pkey  is the name of the related_table primary key. If omitted, 
%                   it is assumed to be the same as field.
%
%   - related_field is the name of the field within the related_table, the
%                   value of which is to be used as the attribute value.
%
% A couple of examples:
%
%   1. For the attribute definition:
%
%        local_time_zone = [ddb TimeZone]
%
%      the value will be translated into a query to the deployment database of 
%      the form:
%
%        select TimeZone from DeploymentData 
%        where DeploymentID = dataset_deployment_id
%
%   2. For the attribute definition:
%
%        institution = [ddb PersonnelDownload Personnel StaffID Organisation]
%
%      the value will be translated into the following query:
%
%        select Organisation from Personnel where StaffID = 
%        (
%          select PersonnelDownload from DeploymentData
%          where DeploymentID = dataset_deployment_id
%        )
%
% === Matlab tokens ===
%
% You can set the attribute value to be the result of a matlab statement like
% so:
% 
%   attribute_name = [mat statement]
%
% The following 'workspace' is available to these embedded statements:
%
%   sample_data - the struct containing sample data, which is passed to this 
%                 function.
%
%   k           - (only if the template is a data attribute template) the
%                 variable index passed to this function.
%
% For example, for the attribute definition:
% 
%   quality_control_set = [mat readToolboxProperty('toolbox.qc_set')]
%
% the attribute value will be the value of the matlab statment:
%
%   readToolboxProperty('toolbox.qc_set')
%
% === Combinations ===
%
% An attribute value can contain combinations of plain strings and tokens, as 
% shown in the examples below. Tokens may contain other tokens.
%
% 1. qc_param_name = [mat sample_data.variables{k}.name]_QC
% 
% 2. author = [ddb PersonnelDownload Personnel StaffID FirstName] \
%             [ddb PersonnelDownload Personnel StaffID LastName]
%
% 3. title = [ddb Site]: [ddb Site Sites ResearchActivity]
%
% 4. platform = [mat ['Platform ' '[ddb Site]']]
%
% The use of square braces to enclose tokens imposes a minor limitation on the 
% use of square braces in attribute values: when the attribute value, tokens 
% and all, is taken as a literal string, the square braces must be balanced. 
% For example, the following is an example of a valid (not necessarily 
% realistic) attribute containing nested tokens and literal braces:
%
%   title = [[mat ['abc' '[ddb Site]' 'def']]]
%
% This will evaluate (assuming that the Site field in the deployment database 
% is 'MAI') to '[abcMAIdef]'. Using the same example, if the closing brace 
% at the end had been omitted, the parser would raise an error, as the braces 
% would not be balanced.
%
% Inputs:
%   file        - name of the template file to parse.
%
%   sample_data - A single struct containing sample data. 
%
%   k           - Optional. If the template is a data attribute template, 
%                 this value is an index into the variables vectors in the 
%                 sample_data struct to the corresponding variable struct.
%
% Outputs:
%   template    - Struct containing the attribute-value pairs that were 
%                 defined in the template file.
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
  error(nargchk(2, 3, nargin));

  if ~ischar(file),                error('file must be a string');        end
  if ~isstruct(sample_data),       error('sample_data must be a struct'); end
  if nargin == 3 && ~isnumeric(k), error('k must be numeric');            end

  dateFmt = readToolboxProperty('toolbox.timeFormat');
  qcSet   = str2double(readToolboxProperty('toolbox.qc_set'));
  qcType  = imosQCFlag('', qcSet, 'type');

  % if k isn't provided, provide a dummy value
  if nargin == 2, k = 1; end
  
  fid = -1;

  try 
    % open file for reading
    fid = fopen(file, 'rt');
    if fid == -1, error(['couldn''t open ' file ' for reading']); end

    template = struct;

    % read in and parse each line
    line = fgetl(fid);
    while ischar(line)

      % extract the attribute name and value
      tkns = regexp(line, ...
        '^\s*(.*\S)\s*,\s*(.*\S)\s*=\s*(.*\S)?\s*$', 'tokens');

      % ignore bad lines
      if isempty(tkns), 
        line = fgetl(fid);
        continue; 
      end

      type = tkns{1}{1};
      name = tkns{1}{2};
      val  = tkns{1}{3};

      % Parse the value, put it into the template struct. Matlab doesn't 
      % allow field names (or variable names) to start with an underscore. 
      % This is unfortunate, because some of the NetCDF attribute names do 
      % start with an underscore. I'm getting around this problem with a 
      % horrible hack: if the name starts with an underscore, remove the 
      % underscore from the name start, and put it at the name end. We can 
      %reverse this process when the NetCDF file is exported.
      if name(1) == '_', name = [name(2:end) '_']; end
      template.(name) = parseAttributeValue(val, sample_data, k);
      
      % cast to correct type
      template.(name) = castAtt(template.(name), type, qcType, dateFmt);

      % get the next line
      line = fgetl(fid);
    end

    fclose(fid);
  catch e
    if fid ~= -1, fclose(fid); end
    disp(line);
    rethrow(e);
  end
end

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
  sIdx = 1;
  
  value = line;
 
  if isempty(value), return; end

  while true
    
    % end of string reached
    if sIdx >= length(value), break; end
    
    % look at the next character
    c = value(sIdx);
    
    % if not the start of a token, move on to the next character
    if c ~= '[', sIdx = sIdx + 1;
      
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

  % get the relevant deployment
  deployment = sample_data.meta.DeploymentData;

  % no such deployment exists in the ddb, or multiple hits
  if length(deployment) ~= 1, return; end

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

  % simple query - just a field in the DeploymentData table
  if simple_query, value = deployment.(field); return; end

  % complex query - join with another table, get the field from that table
  field_value = deployment.(field);
  
  % if the field value is empty, we can't use it as 
  % a foreign key, so our only choice is to give up
  if isempty(field_value), return; end
  
  result = executeDDBQuery(related_table, related_pkey, deployment.(field));
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

function value = castAtt(value, t, qcType, dateFmt)
%CASTATT Given a string, translates it into the type specified by t, where
% t is one of the attribute types S, N, D, or Q.
%
% Inputs:
%   value   - A string.
%   t       - the attribute type to cast to.
%   qcType  - the netcdf type of the QC flags for the QC set in use.
%             Required to figure out what to do with values of type 'Q'.
%   dateFmt - Format in which to expect values of type 'D'. Matlab serial
%             dates are accepted in addition to this format.
%
% Outputs:
%
%   value - If the input was a string, and that string contained a scalar 
%           numeric, returns a scalar numeric. Otherwise returns the input 
%           unchanged.
%
  switch t
    case 'S', value = value;
    case 'N'
      value = str2double(value);
      if isnan(value), value = []; end
    case 'D'
      
      % for dates, try to use provided date format, 
      % otherwise assume it is matlab serial
      val = [];
      try      val = datenum(value, dateFmt);
      catch e, val = str2double(value);
      end
      value = val;
      
      if isnan(value), value = []; end
      
    case 'Q'
      
      switch (qcType)
        case 'byte', value = uint8(str2num(value));
        case 'char', value = value;
      end
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
  elseif isnumeric(value), value = num2str(value); 
  end

end
