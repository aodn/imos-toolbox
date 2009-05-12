function sample_data = WQMParse( filename )
%WQMParse Parse a .dat file retrieved from a Wetlabs WQM instrument.
%
% This function is able to parse data retrieved from a Wetlabs WQM CTD/ECO 
% instrument. The data must be in '.dat' format, i.e. raw data which has been
% processed by the WQMHost software, in tab-delimited format. WQMHost allows a 
% wide range of fields to be included in the output file; the following are 
% supported by this parser:
%
%   WQM               (literal 'WQM')
%   SN                (serial number - required)
%   MMDDYY            (date - required)
%   HHMMSS            (time - required)
%   Conductivity      (floating point, milliSiemens/metre)
%   Temperature       (floating point, Degrees Celsius)
%   Presssure         (floating point, Decibar)
%   Salinity          (floating point, PSS)
%   Dissolved Oxygen  (floating point, milligrams/Litre)
%   Chlorophyll       (floating point, micrograms/Litre)
%   Turbidity         (floating point, NTU)
%
% Any other parameters which are present in the input file will be ignored.
%
% Inputs:
%   filename    - name of the input file to be parsed
%
% Outputs:
%   sample_data - contains a time vector (in matlab numeric format), and a 
%                 vector of up to eight variable structs, containing sample 
%                 data. The possible parameters are as follows:
%
%                   Conductivity      ('CNDC'): S m^-1
%                   Temperature       ('TEMP'): Degrees Celsius
%                   Pressure          ('PRES'): Decibars
%                   Salinity          ('PSAL'): 1e^(-3) (PSS)
%                   Dissolved Oxygen  ('DOXY'): kg/m^3
%                   Chlorophyll       ('CPHL'): mg/m^3   (user coefficient)
%                   Chlorophyll       ('CPHL'): mg/m^3   (factory coefficient)
%                   Turbidity         ('TURB') NTU
%                 
%                 Also contains some metadata fields. The '.dat' output 
%                 format does not contain any calibration information, so 
%                 only the following are present:
%   
%                   instrument_make:      'WET Labs'
%                   instrument_model:     'WQM'
%                   instrument_serial_no: retrieved from input file
%
% Author: Paul McCarthy <paul.mccarthy@csiro.au>
%
% See http://www.wetlabs.com/products/wqm/wqm.htm
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

% ensure that there is exactly one argument, 
% and that it is a cell array of strings
error(nargchk(1, 1, nargin));
if ~iscell(filename), error('filename must be a cell array'); end

filename = filename{1};
if ~ischar(filename), error('filename must contain a string'); end

% Lookup table/array for supported and required parameters
global PARAMS;
global REQUIRED;

%
% this table provides mappings from the WQM parameter name (the column header 
% in the input file) to the IMOS compliant parameter name. It also contains 
% comments for some parameters.
%
PARAMS = java.util.Hashtable;
PARAMS.put('WQM',             {'',     ''});
PARAMS.put('SN',              {'',     ''});
PARAMS.put('MMDDYY',          {'',     ''});
PARAMS.put('HHMMSS',          {'',     ''});
PARAMS.put('Cond(mmho)',      {'CNDC', ''});
PARAMS.put('Temp(C)',         {'TEMP', ''});
PARAMS.put('Pres(dbar)',      {'PRES', ''});
PARAMS.put('Sal(PSU)',        {'PSAL', ''});
PARAMS.put('DO(mg/l)',        {'DOXY', ''});
PARAMS.put('F-Cal-CHL(ug/l)', {'CPHL', 'Factory coefficient'});
PARAMS.put('U-Cal-CHL(ug/l)', {'CPHL', 'User coefficient'});
PARAMS.put('NTU',             {'TURB', ''});

%
% This array contains the column headers which must be in the input file.
%
REQUIRED = {
  'SN'
  'MMDDYY'
  'HHMMSS'
};

% open file, get header and use it to generate a 
% format string which we can pass to textscan
fid     = -1;
samples = [];
fields  = [];
format  = [];
try
  fid = fopen(filename);
  if fid == -1, error(['couldn''t open ' filename 'for reading']); end

  [fields format] = getFormat(fid);

  % read in the data
  samples = textscan(fid, format);
  fclose(fid);
catch e
  if fid ~= -1, fclose(fid); end
  rethrow(e);
end

%fill in sample and cal data
sample_data           = struct;
sample_data.variables = struct;

sample_data.instrument_make      = 'WQM';
sample_data.instrument_model     = 'WET Labs';
sample_data.instrument_serial_no = samples{1}{1};

% create a parameters struct in sample_data for each parameter in the file
% start index at 4 to skip serial, date and time
for k = 4:length(fields)
  
  [name comment] = getParamDetails(fields{k});  
  data = samples{k-1};
  
  % some parameters are not in IMOS uom - scale them so that they are
  switch name
    
    % WQM provides conductivity in mS/m; we need it in S/m.
    case 'CNDC'
      data = data / 1000.0;
    
    % WQM provides dissolved oxygen in mg/L; we need it in kg/m^3.
    % Actually, these work out to be equivalent, so no scaling is needed
    % case 'DOXY'
      
    % WQM provides chlorophyll in ug/L; we need it in mg/m^3.
    % Again, these are equivalent, so no scaling is needed.
    % case 'CPHL'
      
  end
  
  sample_data.variables(k-3).dimensions = [1];
  sample_data.variables(k-3).comment    = comment;
  sample_data.variables(k-3).name       = name;
  sample_data.variables(k-3).data       = data;
end

% convert and save the time data
time = cellstr(samples{2});
sample_data.dimensions(1).name = 'TIME';
sample_data.dimensions(1).data = datenum(time, 'mmddyy HHMMSS')';

%
%% getFormat generates a format for textscan from the file header
%

function [fields format] = getFormat(fid)
%GETFORMAT Figures out the format pattern to give to textscan, based on the 
% list of parameters that are present in the file header (tokens contained in 
% the first line of the file).
%
% The function checks that all of the required columns are present in the file.
%
% Returns a list of all the fields to expect, and the textscan format to use.
%
% The list of required parameters are listed in the global REQUIRED_PARAMETERS 
% variable which is defined in the main function above.
%
global REQUIRED;

% read in header
fields = fgetl(fid);
fields = textscan(fields, '%s');
fields = fields{1};

% test that required fields are present
for k = 1:length(REQUIRED)

  if ~ismember(REQUIRED{k}, fields)
    error([REQUIRED{k} ...
      ' field is missing from WQM file - this field is required']);
  end
end

%
% build the format string
%
format = '';

% WQM column, if present
if strcmp('WQM', fields{1})
  format = 'WQM '; 
  fields(1) = []; 
end

% serial and time/date
format = [format '%s%13c'];

%
% floating point values, or ignore if unsupported, for all other fields.
% start index at 4 to skip serial number, date and time.
% keep track of indices of unsupported parameters - we remove them afterwards
%
unsupported = [];
for k = 4:length(fields)
  if isSupported(fields{k}); 
    format = [format '%f']; 
  else
    format = [format '%*s'];
    unsupported = [unsupported k];
  end
end

%remove unsupported parameters from header list
fields(unsupported) = [];

%
%% getParamDetails returns the IMOS parameter name, and an optional 
% comment for the given WQM parameter name.
%

function [name comment] = getParamDetails(param)
%GETPARAMDETAILS
% Returns the IMOS-compliant name, and an optional comment for the given WQM
% parameter.
%
% The mappings are provided in the global PARAMS variable (a 
% java.util.Hashtable), which is defined in the main function.
%

global PARAMS;

name = '';
comment = '';

entry = PARAMS.get(param);
if ~isempty(entry)
  name    = entry(1);
  comment = entry(2);
  
  % they're java.lang.String arrays - we just want the string
  name    = char(name(1));
  comment = char(comment(1));
end

%
%% isSupported determines whether the given WQM parameter is 
% supported.
%

function supported = isSupported(param)
%ISSUPPORTED returns logical true (1) if the given WQM parameter is supported,
% false (0) otherwise.
%
% If a parameter is supported, it will be contained in the global PARAMS 
% variable.
%

global PARAMS;

supported = PARAMS.containsKey(param);
