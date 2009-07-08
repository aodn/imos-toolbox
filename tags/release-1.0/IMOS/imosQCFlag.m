function value = imosQCFlag( qc_class, qc_set, field )
%IMOSQCFLAG Returns an appropriate QC flag value (String), description, color 
% spec, output type, minimum/maximum value, fill value, or set description for 
% the given qc_class (String), using the given qc_set (integer).
%
% The QC sets definitions, descriptions, output types, and valid flag values 
% for each, are maintained in the file  'imosQCFlag.txt' which is stored  in 
% the same directory as this m-file.
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
%   qc_class - If field is one of 'flag', 'desc' or 'color', must be one 
%              of the (case insensitive) strings listed in the imosQCSets.txt 
%              file. If it is not equal to one of these strings, the return 
%              value will be empty.
%
%   qc_set   - must be an integer identifier to one of the supported QC sets. 
%              If it does not map to a supported QC set, it is assumed to be 
%              the first qc set defined in the imosQCSets.txt file.
%
%   field    - String which defines what the return value is. Must be one
%              of 'flag', 'desc', 'set_desc', 'type', 'values' 'min', 'max',
%              'fill_value', or 'color'.
%
% Outputs:
%   value    - One of the flag value, flag description, output type, color 
%              spec, or set description.
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
if ~ischar(qc_class)...
&& ~isnumeric(qc_class), error('qc_class must be a string or numeric'); end
if ~isnumeric(qc_set),   error('qc_set must be numeric');               end
if ~ischar(field),       error('field must be a string');               end

value = '';

% open the IMOSQCSets file - it should be 
% in the same directory as this m-file
path = fileparts(which(mfilename));

fid = -1;
flags = [];
sets = [];
try
  fid = fopen([path filesep 'imosQCFlag.txt']);
  if fid == -1, return; end

  % read in the QC sets and flag values for each set
  sets  = textscan(fid, '%f%s%s%s%s', 'delimiter', ',', 'commentStyle', '%');
  flags = textscan(fid, '%f%s%s%s%s', 'delimiter', ',', 'commentStyle', '%');
  fclose(fid);

catch e
  if fid ~= -1, fclose(fid); end
  rethrow(e);
end

% no set definitions in file
if isempty(sets{1}), return; end

% no flag definitions in file
if isempty(flags{1}), return; end

% get the qc set description (or reset the qc set to 1)
qc_set_idx = find(sets{1} == qc_set);
if isempty(qc_set_idx), qc_set_idx = 1; end;

% if the request was the set description, set values, output 
% type, or minimum/maximum value, retrieve and return them 
if strcmp(field, 'set_desc')
  
  value = sets{2}(qc_set_idx);
  value = value{1};
  return;
  
elseif strcmp(field, 'values') || strcmp(field, 'min') || strcmp(field, 'max')
  
  val = sets{3}(qc_set_idx);
  val = val{1};
  
  % try to convert to a vector of numbers, otherwise return a string
  value = str2num(val);
  if isempty(value), value = val(val ~= ' '); end
  
  % return only the min/max value if requested
  if     strcmp(field, 'min'), value = value(1);
  elseif strcmp(field, 'max'), value = value(end);
  end
  
  return;
  
elseif strcmp(field, 'type')
  
  value = sets{4}(qc_set_idx);
  value = value{1};
  
  return;
elseif strcmp(field, 'fill_value')
  
  val   = sets{5}(qc_set_idx);
  value = str2double(val);
  if isnan(value), value = val; end
  
  return;
end

% find a flag entry with matching qc_set and qc_class values
lines = find(flags{1} == qc_set);
for k=1:length(lines)
  
  if strcmp(field, 'color') || strcmp(field, 'desc')
    
    % flag value may have been passed in as a number or a character
    flagVal = num2str(qc_class);
    
    if flagVal == flags{2}{lines(k)}
      
      switch (field)
        
        case 'color'
      
          value = flags{4}{lines(k)};

          % if color was specified numerically, convert it from a string
          temp = str2num(value);
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
  if ~isempty(regexpi(classes, ['\s' qc_class '\s'], 'match'))

    switch(field)
      case 'flag'
        % try to convert to a number, on failure 
        % just return the character
        value = str2double(flags{2}{lines(k)});
        if isnan(value), value = flags{2}{lines(k)};
        end
    end

    return;
  end
end
