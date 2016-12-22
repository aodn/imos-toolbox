function sample_data = readWQMdat( filename, mode )
%readWQMdat parses a .dat file retrieved from a Wetlabs WQM instrument.
%
% This function is able to parse data retrieved from a Wetlabs WQM CTD/ECO 
% instrument. The data must be in '.dat' format, i.e. raw data which has been
% processed by the WQMHost software, in tab-delimited format. WQMHost allows a 
% wide range of fields to be included in the output file; the following are 
% supported by this parser:
%
%   WQM                 (literal 'WQM')
%   SN                  (serial number - required)
%   MMDDYY              (date - required)
%   HHMMSS              (time - required)
%   WQM-SN              (serial number - required)
%   MM/DD/YY            (date - required)
%   HH:MM:SS            (time - required)
%   Cond(mmho)          (floating point conductivity, Siemens/metre)
%   Cond(S/m)           (floating point conductivity, Siemens/metre)
%   Temp(C)             (floating point temperature, Degrees Celsius)
%   Pres(dbar)          (floating point pressure, Decibar)
%   Sal(PSU)            (floating point salinity, PSS)
%   DO(mg/l)            (floating point dissolved oxygen, milligrams/Litre)
%   DO(ml/l)            (floating point dissolved oxygen, millilitres/Litre)
%   DO(mmol/m^3)        (floating point dissolved oxygen, millimole/metre^3)
%   CHL(ug/l)           (floating point chlorophyll, micrograms/Litre)
%   CHLa(ug/l)          (floating point chlorophyll, micrograms/Litre)
%   F-Cal-CHL(ug/l)     (floating point factory coefficient chlorophyll, micrograms/Litre)
%   Fact-CHL(ug/l))     (floating point factory coefficient chlorophyll, micrograms/Litre)
%   U-Cal-CHL(ug/l)     (floating point user coefficient chlorophyll, micrograms/Litre)
%   RawCHL(Counts)      (integer fluorescence in raw counts)
%   CHLa(Counts)        (integer fluorescence in raw counts)
%   NTU                 (floating point turbidity, NTU)
%   NTU(NTU)            (floating point turbidity, NTU)
%   Turbidity(NTU)      (floating point turbidity, NTU)
%   rho                 (floating point density, kg/metre^3)
%   PAR(umol_phtn/m2/s) (floating point photosynthetically active radiation, micromole of photon/m2/s)
%
% Any other fields which are present in the input file will be ignored.
%
% Inputs:
%   filename    - name of the input file to be parsed
%   mode        - Toolbox data type mode.
%
% Outputs:
%   sample_data - contains a time vector (in matlab numeric format), and a 
%                 vector of up to nine variable structs, containing sample 
%                 data. The possible variables are as follows:
%
%                   Conductivity      ('CNDC'): S m^-1
%                   Temperature       ('TEMP'): Degrees Celsius
%                   Pressure          ('PRES_REL'): Decibars
%                   Salinity          ('PSAL'): 1e^(-3) (PSS)
%                   Dissolved Oxygen  ('DOXY'): kg/m^3
%                   Dissolved Oxygen  ('DOX1'): mmol/m^3
%                   Dissolved Oxygen  ('DOX2'): umol/kg
%                   Chlorophyll       ('CPHL'): mg/m^3
%                   Chlorophyll       ('CHLU'): mg/m^3   (user coefficient)
%                   Chlorophyll       ('CHLF'): mg/m^3   (factory coefficient)
%                   Fluorescence      ('FLU2'): raw counts
%                   Turbidity         ('TURB'): NTU
%                   Density           ('DENS'): kg/m^3
%                   Photosynthetically active radiation ('PAR'): umol_phtn/m^2/s
%                 
%                 Also contains some metadata fields. The '.dat' output 
%                 format does not contain any calibration information, so 
%                 only the following are present:
%   
%                   instrument_make:      'WET Labs'
%                   instrument_model:     'WQM'
%                   instrument_serial_no: retrieved from input file
%
% Author:       Paul McCarthy <paul.mccarthy@csiro.au>
% Contributor:  Brad Morris <b.morris@unsw.edu.au>
% 				Guillaume Galibert <guillaume.galibert@utas.edu.au>
%
% See http://www.wetlabs.com/products/wqm/wqm.htm
%

%
% Copyright (c) 2016, Australian Ocean Data Network (AODN) and Integrated 
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
%     * Neither the name of the AODN/IMOS nor the names of its contributors 
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
  % ensure that there are exactly two arguments
  narginchk(2, 2);
  if ~ischar(filename), error('filename must contain a string'); end

  % Lookup arrays for supported and required fields
  params   = {};

  %
  % this table provides mappings from the WQM field name (the column header 
  % in the input file) to the IMOS compliant parameter name. It also contains 
  % comments for some parameters.
  %
  params{end+1} = {'WQM',                   {'',     ''}};
  params{end+1} = {'SN',                    {'',     ''}};
  params{end+1} = {'WQM-SN',                {'',     ''}};
  params{end+1} = {'MMDDYY',                {'',     ''}};
  params{end+1} = {'HHMMSS',                {'',     ''}};
  params{end+1} = {'MM/DD/YY',              {'',     ''}};
  params{end+1} = {'HH:MM:SS',              {'',     ''}};
  params{end+1} = {'Cond(mmho)',            {'CNDC', ''}}; % mmho <=> mS , I think /mm is assumed
  params{end+1} = {'Cond(S/m)',             {'CNDC', ''}}; 
  params{end+1} = {'Temp(C)',               {'TEMP', ''}};
  params{end+1} = {'Pres(dbar)',            {'PRES_REL', ''}};
  params{end+1} = {'Sal(PSU)',              {'PSAL', ''}};
  params{end+1} = {'DO(mg/l)',              {'DOX1_3', ''}};
  params{end+1} = {'DO(mmol/m^3)',          {'DOX1_1', ''}};
  params{end+1} = {'DO(ml/l)',              {'DOX1_2', ''}};
  params{end+1} = {'CHL(ug/l)',             {'CPHL', 'Artificial chlorophyll data '...
      'computed from bio-optical sensor raw counts measurements. The '...
      'fluorometre is equipped with a 470nm peak wavelength LED to irradiate and a '...
      'photodetector paired with an optical filter which measures everything '...
      'that fluoresces in the region of 695nm. '...
      'Originally expressed in ug/l, 1l = 0.001m3 was assumed.'}};  
  params{end+1} = {'CHLa(ug/l)',            {'CPHL', 'Artificial chlorophyll data '...
      'computed from bio-optical sensor raw counts measurements. The '...
      'fluorometre is equipped with a 470nm peak wavelength LED to irradiate and a '...
      'photodetector paired with an optical filter which measures everything '...
      'that fluoresces in the region of 695nm. '...
      'Originally expressed in ug/l, 1l = 0.001m3 was assumed.'}};  
  params{end+1} = {'F-Cal-CHL(ug/l)',       {'CHLF', 'Artificial chlorophyll data '...
      'computed from bio-optical sensor raw counts measurements using factory calibration coefficient. The '...
      'fluorometre is equipped with a 470nm peak wavelength LED to irradiate and a '...
      'photodetector paired with an optical filter which measures everything '...
      'that fluoresces in the region of 695nm. '...
      'Originally expressed in ug/l, 1l = 0.001m3 was assumed.'}};
  params{end+1} = {'Fact-CHL(ug/l))',       {'CHLF', 'Artificial chlorophyll data '...
      'computed from bio-optical sensor raw counts measurements using factory calibration coefficient. The '...
      'fluorometre is equipped with a 470nm peak wavelength LED to irradiate and a '...
      'photodetector paired with an optical filter which measures everything '...
      'that fluoresces in the region of 695nm. '...
      'Originally expressed in ug/l, 1l = 0.001m3 was assumed.'}}; % v1.26 of Host software
  params{end+1} = {'U-Cal-CHL(ug/l)',       {'CHLU', 'Artificial chlorophyll data '...
      'computed from bio-optical sensor raw counts measurements using user calibration coefficient. The '...
      'fluorometre is equipped with a 470nm peak wavelength LED to irradiate and a '...
      'photodetector paired with an optical filter which measures everything '...
      'that fluoresces in the region of 695nm. '...
      'Originally expressed in ug/l, 1l = 0.001m3 was assumed.'}};
  params{end+1} = {'RawCHL(Counts)',        {'FLU2', ''}};
  params{end+1} = {'CHLa(Counts)',          {'FLU2', ''}};
  params{end+1} = {'NTU',                   {'TURB', ''}};
  params{end+1} = {'NTU(NTU)',              {'TURB', ''}};
  params{end+1} = {'Turbidity(NTU)',        {'TURB', ''}};
  params{end+1} = {'rho',                   {'DENS', ''}};
  params{end+1} = {'PAR(umol_phtn/m2/s)',   {'PAR', ''}};

  %
  % This array contains the column headers which must be in the input file.
  %
  required = upper({
    'SN',       'WQM-SN'
    'MMDDYY',   'MM/DD/YY'
    'HHMMSS',   'HH:MM:SS'
  });

  % open file, get header and use it to generate a 
  % format string which we can pass to textscan
  fid     = -1;
  samples = [];
  fields  = [];
  format  = [];
  try
    fid = fopen(filename, 'rt');
    if fid == -1, error(['couldn''t open ' filename 'for reading']); end

    [fields, format, jThere] = getFormat(fid, required, params);

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

  sample_data.toolbox_input_file        = filename;
  sample_data.meta.instrument_make      = 'WET Labs';
  sample_data.meta.instrument_model     = 'WQM';
  sample_data.meta.instrument_serial_no = samples{1}{1};
  sample_data.meta.featureType          = mode;
  
  % convert and save the time data
  time = cellstr(samples{2});
  switch jThere
      case 2
          timeFormat = 'mm/dd/yy HH:MM:SS';
      otherwise
          timeFormat = 'mmddyy HHMMSS';
  end
  time = datenum(time, timeFormat);
  
  % Let's find each start of bursts
  dt = [0; diff(time)];
  iBurst = [1; find(dt>(1/24/60)); length(time)+1];
  
  % let's read data burst by burst
  nBurst = length(iBurst)-1;
  firstTimeBurst = zeros(nBurst, 1);
  sampleIntervalInBurst = zeros(nBurst, 1);
  durationBurst = zeros(nBurst, 1);
  for i=1:nBurst
      timeBurst = time(iBurst(i):iBurst(i+1)-1);
      if numel(timeBurst)>1 % deals with the case of a file with a single sample in a single burst
          sampleIntervalInBurst(i) = median(diff(timeBurst*24*3600));
          firstTimeBurst(i) = timeBurst(1);
          durationBurst(i) = (timeBurst(end) - timeBurst(1))*24*3600 + sampleIntervalInBurst(i);
      end
  end
  
  sample_data.meta.instrument_sample_interval   = round(median(sampleIntervalInBurst));
  sample_data.meta.instrument_burst_interval    = round(median(diff(firstTimeBurst*24*3600)));
  sample_data.meta.instrument_burst_duration    = round(median(durationBurst));
  
  if sample_data.meta.instrument_sample_interval == 0, sample_data.meta.instrument_sample_interval = NaN; end
  if sample_data.meta.instrument_burst_interval  == 0, sample_data.meta.instrument_burst_interval  = NaN; end
  if sample_data.meta.instrument_burst_duration  == 0, sample_data.meta.instrument_burst_duration  = NaN; end
  
  sample_data.dimensions{1}.name            = 'TIME';
  sample_data.dimensions{1}.typeCastFunc    = str2func(netcdf3ToMatlabType(imosParameters(sample_data.dimensions{1}.name, 'type')));
  sample_data.dimensions{1}.data            = sample_data.dimensions{1}.typeCastFunc(time);
  
  sample_data.variables{end+1}.name           = 'TIMESERIES';
  sample_data.variables{end}.typeCastFunc     = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{end}.name, 'type')));
  sample_data.variables{end}.data             = sample_data.variables{end}.typeCastFunc(1);
  sample_data.variables{end}.dimensions       = [];
  sample_data.variables{end+1}.name           = 'LATITUDE';
  sample_data.variables{end}.typeCastFunc     = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{end}.name, 'type')));
  sample_data.variables{end}.data             = sample_data.variables{end}.typeCastFunc(NaN);
  sample_data.variables{end}.dimensions       = [];
  sample_data.variables{end+1}.name           = 'LONGITUDE';
  sample_data.variables{end}.typeCastFunc     = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{end}.name, 'type')));
  sample_data.variables{end}.data             = sample_data.variables{end}.typeCastFunc(NaN);
  sample_data.variables{end}.dimensions       = [];
  sample_data.variables{end+1}.name           = 'NOMINAL_DEPTH';
  sample_data.variables{end}.typeCastFunc     = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{end}.name, 'type')));
  sample_data.variables{end}.data             = sample_data.variables{end}.typeCastFunc(NaN);
  sample_data.variables{end}.dimensions       = [];

  % create a variables struct in sample_data for each field in the file
  % start index at 4 to skip serial, date and time
  isUmolPerL = false;
  
  for k = 4:length(fields)

    [name, comment] = getParamDetails(fields{k}, params);  
    data = samples{k-1};
    
    % some fields are not in IMOS uom - scale them so that they are
    switch upper(fields{k})
        
        % WQM provides conductivity S/m; exactly like we want it to be!
        
        % WQM can provide Dissolved Oxygen in mmol/m3,
        % hopefully 1 mmol/m3 = 1 umol/l
        % exactly like we want it to be!
        case upper('DO(mmol/m^3)') % DOX1_1
            comment = 'Originally expressed in mmol/m3, 1l = 0.001m3 was assumed.';
            isUmolPerL = true;
            
        % convert dissolved oxygen in ml/l to umol/l
        case upper('DO(ml/l)') % DOX1_2
            comment = 'Originally expressed in ml/l, 1ml/l = 44.660umol/l was assumed.';
            isUmolPerL = true;
            
            % ml/l -> umol/l
            %
            % Conversion factors from Saunders (1986) :
            % https://darchive.mblwhoilibrary.org/bitstream/handle/1912/68/WHOI-89-23.pdf?sequence=3
            % 1ml/l = 43.57 umol/kg (with dens = 1.025 kg/l)
            % 1ml/l = 44.660 umol/l
            
            data = data .* 44.660;
            
        % convert dissolved oxygen in mg/L to umol/l.
        case upper('DO(mg/l)') % DOX1_3
            data = data * 44.660/1.429; % O2 density = 1.429 kg/m3
            comment = 'Originally expressed in mg/l, O2 density = 1.429kg/m3 and 1ml/l = 44.660umol/l were assumed.';
            isUmolPerL = true;
            
        % WQM provides chlorophyll in ug/L; we need it in mg/m^3, 
        % hopefully it is equivalent.
    end
        
    coordinates = 'TIME LATITUDE LONGITUDE NOMINAL_DEPTH';
    
    % dimensions definition must stay in this order : T, Z, Y, X, others;
    % to be CF compliant
    sample_data.variables{end+1}.dimensions         = 1;
    sample_data.variables{end}.name                 = name;
    sample_data.variables{end}.typeCastFunc         = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{end}.name, 'type')));
    sample_data.variables{end}.data                 = sample_data.variables{end}.typeCastFunc(data);
    sample_data.variables{end}.coordinates          = coordinates;
    sample_data.variables{end}.comment              = comment;
    
    % WQM uses SeaBird pressure sensor
    if strncmp('PRES_REL', sample_data.variables{end}.name, 8)
        % let's document the constant pressure atmosphere offset previously 
        % applied by SeaBird software on the absolute presure measurement
        sample_data.variables{end}.applied_offset = sample_data.variables{end}.typeCastFunc(-14.7*0.689476);
    end
  end
  
  % remove empty entries (could occur if DO(ml/l) data is 
  % present, but temp/pressure/salinity data is not)
  sample_data.variables(cellfun(@isempty, sample_data.variables)) = [];

  % Let's add a new parameter
  if isUmolPerL
      data = getVar(sample_data.variables, 'DOX1_1');
      comment = ['Originally expressed in mmol/m3, assuming 1l = 0.001m3 '...
          'and using density computed from Temperature, Salinity and Pressure '...
          'with the CSIRO SeaWater library (EOS-80) v1.1.'];
      if data == 0
          data = getVar(sample_data.variables, 'DOX1_2');
          comment = ['Originally expressed in ml/l, assuming 1ml/l = 44.660umol/l '...
              'and using density computed from Temperature, Salinity and Pressure '...
              'with the CSIRO SeaWater library (EOS-80) v1.1.'];
          if data == 0
              data = getVar(sample_data.variables, 'DOX1_3');
              comment = ['Originally expressed in mg/l, assuming O2 density = 1.429kg/m3, 1ml/l = 44.660umol/l '...
                  'and using density computed from Temperature, Salinity and Pressure '...
                  'with the CSIRO SeaWater library (EOS-80) v1.1.'];
          end
      end
      data = sample_data.variables{data};
      data = data.data;
      name = 'DOX2';
      
      % umol/l -> umol/kg
      %
      % to perform this conversion, we need to calculate the
      % density of sea water; for this, we need temperature,
      % salinity, and pressure data to be present
      temp = getVar(sample_data.variables, 'TEMP');
      pres = getVar(sample_data.variables, 'PRES_REL');
      psal = getVar(sample_data.variables, 'PSAL');
      cndc = getVar(sample_data.variables, 'CNDC');
      
      % if any of this data isn't present,
      % we can't perform the conversion to umol/kg
      if temp ~= 0 && pres ~= 0 && (psal ~= 0 || cndc ~= 0)
          temp = sample_data.variables{temp};
          pres = sample_data.variables{pres};
          if psal ~= 0
              psal = sample_data.variables{psal};
          else
              cndc = sample_data.variables{cndc};
              % conductivity is in S/m and gsw_C3515 in mS/cm
              crat = 10*cndc.data ./ gsw_C3515;
              
              psal.data = gsw_SP_from_R(crat, temp.data, pres.data);
          end
          
          % calculate density from salinity, temperature and pressure
          dens = sw_dens(psal.data, temp.data, pres.data); % cannot use the GSW SeaWater library TEOS-10 as we don't know yet the position
          
          % umol/l -> umol/kg (dens in kg/m3 and 1 m3 = 1000 l)
          data = data .* 1000.0 ./ dens;
          
          sample_data.variables{end+1}.dimensions           = 1;
          sample_data.variables{end}.name                   = name;
          sample_data.variables{end}.typeCastFunc           = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{end}.name, 'type')));
          sample_data.variables{end}.data                   = sample_data.variables{end}.typeCastFunc(data);
          sample_data.variables{end}.coordinates            = coordinates;
          sample_data.variables{end}.comment                = comment;
      end
  end
end

function [fields, format, jThere] = getFormat(fid, required, params)
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
isThere = false;
% looking for the last line of the header (since 2012/12 new host WQM software introduces a header)
while ~isThere && ~feof(fid)
    % read in header
    fields = fgetl(fid);
    if isempty(fields), continue; end
    fields = textscan(fields, '%s');
    fields = fields{1};
    
    % test that required fields are present
    iThere = false(size(required, 1), 1);
    jThere = 1;
    for j=1:size(required, 2)
        if sum(ismember(required(:,j), upper(fields))) > sum(iThere)
            iThere = ismember(required(:,j), upper(fields));
            jThere = j;
        end
        if all(iThere)
            isThere = true;
            break;
        end
    end
end

if ~isThere
    requiredStr = '';
    finalPartStr = ' field is missing from WQM file - this field is required';
    iThere = find(~iThere);
    for i=1:length(iThere)
        if i==1
            requiredStr = ['"' required{iThere(i), jThere} '"'];
        else
            requiredStr = [requiredStr ', "' required{iThere(i), jThere} '"'];
            finalPartStr = ' fields are missing from WQM file - these fields are required';
        end
    end
    error([requiredStr finalPartStr]);
end

%
% build the format string
%
format = '';

% WQM column, if present
if strcmpi('WQM', fields{1})
    format = 'WQM ';
    fields(1) = [];
end

% serial and time/date
% try to take into account files with State variable included
if strcmpi('State', fields{2})
    switch jThere
        case 2
            nChar = 17;
        otherwise
            nChar = 13;
    end
    format = [format '%s 6 %' num2str(nChar) 'c'];
    fields(2)=[];
else
    switch jThere
        case 2
            nChar = 17;
        otherwise
            nChar = 13;
    end
    format = [format '%s%' num2str(nChar) 'c'];
end

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

function [name, comment] = getParamDetails(field, params)
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
    if strcmpi(params{k}{1}, field)
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

    if strcmpi(params{k}{1}, field)
      supported = true;
      break;
    end
  end
end
