function sample_data = readWQMraw( filename )
%readWQMraw parses a .RAW file retrieved from a Wetlabs WQM instrument.
%
% This function is able to parse raw data retrieved from a Wetlabs WQM CTD/ECO 
% instrument. 
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
  % ensure that there is exactly one argument
  error(nargchk(1, 1, nargin));
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
  params{end+1} = {'conductivity',    {'CNDC', ''}};
  params{end+1} = {'temperature',     {'TEMP', ''}};
  params{end+1} = {'pressure',        {'PRES_REL', ''}};
  params{end+1} = {'salinity',        {'PSAL', ''}};
  params{end+1} = {'DO(mg/l)',        {'DOXY', ''}};
  params{end+1} = {'DO(mmol/m^3)',    {'DOX1', ''}};
  params{end+1} = {'oxygen',          {'DOX2', ''}};
  params{end+1} = {'fluorescence',    {'FLU2', ''}};
  params{end+1} = {'F-Cal-CHL(ug/l)', {'CHLF', 'Factory coefficient'}};
  params{end+1} = {'U-Cal-CHL(ug/l)', {'CHLU', 'User coefficient'}};
  params{end+1} = {'backscatterance', {'TURB', ''}};
  % CJ where is PAR?? 
 % params{end+1} = {'PAR',             {'PAR', ''}};
  
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
    % cj use my routine to access raw file
    wqmdata=readWQMinternal(filename);

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
  sample_data.meta.instrument_serial_no = wqmdata.SN;
  sample_data.meta.instrument_sample_interval = wqmdata.interval;
  
  % convert and save the time data
  time = wqmdata.datenumber;
  
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
  
  % dimensions definition must stay in this order : T, Z, Y, X, others;
  % to be CF compliant
  sample_data.dimensions{1}.name = 'TIME';
  sample_data.dimensions{1}.data = time;
  sample_data.dimensions{2}.name = 'LATITUDE';
  sample_data.dimensions{2}.data = NaN;
  sample_data.dimensions{3}.name = 'LONGITUDE';
  sample_data.dimensions{3}.data = NaN;

  % create a variables struct in sample_data for each field in the file
  % start index at 4 to skip serial, date and time
  
    varlabel=wqmdata.varlabel;
  for k = 1:length(varlabel)

    [name comment] = getParamDetails(varlabel{k}, params);  

    data = wqmdata.(varlabel{k});

    % some fields are not in IMOS uom - scale them so that they are
    switch name
        
        % WQM provides conductivity in mS/m; we need it in S/m.
        case 'conductivity'
            data = data / 1000.0;
        
        % convert dissolved oxygen in mg/L to kg/m^3.
        case 'DO(mg/l)'
            data = data / 1000.0;
        
        % convert dissolved oxygen in mmol/m^3 to mol/m^3
        case 'DO(mmol/m^3)'
            data = data / 1000.0;
            
        % convert dissolved oxygen in ml/l to mol/kg
        case 'oxygen'
            
            % to perform this conversion, we need to calculate the
            % density of sea water; for this, we need temperature,
            % salinity, and pressure data to be present
            temp = wqmdata.temperature;
            pres = wqmdata.pressure;
            psal = wqmdata.salinity;
            
            % calculate density from salinity, temperature and pressure
            dens = sw_dens(psal, temp, pres);
            
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
            
        % WQM provides chlorophyll in ug/L; we need it in mg/m^3, 
        % hopefully it is equivalent.
            
        case 'PAR'
            % don't seem to know what to do with PAR yet
            continue;
            
    end
        
    sample_data.variables{k}.dimensions = [1 2 3];
    sample_data.variables{k}.comment    = comment;
    sample_data.variables{k}.name       = name;
    sample_data.variables{k}.data       = data;
    
    % WQM uses SeaBird pressure sensor
    if strncmp('PRES_REL', sample_data.variables{k}.name, 8)
        % let's document the constant pressure atmosphere offset previously 
        % applied by SeaBird software on the absolute presure measurement
        sample_data.variables{k}.applied_offset = -14.7*0.689476;
    end
  end
  
  % remove empty entries (could occur if DO(ml/l) data is 
  % present, but temp/pressure/salinity data is not)
  sample_data.variables(cellfun(@isempty, sample_data.variables)) = [];
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
% This function also requires the CSIRO Seawater toolbox for CTP
% to salinity conversion
% sw_c3514:   Returns conductivity at S=35 psu , T=15 C [ITPS 68] and P=0 db)
% sw_salt:    Calculates Salinity from conductivity ratio. UNESCO 1983 polynomial.


fid=fopen(flnm,'r');
str{1}='';
iline=0;

% read header information
while ~strcmp(str{1},'<EOH>');
str=textscan(fid,'%s',1,'delimiter','\n');
iline=iline+1;
header(iline)=str{1};
end
% 




a=textscan(fid,'%f,%f,%f,%f,%s','delimiter','\n');
fclose(fid);


% Instrument Serial Number to start each line
WQM.instrument='Wetlabs WQM';
WQM.SN=num2str(a{1}(1));

WQM.samp_units='datenumber';
WQM.varlabel={'conductivity','temperature','pressure','salinity','oxygen','fluorescence','backscatterance'};
WQM.varunits={'mohm/cm','C','dbar','PSU','ml/l','ug/l','NTU'};


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
dcode=a{2};
igood=dcode==6;


data=a{5}(igood);

% how many variables (don't know if this changes if PAR sensor is on so
% check anyway)
nvars=length(strfind(data{1},','))+1;

% check that every line has only nvars, otherwise kick it out
k = strfind(data, ',');
iGoodLength = (cellfun('length', k) == nvars-1);
data = data(iGoodLength);

% using sscanf which reads columnwise so put array on side
C=char(data)';

% one weird thing, sscanf will fail if the last column has anything but a
% space in it. So sort of a kludge, but by far the fastest fix I know of.
s=size(C);
C(s(1)+1,:)=' ';


fmt='%f';
for i=1:nvars-1
fmt=strcat(fmt,',%f');
end

[A, ~, errmsg]=sscanf(C,fmt,[nvars s(2)]);

if ~isempty(errmsg)
   error(errmsg); 
end
% A is one long vector with nvars*samples elements
% reshape it to make it easier to extract data
A=A';

% C,T,P are in stored in engineering units

% Wetlabs stores conductivity in ohm/M convert to mohms/cm
WQM.conductivity=10*A(:,1);

% temperature and pressure in C and dbar
WQM.temperature=A(:,2);
WQM.pressure=A(:,3);

% compute conductivity ratio to use seawater salinity algorithm
crat=WQM.conductivity./sw_c3515;

WQM.salinity=sw_salt(crat,WQM.temperature,WQM.pressure);



% find sensor coefficients

% Oxygen
%
Soc=textscan(header{~cellfun('isempty',strfind(header,'Soc'))},'%4c%f');
FOffset=textscan(header{~cellfun('isempty',strfind(header,'FOffset'))},'%8c%f');
A52=textscan(header{~cellfun('isempty',strfind(header,'A52'))},'%4c%f');
B52=textscan(header{~cellfun('isempty',strfind(header,'B52'))},'%4c%f');
C52=textscan(header{~cellfun('isempty',strfind(header,'C52'))},'%4c%f');
E52=textscan(header{~cellfun('isempty',strfind(header,'E52'))},'%4c%f');

O2.Soc=Soc{2};
O2.FOffset=FOffset{2};
O2.A=A52{2};
O2.B=B52{2};
O2.C=C52{2};
O2.E=E52{2};

oxygen=A(:,4);

WQM.oxygen=O2cal(oxygen,O2,WQM);


% FLNTU Sensor
chl=textscan(header{~cellfun('isempty',strfind(header,'UserCHL'))},'%8c%f%f\n');
ntu=textscan(header{~cellfun('isempty',strfind(header,'NTU'))},'%4c%f%f\n');
CHL.scale=chl{2};
CHL.offset=chl{3};
NTU.scale=ntu{2};
NTU.offset=ntu{3};

fluor=A(:,5);
turb=A(:,6);
WQM.fluorescence=FLNTUcal(fluor,CHL);
WQM.backscatterance=FLNTUcal(turb,NTU);

% Store calibration coefficients in meta data
Cal.O2=O2;
Cal.CHL=CHL;
Cal.NTU=NTU;

% Optional PAR sensor
isPar = ~cellfun('isempty',strfind(header,'PAR='));
if any(isPar)
    par=textscan(header{isPar},'%4c%f%f%f\n');
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

WQM.Calibration=Cal;


date=a{3}(igood);
date=date(iGoodLength);
time=a{4}(igood);
time=time(iGoodLength);

month=fix(date/10000);
date=date-month*10000;
day=fix(date/100);
year=2000+date-day*100;

hour=fix(time/10000);
time=time-hour*10000;
minute=fix(time/100);
second=time-minute*100;

WQM.datenumber=datenum(year,month,day,hour,minute,second);

% get interval and duration from header file
interval=textscan(header{~cellfun('isempty',strfind(header,'Sample Interval Seconds:'))},'%24c%f');
duration=textscan(header{~cellfun('isempty',strfind(header,'Sample Seconds:'))},'%15c%f');
WQM.interval=interval{2};
WQM.duration=duration{2};
% WQM record samples at 1 Hz
WQM.frequency=1;
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
oxsat=sw_satO2(S,T);

O2=P1.*P2.*oxsat.*P3;
% is 30000 a bad flag can't tell but O2 is bad if freq sticks
O2(freq==30000)=0;
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