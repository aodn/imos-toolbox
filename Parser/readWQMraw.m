function sample_data = readWQMraw( filename, mode )
%readWQMraw parses a .RAW file retrieved from a Wetlabs WQM instrument.
%
% This function is able to parse raw data retrieved from a Wetlabs WQM CTD/ECO 
% instrument. 
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
%                   Dissolved Oxygen  ('DOX2'): mol/kg
%                   fluorescence      ('CPHL'): mg/m^3
%                   Chlorophyll       ('CHLU'): mg/m^3   (user coefficient)
%                   Chlorophyll       ('CHLF'): mg/m^3   (factory coefficient)
%                   Turbidity         ('TURB') NTU
%                 
%                 Also contains some metadata fields and calibration information, so 
%                 the following are present:
%   
%                   meta.instrument_make:      'WET Labs'
%                   meta.instrument_model:     'WQM'
%                   meta.instrument_serial_no: retrieved from input file
%                   meta.instrument_sample_interval: retrieved from input file
%                   Calibration: retrieved from input file
%
% Author:       Charles James <charles.james@sa.gov.au>
% Contributor:  Guillaume Galibert <guillaume.galibert@utas.edu.au>
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
  params{end+1} = {'WQM',             {'',     ''}};
  params{end+1} = {'SN',              {'',     ''}};
  params{end+1} = {'MMDDYY',          {'',     ''}};
  params{end+1} = {'HHMMSS',          {'',     ''}};
  params{end+1} = {'conductivity',    {'CNDC', ''}};
  params{end+1} = {'temperature',     {'TEMP', ''}};
  params{end+1} = {'pressure',        {'PRES_REL', ''}};
  params{end+1} = {'salinity',        {'PSAL', ''}};
  params{end+1} = {'DO(mg/l)',        {'DOX1_3', ''}};
  params{end+1} = {'DO(mmol/m^3)',    {'DOX1_1', ''}};
  params{end+1} = {'oxygen',          {'DOX1_2', ''}};
  params{end+1} = {'fluorescence',    {'FLU2', ''}};
  params{end+1} = {'F_Cal_CHL',       {'CHLF', 'Artificial chlorophyll data '...
      'computed from bio-optical sensor raw counts measurements using factory calibration coefficient. The '...
      'fluorometre is equipped with a 470nm peak wavelength LED to irradiate and a '...
      'photodetector paired with an optical filter which measures everything '...
      'that fluoresces in the region of 695nm. '...
      'Originally expressed in ug/l, 1l = 0.001m3 was assumed.'}};
  params{end+1} = {'U_Cal_CHL',       {'CHLU', 'Artificial chlorophyll data '...
      'computed from bio-optical sensor raw counts measurements using user calibration coefficient. The '...
      'fluorometre is equipped with a 470nm peak wavelength LED to irradiate and a '...
      'photodetector paired with an optical filter which measures everything '...
      'that fluoresces in the region of 695nm. '...
      'Originally expressed in ug/l, 1l = 0.001m3 was assumed.'}};
  params{end+1} = {'backscatterance', {'TURB', ''}};
  % CJ where is PAR?? 
 % params{end+1} = {'PAR',             {'PAR', ''}};

  % open file, get header and use it to generate a 
  % format string which we can pass to textscan
  fid     = -1;
  samples = [];
  fields  = [];
  format  = [];
  try
    % use Charles James routine to access raw file
    wqmdata = readWQMinternal(filename);

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
  sample_data.meta.instrument_serial_no = wqmdata.SN;
  sample_data.meta.featureType          = mode;
  
  % convert and save the time data
  time = wqmdata.datenumber;
  
  % WQM instrumensts (or the .DAT conversion sofware) have a habit of
  % generating erroneous data sometimes, either missing a character , or 
  % inserting a 0 instead of the correct in the output to .DAT files.
  % This is a simple check to make sure that all of the timestamps appear
  % to be correct; there's only so much we can do though.
  iBadTime = (diff(time) <= 0);
  iBadTime = [false; iBadTime];
  time(iBadTime) = [];
  
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
      sampleIntervalInBurst(i) = median(diff(timeBurst*24*3600));
      firstTimeBurst(i) = timeBurst(1);
      durationBurst(i) = (timeBurst(end) - timeBurst(1))*24*3600 + sampleIntervalInBurst(i);
  end
  
  sample_data.meta.instrument_sample_interval   = round(median(sampleIntervalInBurst));
  sample_data.meta.instrument_burst_interval    = round(median(diff(firstTimeBurst*24*3600)));
  sample_data.meta.instrument_burst_duration    = round(median(durationBurst));
  
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
  isUmolPerL = false;
  
  varlabel = wqmdata.varlabel;
  for k = 1:length(varlabel)

    [name, comment] = getParamDetails(varlabel{k}, params);  

    data = wqmdata.(varlabel{k});
    data(iBadTime) = [];

    % some fields are not in IMOS uom - scale them so that they are
    switch varlabel{k}
        
        % WQM provides conductivity in S/m; exactly like we want it to be!
        
        % convert dissolved oxygen in mg/L to umol/l.
        case 'DO(mg/l)'
            data = data * 44.660/1.429; % O2 density = 1.429kg/m3
            comment = 'Originally expressed in mg/l, O2 density = 1.429kg/m3 and 1ml/l = 44.660umol/l were assumed.';
            isUmolPerL = true;
        
        % WQM can provide Dissolved Oxygen in mmol/m3,
        % hopefully 1 mmol/m3 = 1 umol/l
        % exactly like we want it to be!
        case 'DO(mmol/m^3)'
            comment = 'Originally expressed in mmol/m3, 1l = 0.001m3 was assumed.';
            isUmolPerL = true;
            
        % convert dissolved oxygen in ml/l to umol/l
        case 'oxygen'
            comment = 'Originally expressed in ml/l, 1ml/l = 44.660umol/l was assumed.';
            isUmolPerL = true;
            
            % ml/l -> umol/l
            %
            % Conversion factors from Saunders (1986) :
            % https://darchive.mblwhoilibrary.org/bitstream/handle/1912/68/WHOI-89-23.pdf?sequence=3
            % 1ml/l = 43.57 umol/kg (with dens = 1.025 kg/l)
            % 1ml/l = 44.660 umol/l
            
            data = data .* 44.660;
            
            % WQM provides chlorophyll in ug/L; we need it in mg/m^3,
            % hopefully it is equivalent.
            
        case 'PAR'
            % don't seem to know what to do with PAR yet
            continue;

    end
        
    % dimensions definition must stay in this order : T, Z, Y, X, others;
    % to be CF compliant
    sample_data.variables{end+1}.dimensions           = 1;
    sample_data.variables{end}.name                   = name;
    sample_data.variables{end}.typeCastFunc           = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{end}.name, 'type')));
    sample_data.variables{end}.data                   = sample_data.variables{end}.typeCastFunc(data);
    sample_data.variables{end}.coordinates            = 'TIME LATITUDE LONGITUDE NOMINAL_DEPTH';
    sample_data.variables{end}.comment                = comment;
    
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
          sample_data.variables{end}.comment                = comment;
          sample_data.variables{end}.name                   = name;
          sample_data.variables{end}.typeCastFunc           = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{end}.name, 'type')));
          sample_data.variables{end}.data                   = sample_data.variables{end}.typeCastFunc(data);
          sample_data.variables{end}.coordinates            = 'TIME LATITUDE LONGITUDE NOMINAL_DEPTH';
      end
  end
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
    if strcmp(params{k}{1}, field)
      entry = params{k};
      break;
    end
  end
  
  if isempty(entry), return; end

  name    = entry{2}{1};
  comment = entry{2}{2};
end

function WQM=readWQMinternal(flnm)
% function WQM=readWQM(flnm)
% 
% data sequence in raw file appears to be an attempt to wake up the
% instrument
% code 100 twice  - I suspect this contains voltage info and other
% machine status data which I can't parse at this point
% a burst of data with line code 4 with usually only CTP and O2 (other
% fields are zero)
% a line of code 5 followed by code 100 then a burst of code 5 (more data now in
% other fields - still some zeros);
% a line of code 6 followed by code 100 then a burst of code 6
% finish up with one code 100 (or sometimes two code 130s and then a 100 -
% maybe some lag between response after code 6 burst);
% .DAT file produced by WQM software 
%
% Charles James May 2010
% note:
% This function also requires the Gibbs-SeaWater toolbox (TEOS-10)
% gsw_C3515:        Returns conductivity at S=35 psu , T=15 C [ITPS 68] and P=0 db)
% gsw_SP_from_R:    Calculates Salinity from conductivity ratio. UNESCO 1983 polynomial


fid=fopen(flnm,'r');
str{1}='';
iline=0;

% read header information
while ~strcmp(str{1},'<EOH>');
    str=textscan(fid,'%s',1,'delimiter','\n');
    iline=iline+1;
    headerLine(iline)=str{1};
end

wqmSNExpr    = ['^WQM SN: +' '(\S+)$'];
ctdSNExpr    = ['^CTDO SN: +' '(\S+)$'];
doSNExpr     = 'DOSN=(\S+)';
opticsSNExpr = ['Optics SN: +' '(\S+)'];

exprs = {wqmSNExpr ctdSNExpr doSNExpr opticsSNExpr};

for l = 1:length(headerLine)
    
    % try each of the expressions
    for m = 1:length(exprs)
        
        % until one of them matches
        tkns = regexp(headerLine{l}, exprs{m}, 'tokens');
        if ~isempty(tkns)
            
            % yes, ugly, but easiest way to figure out which regex we're on
            switch m
                
                % wqm
                case 1
                    WQM.SN          = tkns{1}{1};
                    
                % ctd
                case 2
                    WQM.CTDO_SN     = tkns{1}{1};
                    
                % do
                case 3
                    WQM.DO_SN       = tkns{1}{1};
                    
                    if strcmpi(WQM.DO_SN, '0'), WQM.DO_SN = WQM.CTDO_SN; end
                    
                % optics
                case 4
                    WQM.Optics_SN   = tkns{1}{1};
            end
            break;
        end
    end
end

% read data information
% sometimes, when file is corrupted, all variables are not output.
a = [];
while ~feof(fid)
    if isempty(a)
        a = textscan(fid, '%f,%f,%f,%f,%s', 'delimiter', '\n');
        
        % get rid of any uncomplete line
        lenA1 = length(a{1});
        lenA2 = length(a{2});
        lenA3 = length(a{3});
        lenA4 = length(a{4});
        lenA5 = length(a{5});
        if lenA5 < lenA4
            a{4}(end) = [];
        end
        if lenA5 < lenA3
            a{3}(end) = [];
        end
        if lenA5 < lenA2
            a{2}(end) = [];
        end
        if lenA5 < lenA1
            a{1}(end) = [];
        end
    else
        % continue parsing file
        b = textscan(fid, '%f,%f,%f,%f,%s', 'delimiter', '\n');
        
        if isempty(b{1})
            % let's skip this line or it will get stuck in it
            [~] = fgetl(fid);
        end
        
        % get rid of any uncomplete line
        lenB1 = length(b{1});
        lenB2 = length(b{2});
        lenB3 = length(b{3});
        lenB4 = length(b{4});
        lenB5 = length(b{5});
        if lenB5 < lenB4
            b{4}(end) = [];
        end
        if lenB5 < lenB3
            b{3}(end) = [];
        end
        if lenB5 < lenB2
            b{2}(end) = [];
        end
        if lenB5 < lenB1
            b{1}(end) = [];
        end
        
        % append to existing structure
        if ~isempty(b{1})
            a{1} = [a{1}; b{1}];
            a{2} = [a{2}; b{2}];
            a{3} = [a{3}; b{3}];
            a{4} = [a{4}; b{4}];
            a{5} = [a{5}; b{5}];
        end
        clear b;
    end
end

fclose(fid);

% Instrument Serial Number to start each line
WQM.instrument='Wetlabs WQM';

WQM.samp_units='datenumber';
WQM.varlabel={'conductivity','temperature','pressure','salinity','oxygen','U_Cal_CHL','backscatterance'};
WQM.varunits={'S/m','C','dbar','PSU','ml/l','ug/l','NTU'};


% the next number is one of 7 codes

% These clearly contain physical data
% 4 - data fields
% 5 - data fields
% 6 - data fields

% Not clear what these lines contain, maybe status and voltage stuff
% 100 - 16 fields
% 110 - 13 fields, perhaps an aborted sample? - only found it at end of file
% 120 - 3 fields, pretty rare right near end as well
% 130 - 1 field Unable to Wake CTD

% we will only retain data with line code 6
dcode = a{2};
igood = dcode == 6;
clear dcode;

data = a{5}(igood);
date = a{3}(igood);
time = a{4}(igood);
clear a igood;

% sometimes, when file is corrupted, a dot "." or coma "," is inserted in
% the variable value. As is it impossible to know where will occure this
% error, the simplest thing to do is to remove the whole corresponding
% lines
iGoodDataLine = cellfun('isempty', strfind(data, '.,'));
iGoodDataLine = iGoodDataLine & cellfun('isempty', strfind(data, ',,'));
iGoodDataLine = iGoodDataLine & cellfun('isempty', strfind(data, ',.'));
iGoodDataLine = iGoodDataLine & cellfun('isempty', strfind(data, '..'));
data = data(iGoodDataLine);
date = date(iGoodDataLine);
time = time(iGoodDataLine);
clear iGoodDataLine;

% how many variables (don't know if this changes if PAR sensor is on so
% check anyway)
nvars = length(strfind(data{1}, ',')) + 1;

% check that every line has only nvars, otherwise kick it out
k = strfind(data, ',');
iGoodLength = (cellfun('length', k) == nvars-1);
clear k;
data = data(iGoodLength);
date = date(iGoodLength);
time = time(iGoodLength);
clear iGoodLength;

month = fix(date/10000);
date = date - month*10000;
day = fix(date/100);
year = 2000 + date - day*100;
clear date;

hour = fix(time/10000);
time = time - hour*10000;
minute = fix(time/100);
second = time - minute*100;
clear time;

WQM.datenumber = datenum(year, month, day, hour, minute, second);
clear year month day hour minute second;

% using sscanf which reads columnwise so put array on side
C = char(data);
clear data;
C = C';

% one weird thing, sscanf will fail if the last column has anything but a
% space in it. So sort of a kludge, but by far the fastest fix I know of.
s = size(C);
C(s(1)+1,:) = ' ';

fmt = '%f';
for i=1:nvars-1
    fmt = strcat(fmt, ',%f');
end

[A, ~, errmsg] = sscanf(C, fmt, [nvars s(2)]);

% sometimes, when file is corrupted, a value can contain several dots "." 
% in the same variable value, the whole line cannot be read properly and 
% sscanf stops at this point.
if ~isempty(errmsg)
    % let's replace any erroneous value by NaN
    A(:, end) = NaN;
end

lenC = size(C, 2);
nextPosInC = size(A, 2) + 1;
while ~isempty(errmsg) && nextPosInC <= lenC
    % go to next line
    [B, ~, errmsg] = sscanf(C(:, nextPosInC:end), fmt, [nvars s(2)-size(A, 2)]);
    if ~isempty(errmsg) && ~isempty(B)
        % let's replace any erroneous value by NaN
        B(:, end) = NaN;
    end

    % Let's fill any undocumented line by NaN
    while size(B, 1) < 6
        B = [B; nan(size(B, 2), 1)];
    end
    
    % append to existing matrix
    A = [A, B];
    
    % increment next position in C to continue reading
    nextPosInC = size(A, 2) + 1;
end
% A is one long vector with nvars*samples elements
% reshape it to make it easier to extract data
A = A';

% C,T,P are in stored in engineering units
WQM.conductivity = A(:,1);    % S/m

% temperature and pressure in C and dbar
WQM.temperature = A(:,2);
WQM.pressure = A(:,3);

% compute conductivity ratio to use seawater salinity algorithm
% Wetlabs conductivity is in S/m and gsw_C3515 in mS/cm
crat = 10*WQM.conductivity./gsw_C3515;

WQM.salinity = gsw_SP_from_R(crat, WQM.temperature, WQM.pressure);

% find sensor coefficients

% Oxygen
%
Soc = textscan(headerLine{~cellfun('isempty',strfind(headerLine,'Soc'))},'%4c%f');
FOffset = textscan(headerLine{~cellfun('isempty',strfind(headerLine,'FOffset'))},'%8c%f');
A52 = textscan(headerLine{~cellfun('isempty',strfind(headerLine,'A52'))},'%4c%f');
B52 = textscan(headerLine{~cellfun('isempty',strfind(headerLine,'B52'))},'%4c%f');
C52 = textscan(headerLine{~cellfun('isempty',strfind(headerLine,'C52'))},'%4c%f');
E52 = textscan(headerLine{~cellfun('isempty',strfind(headerLine,'E52'))},'%4c%f');

O2.Soc = Soc{2};
O2.FOffset = FOffset{2};
O2.A = A52{2};
O2.B = B52{2};
O2.C = C52{2};
O2.E = E52{2};

oxygen = A(:,4);

WQM.oxygen = O2cal(oxygen, O2, WQM);

% FLNTU Sensor
chl = textscan(headerLine{~cellfun('isempty',strfind(headerLine,'UserCHL'))},'%8c%f%f\n');
ntu = textscan(headerLine{~cellfun('isempty',strfind(headerLine,'NTU'))},'%4c%f%f\n');
CHL.scale = chl{2};
CHL.offset = chl{3};
NTU.scale = ntu{2};
NTU.offset = ntu{3};

fluor = A(:,5);
turb = A(:,6);
WQM.U_Cal_CHL = FLNTUcal(fluor, CHL);
WQM.backscatterance = FLNTUcal(turb, NTU);

% Store calibration coefficients in meta data
Cal.O2 = O2;
Cal.CHL = CHL;
Cal.NTU = NTU;

% Optional PAR sensor
isPar = ~cellfun('isempty',strfind(headerLine,'PAR='));
if any(isPar)
    par=textscan(headerLine{isPar},'%4c%f%f%f\n');
    PAR.Im=par{2};
    PAR.a0=par{3};
    PAR.a1=par{4};
    %par=cellfun(@(x) x(7),D);
    par=A(:,7);
    WQM.PAR=PARcal(par,PAR);
    % nvars = 8 because of salinity (derived)
    WQM.varlabel{nvars+1}='PAR';
    WQM.varunits{nvars+1}='umol/m^2/s';
    Cal.PAR=PAR;
end

WQM.Calibration = Cal;

% get interval and duration from header file
interval = ~cellfun('isempty', strfind(headerLine, 'Sample Interval Seconds:'));
if any (interval)
    interval = textscan(headerLine{interval}, '%24c%f');
    interval = interval{2};
else
    interval = NaN;
end
duration = ~cellfun('isempty', strfind(headerLine, 'Sample Seconds:'));
if any (duration)
    duration = textscan(headerLine{duration}, '%15c%f');
    duration = duration{2};
else
    duration = NaN;
end
WQM.interval = interval;
WQM.duration = duration;
% WQM record samples at 1 Hz
WQM.frequency = 1;
end


function O2=O2cal(freq,Cal,CTD)
% WQM uses SBE-43F
% Oxygen = Soc * (output + Foffset)*(1.0+A*T+B*T^2+C*T^3)*Oxsat(T,S)*exp(E*P/K), 
% where output=SBE-43F oxygen sensor output frequency in Hz, 
% K=T[degK], OxSat()=oxygen saturation[ml/l] function of Weiss

Soc=Cal.Soc;
FOffset=Cal.FOffset;
A=Cal.A;
B=Cal.B;
C=Cal.C;
E=Cal.E;
P=CTD.pressure;
S=CTD.salinity;
T=CTD.temperature;

P1=Soc*(freq+FOffset);
P2=(1+A.*T+B.*T.^2+C.*T.^3);
K=T+273.15;
P3=exp(E.*P./K);
oxsat=sw_satO2(S,T); % cannot use the GSW SeaWater library TEOS-10 since there is not any function provided for oxygen.

O2=P1.*P2.*oxsat.*P3;
% is 30000 a bad flag can't tell but O2 is bad if freq sticks
O2(freq==30000)=NaN;
end

function PAR=PARcal(freq,Cal)
% from the Satlantic PAR sensor manual (don't know if this is linear or log
% par)
Im=Cal.Im;
a0=Cal.a0;
a1=Cal.a1;
% linear
%PAR=Im.a1.*(freq-a0);

% or log
PAR=Im.*10.^((freq-a0)./a1);

end

function var=FLNTUcal(counts,Cal)
scale=Cal.scale;
offset=Cal.offset;

var=scale.*(counts-offset);

end