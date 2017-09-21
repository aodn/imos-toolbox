function [data, comment] = readSBE19hex( dataLines, instHeader )
%READSBE19HEX Parses the given data lines from a SBE19 .hex data file. 
%
% Currently, only raw hex (raw voltages and frequencies) output format is 
% supported.
%
% Inputs:
%   dataLines  - Cell array of strings, the lines from the .hex file which
%                contain data.
%   instHeader - Struct containing information contained in the .hex file
%                header.
%
% Outputs:
%   data       - Struct containing variable data.
%   comment    - Struct containing variable comment.
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

  data = struct;

  % boolean variables used to handle all of the optional entries
  
  % Currently, only raw hex output format is supported, 
  % so each pressure reading has an associated temperature 
  % compensation voltage. If raw eng is supported in the 
  % future, the logic defining the value of pressureVolt 
  % will need to be implemented.
  pressure     = checkField(instHeader, 'pressureSensor', 'strain gauge');
  pressureVolt = pressure;
  volt0        = checkField(instHeader, 'ExtVolt0',       'yes');
  volt1        = checkField(instHeader, 'ExtVolt1',       'yes');
  volt2        = checkField(instHeader, 'ExtVolt2',       'yes');
  volt3        = checkField(instHeader, 'ExtVolt3',       'yes');
  volt4        = checkField(instHeader, 'ExtVolt4',       'yes');
  volt5        = checkField(instHeader, 'ExtVolt5',       'yes');
  sbe38        = checkField(instHeader, 'sbe38',          'yes');
  gtd          = checkField(instHeader, 'gtd',            'yes');
  dualgtd      = checkField(instHeader, 'dualgtd',        'yes');
  optode       = checkField(instHeader, 'optode',         'yes');
  time         = checkField(instHeader, 'mode',           'moored');
  
  % preallocate space for the sample data
  nLines = length(dataLines);
  preallocZeros = zeros(nLines, 1);
                   data.temperature  = preallocZeros;
                   data.conductivity = preallocZeros;
  if pressure,     data.pressure     = preallocZeros; end
  if pressureVolt, data.pressureVolt = preallocZeros; end
  if volt0,        data.volt0        = preallocZeros; end
  if volt1,        data.volt1        = preallocZeros; end
  if volt2,        data.volt2        = preallocZeros; end
  if volt3,        data.volt3        = preallocZeros; end
  if volt4,        data.volt4        = preallocZeros; end
  if volt5,        data.volt5        = preallocZeros; end
  if sbe38,        data.sbe38        = preallocZeros; end
  if gtd,          data.gtdPres      = preallocZeros; 
                   data.gtdTemp      = preallocZeros; end
  if dualgtd,      data.dualgtdPres  = preallocZeros; 
                   data.dualgtdTemp  = preallocZeros; end
  if optode,       data.optode       = preallocZeros; end
  if time,         data.time         = preallocZeros; end
  
  % read in the data
  for k = 1:length(dataLines)
    
    % l is an index into the current line
    l    = 1;
    line = dataLines{k};
    
                     data.temperature (k) = hex2dec(line(l:l+5)); l=l+6;
                     data.conductivity(k) = hex2dec(line(l:l+5)); l=l+6;
    if pressure,     data.pressure    (k) = hex2dec(line(l:l+5)); l=l+6; end
    if pressureVolt, data.pressureVolt(k) = hex2dec(line(l:l+3)); l=l+4; end
    if volt0,        data.volt0       (k) = hex2dec(line(l:l+3)); l=l+4; end
    if volt1,        data.volt1       (k) = hex2dec(line(l:l+3)); l=l+4; end
    if volt2,        data.volt2       (k) = hex2dec(line(l:l+3)); l=l+4; end
    if volt3,        data.volt3       (k) = hex2dec(line(l:l+3)); l=l+4; end
    if volt4,        data.volt4       (k) = hex2dec(line(l:l+3)); l=l+4; end
    if volt5,        data.volt5       (k) = hex2dec(line(l:l+3)); l=l+4; end
    if sbe38,        data.sbe38       (k) = hex2dec(line(l:l+3)); l=l+4; end
    if gtd,          data.gtdPres     (k) = hex2dec(line(l:l+7)); l=l+8; 
                     data.gtdTemp     (k) = hex2dec(line(l:l+5)); l=l+6; end
    if dualgtd,      data.dualgtdPres (k) = hex2dec(line(l:l+7)); l=l+8; 
                     data.dualgtdTemp (k) = hex2dec(line(l:l+5)); l=l+6; end
    if optode,       data.optode      (k) = hex2dec(line(l:l+5)); l=l+6; end
    if time,         data.time        (k) = hex2dec(line(l:l+7)); l=l+8; end
  end
  
  [data, comment] = convertData(data, instHeader);
end

function [newData, comment] = convertData(data, header)
%CONVERTDATA Converts the data contained in the .hex file into IMOS
% compliant parameters.
%
  newData = struct;
  comment = struct;
  
  % temperature, pressure and conductivity will always be 
  % present, and conductivity conversion requires temperature 
  % and pressure, so we manually do all three
  newData.TEMP = convertTemperature(data.temperature, header);
  comment.TEMP = '';
  newData.PRES = convertPressure(   data.pressure, data.pressureVolt, header);
  comment.PRES = '';
  newData.CNDC = convertConductivity(data.conductivity, ...
    newData.PRES, newData.TEMP, header);
  comment.CNDC = '';
  
  names = fieldnames(data);
  
  for k = 1:length(names)
    
    name = names{k};
    
    switch name
    
      % already in degrees celsius
      case 'sbe38'
        newData.TEMP_2 = data.sbe38;
        comment.TEMP_2 = '';
    
      % millibars -> decibars
      case 'gtdPres'
        newData.PRES_2 = data.gtdPres / 100.0;
        comment.PRES_2 = '';
      
      % already in degrees celsius
      case 'gtdTemp'
        newData.TEMP_3 = data.gtdTemp;
        comment.TEMP_3 = '';
      
      % millibars -> decibars
      case 'dualgtdPres'
        newData.PRES_3 = data.dualgtdPres / 100.0;
        comment.PRES_3 = '';
      
      % already in degrees celsius
      case 'dualgtdTemp'
        newData.TEMP_4 = data.dualgtdTemp;
        comment.TEMP_4 = '';
      
      % umol/l
      case 'optode'
        % Exactly like we want it to be.
        newData.DOX1 = data.optode;
        comment.DOX1 = '';
    
      % seconds since jan 1 2000 -> days since jan 1 0000
      case 'time'
        newData.TIME = (data.time / 86400) - datenum('2000-01-00 00:00:00');
        comment.TIME = '';
      
      % A/D counts to volts (sensor_analog_output 0 to 5)
      case {'volt0', 'volt1', 'volt2', 'volt3', 'volt4', 'volt5'}
        newName = ['ANA' name(end)];
        newData.(newName) = convertVolts(data.(name), name, header);
        comment.(newName) = '';
      
    end
  end
  
end

function check = checkField(struc, fieldName, fieldValue)
%CHECKFIELD Checks for existence of the given field in the given struct; if
% the field exists, checks the value (string comparison only).
%
  if ~isfield(struc, fieldName),              check = false; return; end
  if ~strcmp( struc.(fieldName), fieldValue), check = false; return; end
  
  check = true;
end

function temperature = convertTemperature(temperature, header)
%CONVERTTEMPERATURE Converts temperature A/D counts to degrees celsius, via
% the convertion equation provided with SBE19 calibration sheets.
%

  if ~isfield(header, 'TA0'),     return; end
  if ~isfield(header, 'TA1'),     return; end
  if ~isfield(header, 'TA2'),     return; end
  if ~isfield(header, 'TA3'),     return; end

  TA0     = str2double(header.TA0);
  TA1     = str2double(header.TA1);
  TA2     = str2double(header.TA2);
  TA3     = str2double(header.TA3);
  
  % convert from A/D counts to degrees celsius; the equation 
  % is as follows (from SBE19 calibration sheet):
  %
  %   MV = (temperature - 524288)/1.6E+07
  %   R  = (MV.2.9e+09 + 1.024E+08)/(2.048E+04 - MV.2.0E+05)
  %   temperature = 1 / (TA0 + TA1.ln(R) + TA2.(ln^2(R)) + TA3.(ln^3(R))) -
  %                   273.15
  %
  MV = (temperature - 524288) / 1.6E+07;
  R  = (MV * 2.9E+09 + 1.024E+08)./(2.048E+04 - MV * 2.0E+05);
  temperature = 1 ./ ( TA0             + ...
                      (TA1 * log(R)  ) + ...
                      (TA2 * log(R).^2) + ...
                      (TA3 * log(R).^3)) - 273.15;

end

function conductivity = convertConductivity(...
  conductivity, pressure, temperature, header)
%CONVERTCONDUCTIVITY Converts conductivity frequency to siemens per metre, 
% via the convertion equation provided with SBE19 calibration sheets.
%

  if ~isfield(header, 'G'),      return; end
  if ~isfield(header, 'H'),      return; end
  if ~isfield(header, 'I'),      return; end
  if ~isfield(header, 'J'),      return; end
  if ~isfield(header, 'CTCOR'),  return; end
  if ~isfield(header, 'CPCOR'),  return; end

  G      = str2double(header.G);
  H      = str2double(header.H);
  I      = str2double(header.I);
  J      = str2double(header.J);
  CTCOR  = str2double(header.CTCOR);
  CPCOR  = str2double(header.CPCOR);

  % convert from counts to Hz, and Hz to kHz
  conductivity = conductivity / (1000.0 * 256);
  
  % convert from frequency to S/m; the equation is as follows:
  %
  %   conductivity = (G + H.counts^2 + I.counts^3 + J.counts^4) / 
  %                  (1 + CTCOR.temperature + CPCOR.pressure)
  %
  conductivity =  G                     + ...
                 (H * (conductivity.^2)) + ...
                 (I * (conductivity.^3)) + ...
                 (J * (conductivity.^4));
  conductivity = conductivity ./ ...
                 (1 + (CTCOR * temperature) + ...
                      (CPCOR * pressure));
end

function pressure = convertPressure(pressure, pressureVolt, header)
%CONVERTPRESSURE Converts pressure A/D counts to decibars, via the 
% convertion equation provided with SBE19 calibration sheets. Here, the
% constant value 14.7*0.689476 dbar for atmospheric pressure isn't 
% substracted like in the processed .cnv data.
%

  if ~isfield(header, 'PTEMPA0'), return; end
  if ~isfield(header, 'PTEMPA1'), return; end
  if ~isfield(header, 'PTEMPA2'), return; end
  if ~isfield(header, 'PTCA0'),   return; end
  if ~isfield(header, 'PTCA1'),   return; end
  if ~isfield(header, 'PTCA2'),   return; end
  if ~isfield(header, 'PTCB0'),   return; end
  if ~isfield(header, 'PTCB1'),   return; end
  if ~isfield(header, 'PTCB2'),   return; end
  if ~isfield(header, 'PA0'),     return; end
  if ~isfield(header, 'PA1'),     return; end
  if ~isfield(header, 'PA2'),     return; end

  PTEMPA0 = str2double(header.PTEMPA0);
  PTEMPA1 = str2double(header.PTEMPA1);
  PTEMPA2 = str2double(header.PTEMPA2);
  PTCA0   = str2double(header.PTCA0);
  PTCA1   = str2double(header.PTCA1);
  PTCA2   = str2double(header.PTCA2);
  PTCB0   = str2double(header.PTCB0);
  PTCB1   = str2double(header.PTCB1);
  PTCB2   = str2double(header.PTCB2);
  PA0     = str2double(header.PA0);
  PA1     = str2double(header.PA1);
  PA2     = str2double(header.PA2);
  
  % convert pressure thermistor from A/D counts to volts
  pressureVolt = pressureVolt / 13107;
  
  % convert from A/D counts to PSIA; 
  % the equation is as follows:
  %
  %   t = PTEMPA0 + PTEMPA1.rawthermistor + PTEMPA2.rawthermistor^2
  %   x = counts - PTCA0 - PTCA1.t - PTCA2.t^2
  %   n = x.PTCB0/(PTCB0 + PTCB1.t + PTCB2.t^2)
  %
  %   pressure = PA0 + PA1.n + PA2.n^2 
  t = PTEMPA0 + PTEMPA1 * pressureVolt + PTEMPA2 * (pressureVolt.^2);
  x = pressure - PTCA0 - (PTCA1 * t) - PTCA2 - (t.^2);
  n = (x * PTCB0) ./ (PTCB0 + PTCB1 * t + PTCB2 * (t.^2));
  
  pressure = PA0 + PA1 * n + PA2 * (n.^2);
  
  % convert from PSIA to decibar (1 PSI = 6894.76 Pa)
  pressure = pressure * 0.689476;
end

function volts = convertVolts(volts, name, header)
%CONVERTVOLTS Converts from raw A/D counts to voltage, as specified in the 
% SBE19 manual.
%
  % convert from counts to voltage
  volts = volts / 13107.0;
  
  % apply scaling offset
  %if ~isfield(header, [name 'offset']), return; end
  %if ~isfield(header, [name 'slope']),  return; end
  %
  %offset = header.([name 'offset']);
  %slope  = header.([name 'slope']);
  %
  %volts = offset + slope * volts;

end
