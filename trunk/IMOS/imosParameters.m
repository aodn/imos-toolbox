function value = imosParameters( short_name, field )
%IMOSPARAMETERS Returns IMOS compliant standard name, units of measurement, 
% data code, fill value or valid min/max value given the short parameter name.
%
% The list of all IMOS parameters is stored in a file 'imosParameters.txt'
% which is in the same directory as this m-file.
%
% The file imosParameters.txt contains a list of all parameters for which an
% IMOS compliant identifier (the short_name) exists. This function looks up the 
% given short_name and returns the corresponding standard name, long name, 
% units of measurement, data code, fill value or valid min/max value. If the 
% given short_name is not in the list of IMOS parameters, an error is raised.
%
% Currently, requests for long name and standard name return the same value, 
% unless the requested field is the standard name, and the parameter is not a
% CF-standard parameter, in which case an empty string is returned.
%
% Inputs:
%   short_name  the IMOS parameter name
%   field      - either 'standard_name', 'long_name', 'uom', 'data_code',
%                'fill_value', 'valid_min' or 'valid_max',
%
% Outputs:
%   value      - the IMOS standard name, unit of measurement, data code, 
%                fill value or valid min/max value, whichever was requested.
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

error(nargchk(2, 2, nargin));
if ~ischar(short_name), error('short_name must be a string'); end
if ~ischar(field),      error('field must be a string');      end

value = nan;

% account for numbered parameters (if the dataset 
% contains more than one variable of the same name)
match = regexp(short_name, '_\d$');
if ~isempty(match), short_name(match:end) = ''; end

% get the location of this m-file, which is 
% also the location of imosParamaters.txt
path = fileparts(which(mfilename));

fid = -1;
params = [];
try
  fid = fopen([path filesep 'imosParameters.txt'], 'rt');
  if fid == -1, return; end
  
  params = textscan(fid, '%s%d%s%s%s%f%f%f', ...
    'delimiter', ',', 'commentStyle', '%');
  fclose(fid);
catch e
  if fid ~= -1, fclose(fid); end
  rethrow(e);
end

names          = params{1};
cfCompliance   = params{2};
standard_names = params{3};
uoms           = params{4};
data_codes     = params{5};
fillValues     = params{6};
validMins      = params{7};
validMaxs      = params{8};

% search the list for a match
for k = 1:length(names)

  if strcmp(short_name, names{k})

    switch field
      case 'standard_name', 
        if ~cfCompliance(k), value = '';
        else                 value = standard_names{k};
        end
      case 'long_name',      value = standard_names{k};
      case 'uom'
        value = uoms{k};
        if strcmp(value, 'percent'), value = '%'; end
      case 'data_code',      value = data_codes    {k};
      case 'fill_value',     value = fillValues    (k);
      case 'valid_min',      value = validMins     (k);
      case 'valid_max',      value = validMaxs     (k);
    end
    break;
  end
end

if isnan(value)
  error([short_name ' is not a recognised IMOS parameter']); 
end
