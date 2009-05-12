function template = parseNetCDFTemplate ( file, sample_data, k )
%PARSETEMPLATE Parses the given NetCDF attribute template file.
%
% Parses the given NetCDF attribute template file, inserting data where
% required. 
%
% A number of template files exist in the NetCDF/template subdirectory. These
% files list the NetCDF attribute names and provide default values to be
% exported in the output NetCDF files.
%
%   == Attribute definition ==
%
% The syntax of an attribute definition is of the form:
%
%   attribute_name = attribute_value
%
% where attribute_name is the IMOS compliant NetCDF attribute name, and
% attribute_value is the value that the attribute should be given.
%
%   == Value definition ==
%
% The attribute_value field has a syntax of its own. It can be a plain string
% (without quotes), and can also contain 'tokens' which either point to a field 
% within the deployment database, or contain a one line matlab statement.
% Tokens are parts of the attribute value which are contained within curly
% braces (i.e. '{}').
%
%   === DDB tokens ===
%
% The token syntax for setting an attribute value to be the value of a field 
% within the deployment database is (the square brackets indicate optional 
% sections):
%
%   attribute_value  = {ddb field [related_table [related_pkey] related_field]}
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
%        local_time_zone = {ddb TimeZone}
%
%      the value will be translated into a query to the deployment database of 
%      the form:
%
%        select TimeZone from DeploymentData 
%        where DeploymentID = cal_data.deployment_id
%
%   2. For the attribute definition:
%
%        institution = {ddb PersonnelDownload Personnel StaffID Organisation}
%
%      the value will be translated into the following query:
%
%        select Organisation from Personnel where StaffID = 
%        (
%          select PersonnelDownload from DeploymentData
%          where DeploymentID = cal_data.deployment_id
%        )
%
% === Matlab tokens ===
%
% You can set the attribute value to be the result of a matlab statement like
% so:
% 
%   attribute_name = {mat statement}
%
% The result of the statement must be a matlab string.
%
% The following 'workspace' is available to these embedded statements:
%
%   sample_data - the struct containing sample data, which is passed to this 
%                 function.
%
%   cal_data    - the struct containing calibration/metadata, which is passed
%                 to this function.
%
%   k           - (only if the template is a data attribute template) the
%                 parameter index passed to this function.
%
% For example, for the attribute definition:
% 
%   quality_control_set = {mat num2str(cal_data.qc_set)}
%
% the attribute value will be the value of the matlab statment:
%
%   num2str(cal_data.qc_set)
%
% === Combinations ===
%
% An attribute value can contain combinations of plain strings and tokens, as 
% shown in the following examples. The following constraints exist:
%   - Tokens cannot be repeated in a single attribute definition
%   - Tokens cannot be nested within other tokens.
%
% 1. qc_param_name = {mat sample_data.parameters(k).name}_QC
% 
% 2. author = {ddb PersonnelDownload Personnel StaffID FirstName} \
%             {ddb PersonnelDownload Personnel StaffID LastName}
%
% 3. title = {ddb Site}: {ddb Site Sites ResearchActivity}
%
% Inputs:
%   file        - name of the template file to parse.
%
%   sample_data - A single struct containing sample data. 
%
%   cal_data    - A struct containing the calibration/metadata that corresponds
%                 to the given sample data.
%
%   k           - Optional. If the template is a data attribute template, this 
%                 value is an index into the parameters vectors in both the 
%                 sample_data and cal_data structs to the corresponding 
%                 parameter data.
%
% Outputs:
%   template    - a struct containing all of the fields and values specified 
%                 in the template file.
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
  error(nargchk(3, 4, nargin));

  if ~ischar(file),                error('file must be a string');        end
  if ~isstruct(sample_data),       error('sample_data must be a struct'); end
  if ~isstruct(cal_data),          error('cal_data must be a struct');    end
  if nargin == 4 && ~isnumeric(k), error('k must be numeric');            end

  % if k isn't provided, provide a dummy value
  if nargin == 3, k = -1; end
  
  fid = -1;

  try 
    % open file for reading
    fid = fopen(file, 'r');
    if fid == -1, error(['couldn''t open ' file ' for reading']); end

    template = struct;

    % read in and parse each line
    line = readline(fid);
    while ischar(line)

      % extract the attribute name and value
      tkns = regexp(line, '^\s*(.*\S)\s*=\s*(.*\S)?\s*$', 'tokens');

      % ignore bad lines
      if isempty(tkns), 
        line = readline(fid);
        continue; 
      end

      name = tkns{1}{1};
      val  = tkns{1}{2};

      % Parse the value, put it into the template struct. Matlab doesn't allow 
      % field names (or variable names) to start with an underscore. This is 
      % unfortunate, because some of the NetCDF attribute names do start with an 
      % underscore. I'm getting around this problem with a horrible hack: if the 
      % name starts with an underscore, remove the underscore from the name 
      % start, and put it at the name end. We can reverse this process when the 
      % NetCDF file is exported.
      if name(1) == '_', name = [name(2:end) '_']; end
      template.(name) = parseAttributeValue(val, sample_data, cal_data, k);

      % get the next line
      line = readline(fid);
    end

    fclose(fid);
  catch e
    if fid ~= -1, fclose(fid); end
    rethrow(e);
  end
end

function value = parseAttributeValue(line, sample_data, cal_data, k)
%PARSEATTRIBUTEVALUE Parse an attribute value.
%
% Parses an attribute value as read from a template file. Searches for and 
% interprets 'tokens' which point to the deployment database or which contain 
% a matlab expression.
%
% Inputs:
%
%   sample_data - A single struct containing sample data. 
%   cal_data    - A struct containing the calibration/metadata that corresponds
%                 to the given sample data.
%   k           - Index into parameters vectors.
%
% Outputs:
%
%   value       - the attribute value.
%

  value = line;

  % get all tokens in the value (substrings that are contained within { })
  tkns = regexp(line, '{([^{}]*)}', 'tokens');

  for k = 1:length(tkns)

    tkn = tkns{k}{1};

    % translate the token into an actual value
    val = '';

    switch tkn(1:3)
      case 'ddb', val = parseDDBToken(tkn(5:end), sample_data, cal_data, k);
      case 'mat', val = parseMatToken(tkn(5:end), sample_data, cal_data, k);
      otherwise,  val = '';
    end
    
    % replace the token from the original line with its value
    value = strrep(value, ['{' tkn '}'], stringify(val));

  end
  
  value = numify(value);
end

function value = parseDDBToken(token, sample_data, cal_data, k)
%PARSEDDBTOKEN Parse a token pointing to the DDB.
%
% Interprets a token which contains a pointer to an entry in the deployment
% database. The token is translated into a DDB query. The result of that query
% is returned.
%
% Inputs:
%
%   sample_data - A single struct containing sample data. 
%   cal_data    - A struct containing the calibration/metadata that corresponds
%                 to the given sample data.
%   k           - Index into parameters vectors.
%
% Outputs:
%
%   value       - the value of the token as contained in the DDB.
%

  value = '';

  % get the relevant deployment
  deployment = executeDDBQuery('DeploymentData', ...
                               'DeploymentId', ...
                               cal_data.parameters(k).deployment_id);

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

function value = parseMatToken(token, sample_data, cal_data, k)
%PARSEMATTOKEN Parse a token containing a matlab expression.
%
% Parses a token, which has been extracted from an attribute value, and which 
% contains a matlab expression. Returns the value of that matlab expression.
%
% Inputs:
%
%   sample_data - A single struct containing sample data. 
%   cal_data    - A struct containing the calibration/metadata that corresponds
%                 to the given sample data.
%   k           - Index into parameters vectors.
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

function value = numify(value)
%NUMIFY Given a string, translates it into a scalar numeric if possible. 
% Otherwise leaves the input value unchanged.
%
% Inputs:
%
%   value - Anything.
%
% Outputs:
%
%   value - If the input was a string, and that string contained a scalar 
%           numeric, returns a scalar numeric. Otherwise returns the input 
%           unchanged.
%
  if ischar(value)
    
    dub = str2double(value);
    if ~isnan(dub), value = dub; end
    
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

function line = readline(fid)
%READLINE Reads a line from the given file, interpreting lines which are split
% over multiple lines with line break escapes ('\').
%
% Matlab does not provide any functionality to interpret line break escapes, so
% I wrote my own.
%
% Inputs:
%
%   fid  - fid of the file to read from
%
% Outputs:
%
%   line - the next line, or -1 if the end of the file has been reached.
%
  line = '\';

  while ~isempty(line) && line(end) == '\';

    line = line(1:end-1);
    next = fgetl(fid);

    if ~ischar(next), 
      if isempty(line), line = -1; end
      return; 
    end

    next = strtrim(next);
    line = [line next];

  end
end
