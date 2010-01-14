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
%   Dissolved Oxygen  (floating point, millilitres/Litre)
%   Dissolved Oxygen  (floating point, millimole/metre^3)
%   Chlorophyll       (floating point, micrograms/Litre)
%   Turbidity         (floating point, NTU)
%
% Any other fields which are present in the input file will be ignored.
%
% Inputs:
%   filename    - name of the input file to be parsed
%
% Outputs:
%   sample_data - contains a time vector (in matlab numeric format), and a 
%                 vector of up to nine variable structs, containing sample 
%                 data. The possible variables are as follows:
%
%                   Conductivity      ('CNDC'): S m^-1
%                   Temperature       ('TEMP'): Degrees Celsius
%                   Pressure          ('PRES'): Decibars
%                   Salinity          ('PSAL'): 1e^(-3) (PSS)
%                   Dissolved Oxygen  ('DOXY'): kg/m^3
%                   Dissolved Oxygen  ('DOX2'): mol/kg
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

  % Lookup arrays for supported and required fields
  params   = {};
  required = {};

  %
  % this table provides mappings from the WQM field name (the column header 
  % in the input file) to the IMOS compliant parameter name. It also contains 
  % comments for some parameters.
  %
  params{end+1} = {'WQM',             {'',     ''}};
  params{end+1} = {'SN',              {'',     ''}};
  params{end+1} = {'MMDDYY',          {'',     ''}};
  params{end+1} = {'HHMMSS',          {'',     ''}};
  params{end+1} = {'Cond(mmho)',      {'CNDC', ''}};
  params{end+1} = {'Temp(C)',         {'TEMP', ''}};
  params{end+1} = {'Pres(dbar)',      {'PRES', ''}};
  params{end+1} = {'Sal(PSU)',        {'PSAL', ''}};
  params{end+1} = {'DO(mg/l)',        {'DOXY', ''}};
  params{end+1} = {'DO(mmol/m^3)',    {'DOXY', ''}};
  params{end+1} = {'DO(ml/l)',        {'DOX2', ''}};
  params{end+1} = {'CHL(ug/l)',       {'CPHL', ''}};
  params{end+1} = {'F-Cal-CHL(ug/l)', {'CPHL', 'Factory coefficient'}};
  params{end+1} = {'U-Cal-CHL(ug/l)', {'CPHL', 'User coefficient'}};
  params{end+1} = {'NTU',             {'TURB', ''}};

  %
  % This array contains the column headers which must be in the input file.
  %
  required = {
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
    fid = fopen(filename, 'rt');
    if fid == -1, error(['couldn''t open ' filename 'for reading']); end

    [fields format] = getFormat(fid, required, params);

    % read in the data
    samples = textscan(fid, format);
    fclose(fid);
  catch e
    if fid ~= -1, fclose(fid); end
    rethrow(e);
  end

  %fill in sample and cal data
  sample_data            = struct;
  sample_data.meta       = struct;
  sample_data.dimensions = {};
  sample_data.variables  = {};

  sample_data.meta.instrument_make      = 'WET Labs';
  sample_data.meta.instrument_model     = 'WQM';
  sample_data.meta.instrument_serial_no = samples{1}{1};
  
  % convert and save the time data
  time = cellstr(samples{2});
  time = datenum(time, 'mmddyy HHMMSS')';
  
  % WQM instrumensts (or the .DAT conversion sofware) have a habit of
  % generating erroneous data sometimes, either missing a character , or 
  % inserting a 0 instead of the correct in the output to .DAT files.
  % This is a simple check to make sure that all of the timestamps appear
  % to be correct; there's only so much we can do though.
  invalid = [];
  for k = 2:length(time)
    if time(k) < time(k-1), invalid(end+1) = k; end
  end
  
  time(invalid) = [];
  for k = 1:length(samples)
    if k == 2, continue; end
    samples{k}(invalid) = []; 
  end
  
  sample_data.dimensions{1}.name = 'TIME';
  sample_data.dimensions{1}.data = time;

  % create a variables struct in sample_data for each field in the file
  % start index at 4 to skip serial, date and time
  for k = 4:length(fields)

    [name comment] = getParamDetails(fields{k}, params);  
    data = samples{k-1};

    % some fields are not in IMOS uom - scale them so that they are
    switch fields{k}

      % WQM provides conductivity in mS/m; we need it in S/m.
      case 'Cond(mmho)'
        data = data / 1000.0;

      % convert dissolved oxygen in mg/L to kg/m^3.
      case 'DO(mg/l)'
        data = data / 1000.0;
      
      % convert dissolved oxygen in mmol/m^3 to kg/m^3.
      case 'DO(mmol/m^3)'
        data = data * 32.0 / 1000000.0;
      
      % convert dissolved oxygen in ml/l to mol/kg
      case 'DO(ml/l)'
        
        % to perform this conversion, we need to calculate the 
        % density of sea water; for this, we need temperature, 
        % salinity, and pressure data to be present
        temp = getVar(sample_data.variables, 'TEMP');
        pres = getVar(sample_data.variables, 'PRES');
        psal = getVar(sample_data.variables, 'PSAL');
        
        % if any of this data isn't present, 
        % we can't perform the conversion
        if temp == 0, continue; end
        if pres == 0, continue; end
        if psal == 0, continue; end
        
        temp = sample_data.variables{temp};
        pres = sample_data.variables{pres};
        psal = sample_data.variables{psal};
        
        % calculate density from salinity, temperature and pressure
        dens = sw_dens(psal.data, temp.data, pres.data);
        
        % ml/l -> mol/kg
        % 
        %   % kg/m^3 -> gm/cm^3
        %   dens = dens ./ 1000.0;
        %
        %   % ml/l ->umol/kg
        %   data = data .* (44.6596 ./ dens);
        %
        %   % umol/kg -> mol/kg
        %   data = data ./ 1000000.0;
        %
        data = data .* (0.0446596 ./ dens);

      % WQM provides chlorophyll in ug/L; we need it in mg/m^3.
      % These are equivalent, so no scaling is needed.
      % case 'CPHL'

    end
        
    sample_data.variables{k-3}.dimensions = [1];
    sample_data.variables{k-3}.comment    = comment;
    sample_data.variables{k-3}.name       = name;
    sample_data.variables{k-3}.data       = data;
  end
  
  % remove empty entries (could occur if DO(ml/l) data is 
  % present, but temp/pressure/salinity data is not)
  sample_data.variables(cellfun(@isempty, sample_data.variables)) = [];

end

function [fields format] = getFormat(fid, required, params)
%GETFORMAT Figures out the format pattern to give to textscan, based on the 
% list of fields that are present in the file header (tokens contained in 
% the first line of the file).
%
% The function checks that all of the required columns are present in the file.
%
% Returns a list of all the fields to expect, and the textscan format to use.
%
% The list of required fields are listed in the required variable which is 
% defined in the main function above.
%
  % read in header
  fields = fgetl(fid);
  fields = textscan(fields, '%s');
  fields = fields{1};

  % test that required fields are present
  for k = 1:length(required)

    if ~ismember(required{k}, fields)
      error([required{k} ...
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
  % keep track of indices of unsupported fields - we remove them afterwards
  %
  unsupported = [];
  for k = 4:length(fields)
    if isSupported(fields{k}, params); 
      format = [format '%f']; 
    else
      format = [format '%*s'];
      unsupported = [unsupported k];
    end
  end

  %remove unsupported fields from header list
  fields(unsupported) = [];
end

function [name comment] = getParamDetails(field, params)
%GETPARAMDETAILS Returns the IMOS-compliant name, and an optional comment 
% for the given WQM field.
%
% The mappings are provided in the params variable, which is defined in the 
% main function.
%
  name = '';
  comment = '';
  
  entry = {};
  
  for k = 1:length(params)
    if strcmp(params{k}{1}, field)
      entry = params{k};
      break;
    end
  end
  
  if isempty(entry), return; end

  name    = entry{2}{1};
  comment = entry{2}{2};
end

function supported = isSupported(field, params)
%ISSUPPORTED returns logical true (1) if the given WQM field is supported,
% false (0) otherwise.
%
% If a field is supported, it will be contained in the params variable.
%
supported = false;

  for k = 1:length(params)

    if strcmp(params{k}{1}, field)
      supported = true;
      break;
    end
  end
end
