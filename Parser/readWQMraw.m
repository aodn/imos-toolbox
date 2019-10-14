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
%                   Dissolved Oxygen  ('DOXY'): mg/l
%                   Dissolved Oxygen  ('DOX1'): mmol/m^3
%                   Dissolved Oxygen  ('DOX'): ml/l
%                   fluorescence      ('CPHL','CPHL_2','CPHL_3',...): mg/m^3
%                   Chlorophyll       ('CPHL','CPHL_2','CPHL_3',...): mg/m^3   (user coefficient)
%                   Chlorophyll       ('CPHL','CPHL_2','CPHL_3',...): mg/m^3   (factory coefficient)
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
% ensure that there are exactly two arguments
narginchk(2, 2);
if ~ischar(filename), error('filename must contain a string'); end
params = load_params();
wqmdata = load_wqm(filename);
sample_data = load_sample_data(filename,mode,params,wqmdata);

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

function WQM=readWQMinternal(flnm,headerLine)
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

wqmSNExpr     = '^WQM SN:\s+(\S+)$';
ctdSNExpr     = '^CTDO SN:\s+(\S+)$';
doSNExpr      = '^DOSN=(\S+)';
opticsSNExpr  = '^Optics SN:\s+(\S+)';
doSNExpr2     = '^IDO SN:\s+(\S+)';
opticsSNExpr2 = '^FL_NTU SN:\s+(\S+)';
opticsSNExpr3 = '^ECO SN:\s+(\S+)';
parSN         = '^PAR SN=(\S+)';

exprs = {wqmSNExpr ctdSNExpr doSNExpr opticsSNExpr doSNExpr2 opticsSNExpr2 opticsSNExpr3 parSN};

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

                    % do v2
                case 5
                    WQM.DO_SN       = tkns{1}{1};
                    if strcmpi(WQM.DO_SN, '0'), WQM.DO_SN = WQM.CTDO_SN; end

                      % optics v2
                case 6
                    WQM.Optics_SN   = tkns{1}{1};

                    % optics v3
                case 7
                    WQM.Optics_SN   = tkns{1}{1};

                    % par
                case 8
                    WQM.PAR_SN   = tkns{1}{1};
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

% Find column index for various variable
% Assume data starts after date/time section. Some example strings are
% File Format: SN,State,Date,Time,Cond,Temp,Pres,RawDO,RawCHL,RawTurb,Volts
% File Format: SN,State,Date,Time,Cond(S/m),Temp(C),Pres(dbar),RawDO(Hz),RawCHL(cts),RawTurb(cts),Volts
% File Format: SN,State,Date,Time,Cond(S/m),Temp(C),Pres(dbar),RawDO(Hz),Pumped,CHLa(Counts),Turbidity(Counts),Volts
% File Format: SN,State,Date,Time,Cond(S/m),Temp(C),Pres(dbar),RawDO(Hz),Pumped,CHLA(COUNTS),TURBIDITY(COUNTS),Volts
rExp = '^File Format:\s+(\S+)';
indFileFormat = find(~cellfun(@isempty, regexpi(headerLine, rExp)));
varmap = load_varmap(indFileFormat,rExp,headerLine);

% a standard data line looks like
% SN,State,DATE,TIME,data
%
% Currently known States are
%
% These clearly contain physical data
% 4 - SN,4,DATE,TIME,comma seperated data fields
% 5 - SN,5,DATE,TIME,comma seperated data fields
% 6 - SN,6,DATE,TIME,comma seperated data fields
%
% Not clear what these lines contain, maybe status and voltage stuff
% 100 - 16 fields
% 110 - 13 fields, perhaps an aborted sample? - only found it at end of file
% 120 - 3 fields, pretty rare right near end as well
% 130 - SN,130,DATE,TIME,status message
% example status messages
%   'Low Voltage - BLIS Pumps Aborted'
%   'EDP Bio-Wiper Might Not have Closed'
% 140 - SN,140,DATE,TIME,status message
% example status messages
%   'Unable to Wake CTD'
%   'CTD Start Time is SLOW at 8.087 Seconds'
%   'Sample Mode:  In Air - Not Pumped: 0.00007 S/M < 0.00150 C90-Limit'
%   'Sample Mode:  Insitu - Pumped: 5.52542 S/M > 0.00150 C90-Limit'
%   'Stray CTD Data was removed'
% 200 - SN,200,DATE,TIME,comma seperated data fields
% 210 - SN,210,DATE,TIME,tab seperated data fields
% 211 - SN,211,DATE,TIME, empty?
% 230 - SN,230,DATE,TIME,comma seperated data fields

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

% try to handle a very badly behaved WQM which didn't record
% some of its primary variable, has flow on effects for calculation of
% other variables
[WQM,hasConductivity] = process_missing(A,varmap,WQM,'Cond','conductivity'); % S/m
[WQM,hasTemperature] = process_missing(A,varmap,WQM,'Temp','temperature'); % deg
[WQM,hasPressure] = process_missing(A,varmap,WQM,'Pres','pressure'); %dbar
hasSalinity = hasConductivity && hasTemperature && hasPressure;

% compute conductivity ratio to use seawater salinity algorithm
% Wetlabs conductivity is in S/m and gsw_C3515 in mS/cm
if hasSalinity
    crat = 10*WQM.conductivity./gsw_C3515;
    WQM.salinity = gsw_SP_from_R(crat, WQM.temperature, WQM.pressure);
else
    [WQM.varlabel,WQM.varunits] = remove_missing(WQM.varlabel,WQM.varunits,'salinity');
end

% find sensor coefficients
if hasSalinity
    O2 = load_oxygen_coefs(headerLine);
    oxygen = A(:,varmap('DO'));
    WQM.oxygen = O2cal(oxygen, O2, WQM);
    % Store calibration coefficients in meta data
    Cal.O2 = O2;
else
    [WQM.varlabel,WQM.varunits] = remove_missing(WQM.varlabel,WQM.varunits,'oxygen');
end

% FLNTU Sensor

CHL = load_chl(headerLine);
NTU = load_ntu(headerLine);

fluor = A(:,varmap('Chl'));
turb = A(:,varmap('Turb'));
WQM.U_Cal_CHL = FLNTUcal(fluor, CHL);
WQM.backscatterance = FLNTUcal(turb, NTU);

% Store calibration coefficients in meta data
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
    par=A(:,varmap('Par'));
    WQM.PAR=PARcal(par,PAR);
    WQM.varlabel{end+1}='PAR';
    WQM.varunits{end+1}='umol/m^2/s';
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
oxsat=sw_satO2(S,T); % SeaBird normally uses function of Weiss to output DOX (ml/l) in .dat files.

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

function [map] = load_varmap(indFileFormat,rExp,headerLine);
  %load variable map index
  map = containers.Map;
  if isempty(indFileFormat)
        % very old file, have to assume default ordering
        map('Cond') = 1;
        map('Temp') = 2;
        map('Pres') = 3;
        map('DO') = 4;
        map('Chl') = 5;
        map('Turb') = 6;
        map('Par') = 7;
    else
        % newer file, try and parse various variable names
        tkns = regexp(headerLine{indFileFormat}, rExp, 'tokens');
        formatStr = tkns{1}{1};
        formatCellStr = textscan(formatStr, '%s', 'delimiter', ',');
        formatCellStr = formatCellStr{1};

        rExp = 'Cond';
        map('Cond') = find(~cellfun(@isempty, regexpi(formatCellStr, rExp))) - 4;
        rExp = 'Temp';
        map('Temp') = find(~cellfun(@isempty, regexpi(formatCellStr, rExp))) - 4;
        rExp = 'Pres';
        map('Pres') = find(~cellfun(@isempty, regexpi(formatCellStr, rExp))) - 4;
        rExp = 'RawDO';
        map('DO') = find(~cellfun(@isempty, regexpi(formatCellStr, rExp))) - 4;
        rExp = 'CHL'; % RawCHL | CHLa | CHLA
        map('Chl') = find(~cellfun(@isempty, regexpi(formatCellStr, rExp))) - 4;
        rExp = 'TURB'; % RawTurb | Turbidity | TURBIDITY
        map('Turb') = find(~cellfun(@isempty, regexpi(formatCellStr, rExp))) - 4;
        rExp = 'PAR'; % RawPAR | PAR
        map('Par') = find(~cellfun(@isempty, regexpi(formatCellStr, rExp))) - 4;
    end

  end

function [params] = load_params();
  %
  % Load default parameters for WQM
  %

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
  params{end+1} = {'DO(mg/l)',        {'DOXY', ''}};
  params{end+1} = {'DO(mmol/m^3)',    {'DOX1', ''}}; % mmol/m3 <=> umol/l
  params{end+1} = {'oxygen',          {'DOX', ''}};
  params{end+1} = {'fluorescence',    {'FLU2', ''}};
  params{end + 1} = {'F_Cal_CHL', {'CPHL', getCPHLcomment('factory', '470nm', '695nm')}};
  params{end + 1} = {'U_Cal_CHL', {'CPHL', getCPHLcomment('user', '470nm', '685nm')}};
  params{end+1} = {'backscatterance', {'TURB', ''}};
  params{end+1} = {'PAR',             {'PAR', ''}};

end

function [wqmdata] = load_wqm(filename);
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

end

function [sample_data] = load_sample_data(filename,mode,params,wqmdata);
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

  tnCHL = sum(contains(varlabel, 'CHL')) - sum(contains(varlabel, 'RawCHL'));
  nCHL = 0;

  for k = 1:length(varlabel)

    [name, comment] = getParamDetails(varlabel{k}, params);
    need_chla_numbered = tnCHL > 1 && strcmp(name, 'CPHL');

    if need_chla_numbered
      nCHL = nCHL + 1;

      if nCHL > 1
        name = [name '_' num2str(nCHL)];
      end

    end

    data = wqmdata.(varlabel{k});

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
end

function [wqm,has_var] = process_missing(A,varmap,wqm,vartype,varname);
   var = A(:,varmap(vartype));
   has_var = ~isempty(var);
  if has_var
    wqm.(varname) = var;
  else
    [wqm.varlabel,wqm.varunits] = remove_missing(wqm.varlabel,wqm.varunits,varname);
  end
end

function [newlabel,newunits] = remove_missing(label,units, varname);
  ilabel = strcmp(label, varname);
  newlabel = label(~ilabel);
  newunits = units(~ilabel);
end


function [O2] = load_oxygen_coefs(headerLine);
  % Oxygen
  %
  try
      Soc = textscan(headerLine{~cellfun('isempty',strfind(headerLine,'Soc='))},'%4c%f');
      FOffset = textscan(headerLine{~cellfun('isempty',strfind(headerLine,'FOffset='))},'%8c%f');
      Acal = textscan(headerLine{~cellfun('isempty',strfind(headerLine,'A52='))},'%4c%f');
      Bcal = textscan(headerLine{~cellfun('isempty',strfind(headerLine,'B52='))},'%4c%f');
      Ccal = textscan(headerLine{~cellfun('isempty',strfind(headerLine,'C52='))},'%4c%f');
      Ecal = textscan(headerLine{~cellfun('isempty',strfind(headerLine,'E52='))},'%4c%f');
  catch
      Soc = textscan(headerLine{~cellfun('isempty',strfind(headerLine,'IDO43 Soc='))},'%10c%f');
      FOffset = textscan(headerLine{~cellfun('isempty',strfind(headerLine,'IDO43 FOffset='))},'%14c%f');
      Acal = textscan(headerLine{~cellfun('isempty',strfind(headerLine,'IDO43 A='))},'%8c%f');
      Bcal = textscan(headerLine{~cellfun('isempty',strfind(headerLine,'IDO43 B='))},'%8c%f');
      Ccal = textscan(headerLine{~cellfun('isempty',strfind(headerLine,'IDO43 C='))},'%8c%f');
      Ecal = textscan(headerLine{~cellfun('isempty',strfind(headerLine,'IDO43 E='))},'%8c%f');
  end

  O2.Soc = Soc{2};
  O2.FOffset = FOffset{2};
  O2.A = Acal{2};
  O2.B = Bcal{2};
  O2.C = Ccal{2};
  O2.E = Ecal{2};
end

function [CHL] = load_chl(headerLine);
  try
      % example text in older files
      % FactoryCHL=0.012  60      Scale and Offset
      % UserCHL=0.012     60      Scale and Offset
      chl = textscan(headerLine{~cellfun('isempty',strfind(headerLine,'UserCHL='))},'%8c%f%f\n');
      CHL.scale = chl{2};
      CHL.offset = chl{3};
  catch
      % example text in newer raw files
      % ECO Signal Count:  2
      % ECO Signal 1 Name:  CHLA
      % ECO Signal 1 Raw Units:  COUNTS
      % ECO Signal 1 Engr Units:  UG/L
      % ECO Signal 1 Type:  1  Std Scale'n'Offset
      % ECO Signal 1 Cal Coef:  0.011200  49.000000  0.000000  0.000000
      rExp = 'ECO Signal Count:\W+(\d+)';
      indNSignals = find(~cellfun(@isempty, regexp(headerLine, rExp)));
      tkns = regexp(headerLine{indNSignals}, rExp, 'tokens');

      % test for CHLA (or CHLa)
      rExp = 'ECO Signal (\d) Name:\W+CHLA';
      indCHLA = find(~cellfun(@isempty, regexpi(headerLine, rExp)));
      if ~isempty(indCHLA)
          tkns = regexpi(headerLine{indCHLA}, rExp, 'tokens');
          nSignal = str2num(tkns{1}{1});
          signalStr =  ['ECO Signal ' num2str(nSignal)];

          str = headerLine{~cellfun('isempty',strfind(headerLine,[signalStr ' Raw Units:']))};
          rawUnits = regexp(str,':','split');
          rawUnits = strtrim(rawUnits{2});

          str = headerLine{~cellfun('isempty',strfind(headerLine,[signalStr ' Engr Units:']))};
          engrUnits = regexp(str,':','split');
          engrUnits = strtrim(engrUnits{2});

          str = headerLine{~cellfun('isempty',strfind(headerLine,[signalStr ' Type:  1']))};
          typeStr = strtrim(regexp(str,':','split'));
          typeStr = typeStr{2}(1);
          if str2num(typeStr) ~= 1
              error('readWQMraw only handles type 1 unit scaling');
          end

          str = headerLine{~cellfun('isempty',strfind(headerLine,[signalStr ' Cal Coef:']))};
          calStr = strtrim(regexp(str,':','split'));
          calCoeffs = str2num(calStr{2});
          CHL.scale = calCoeffs(1);
          CHL.offset = calCoeffs(2);
      end
  end
end

function [NTU] = load_ntu(headerLine);
  try
      % NTU=0.006 58      Scale and Offset
      ntu = textscan(headerLine{~cellfun('isempty',strfind(headerLine,'NTU='))},'%4c%f%f\n');
      NTU.scale = ntu{2};
      NTU.offset = ntu{3};
  catch
      % ECO Signal 2 Name:  TURBIDITY
      % ECO Signal 2 Raw Units:  COUNTS
      % ECO Signal 2 Engr Units:  NTU
      % ECO Signal 2 Type:  1  Std Scale'n'Offset
      % ECO Signal 2 Cal Coef:  0.006200  50.000000  0.000000  0.000000

      % test for TURBIDITY (or Turbidity)
      rExp = 'ECO Signal (\d) Name:\W+TURBIDITY';
      indTURB = find(~cellfun(@isempty, regexpi(headerLine, rExp)));
      if ~isempty(indTURB)
          tkns = regexpi(headerLine{indTURB}, rExp, 'tokens');
          nSignal = str2num(tkns{1}{1});
          signalStr =  ['ECO Signal ' num2str(nSignal)];

          str = headerLine{~cellfun('isempty',strfind(headerLine,[signalStr ' Raw Units:']))};
          rawUnits = regexp(str,':','split');
          rawUnits = strtrim(rawUnits{2});

          str = headerLine{~cellfun('isempty',strfind(headerLine,[signalStr ' Engr Units:']))};
          engrUnits = regexp(str,':','split');
          engrUnits = strtrim(engrUnits{2});

          str = headerLine{~cellfun('isempty',strfind(headerLine,[signalStr ' Type:  1']))};
          typeStr = strtrim(regexp(str,':','split'));
          typeStr = typeStr{2}(1);
          if str2num(typeStr) ~= 1
              error('readWQMraw only handles type 1 unit scaling');
          end

          str = headerLine{~cellfun('isempty',strfind(headerLine,[signalStr ' Cal Coef:']))};
          calStr = strtrim(regexp(str,':','split'));
          calCoeffs = str2num(calStr{2});
          NTU.scale = calCoeffs(1);
          NTU.offset = calCoeffs(2);
      end
  end
end
