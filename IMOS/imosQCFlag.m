function value = imosQCFlag( qcClass, qcSet, field )
%IMOSQCFLAG Returns an appropriate QC flag value (String), description, color 
% spec, output type, minimum/maximum value, fill value, or set description for 
% the given qcClass (String), using the given qcSet (integer).
%
% The QC sets definitions, descriptions, output types, and valid flag values 
% for each, are maintained in the files 'imosQCSet.txt' and 'imosQCFlag.txt'
% which are stored  in the same directory as this m-file.
%
% The value returned by this function is one of:
%   - the appropriate QC flag value to use for flagging data when using the 
%     given QC set. 
%   - a human readable description of the flag meaning.
%   - a ColorSpec which should be used when displaying the flag
%   - a human readable description of the qc set.
%   - the NetCDF type in which the flag values should be output.
%   - The minimum or maximum flag value.
%   - The fill value.
%   - a vector of characters, defining the different flag values that are
%     possible in the qc set.
%
% Inputs:
%
%   qcClass  - If field is one of 'flag', 'desc' or 'color', must be one 
%              of the (case insensitive) strings listed in the imosQCFlag.txt 
%              file. If it is not equal to one of these strings, the return 
%              value will be empty.
%
%   qcSet    - must be an integer identifier to one of the supported QC sets. 
%              If it does not map to a supported QC set, it is assumed to be 
%              the first qc set defined in the imosQCSet.txt file.
%
%   field    - String which defines what the return value is. Must be one
%              of 'flag', 'desc', 'set_desc', 'type', 'values' 'min', 'max',
%              'fill_value', or 'color'.
%
% Outputs:
%   value    - One of the flag value, flag description, output type, color 
%              spec, or set description.
%
% Author:       Paul McCarthy <paul.mccarthy@csiro.au>
% Contributor:  Guillaume Galibert <guillaume.galibert@utas.edu.au>
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
if ~ischar(qcClass)...
&& ~isnumeric(qcClass), error('qcClass must be a string or numeric'); end
if ~isnumeric(qcSet),   error('qcSet must be numeric');               end
if ~ischar(field),      error('field must be a string');              end

value = '';

% open the IMOSQCFlag file - it should be 
% in the same directory as this m-file
path = '';
if ~isdeployed, [path, ~, ~] = fileparts(which('imosToolbox.m')); end
if isempty(path), path = pwd; end
path = fullfile(path, 'IMOS');

fidS = -1;
fidF = -1;
try
  % read in the QC sets
  fidS = fopen([path filesep 'imosQCSet.txt'], 'rt');
  if fidS == -1, return; end
  sets  = textscan(fidS, '%f%s%s%s%s', 'delimiter', ',', 'commentStyle', '%');
  fclose(fidS);
  
  % read in the QC flag values for each set
  fidF = fopen([path filesep 'imosQCFlag.txt'], 'rt');
  if fidF == -1, return; end
  flags = textscan(fidF, '%f%s%s%s%s', 'delimiter', ',', 'commentStyle', '%');
  fclose(fidF);

catch e
  if fidS ~= -1, fclose(fidS); end
  if fidF ~= -1, fclose(fidF); end
  rethrow(e);
end

% no set definitions in file
if isempty(sets{1}), return; end

% no flag definitions in file
if isempty(flags{1}), return; end

% get the qc set description (or reset the qc set to 1)
qcSetIdx = (sets{1} == qcSet);
if ~any(qcSetIdx), qcSetIdx(1) = 1; end;

% if the request was the set description, set values, output 
% type, or minimum/maximum value, retrieve and return them 
if strcmp(field, 'set_desc')
  
  value = sets{2}(qcSetIdx);
  value = value{1};
  return;
  
elseif strcmp(field, 'values') || strcmp(field, 'min') || strcmp(field, 'max')
  
  val = sets{3}(qcSetIdx);
  val = val{1};
  
  % try to convert to a vector of numbers, otherwise return a string
  value = str2num(val); % we need str2num as we deal with an array
  if isempty(value)
    value = val(val ~= ' ');
  else
    value = int8(value);
  end
  
  % return only the min/max value if requested
  if     strcmp(field, 'min'), value = value(1);
  elseif strcmp(field, 'max'), value = value(end);
  end
  
  return;
  
elseif strcmp(field, 'type')
  
  value = sets{4}(qcSetIdx);
  value = value{1};
  
  return;
elseif strcmp(field, 'fill_value')
  
  val   = sets{5}(qcSetIdx);
  if strcmpi(imosQCFlag(qcClass, qcSet, 'type'), 'byte')
    value = str2double(val);
    value = int8(value);
  else
    value = val{1};
  end
  
  return;
end

% find a flag entry with matching qcSet and qcClass values
lines = find(flags{1} == qcSet);
for k=1:length(lines)
  
  if strcmp(field, 'color') || strcmp(field, 'desc')
    
    % flag value may have been passed in as a number or a character
    flagVal = num2str(qcClass);
    
    if flagVal == flags{2}{lines(k)}
      
      switch (field)
        
        case 'color'
      
          value = flags{4}{lines(k)};

          % if color was specified numerically, convert it from a string
          temp = str2num(value); % we need str2num as we deal with an array
          if ~isempty(temp), value = temp; end
          return;
        case 'desc'
          value = flags{3}{lines(k)};
          return;
      end
    end
    continue;
  end
  
  classes = flags{5}{lines(k)};

  % dirty hack to get around matlab's lack of support for word boundaries
  classes = [' ' classes ' '];

  % if this flag matches the class, we've found the flag value to return
  if ~isempty(regexpi(classes, ['\s' qcClass '\s'], 'match'))

    switch(field)
      case 'flag'
        % try to convert to a number, on failure 
        % just return the character
        value = str2double(flags{2}{lines(k)});
        if isnan(value)
            value = flags{2}{lines(k)};
        else
            value = int8(value);
        end
    end

    return;
  end
end
