function data = readSBE19hex( dataLines, instHeader )
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
                   data.temperature  = zeros(length(dataLines), 1);
                   data.conductivity = zeros(length(dataLines), 1);
  if pressure,     data.pressure     = zeros(length(dataLines), 1); end
  if pressureVolt, data.pressureVolt = zeros(length(dataLines), 1); end
  if volt0,        data.volt0        = zeros(length(dataLines), 1); end
  if volt1,        data.volt1        = zeros(length(dataLines), 1); end
  if volt2,        data.volt2        = zeros(length(dataLines), 1); end
  if volt3,        data.volt3        = zeros(length(dataLines), 1); end
  if volt4,        data.volt4        = zeros(length(dataLines), 1); end
  if volt5,        data.volt5        = zeros(length(dataLines), 1); end
  if sbe38,        data.sbe38        = zeros(length(dataLines), 1); end
  if gtd,          data.gtdPres      = zeros(length(dataLines), 1); 
                   data.gtdTemp      = zeros(length(dataLines), 1); end
  if dualgtd,      data.dualgtdPres  = zeros(length(dataLines), 1); 
                   data.dualgtdTemp  = zeros(length(dataLines), 1); end
  if optode,       data.optode       = zeros(length(dataLines), 1); end
  if time,         data.time         = zeros(length(dataLines), 1); end
  
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
  
  data = convertData(data, instHeader);
end

function newData = convertData(data, header)
%CONVERTDATA Converts the data contained in the .hex file into IMOS
% compliant parameters.
%
  newData = struct;
  
  % temperature, pressure and conductivity will always be 
  % present, and conductivity conversion requires temperature 
  % and pressure, so we manually do all three
  newData.TEMP = convertTemperature(data.temperature, header);
  newData.PRES = convertPressure(   data.pressure, data.pressureVolt, header);
  newData.CNDC = convertConductivity(data.conductivity, ...
    newData.PRES, newData.TEMP, header);
  
  names = fieldnames(data);
  
  for k = 1:length(names)
    
    name = names{k};
    
    switch name
    
      % already in degrees celsius
      case 'sbe38'
        newData.TEMP_2 = data.sbe38;
    
      % millibars -> decibars
      case 'gtdPres'
        newData.PRES_2 = data.gtdPres / 100.0;
      
      % already in degrees celsius
      case 'gtdTemp'
        newData.TEMP_3 = data.gtdTemp;
      
      % millibars -> decibars
      case 'dualgtdPres'
        newData.PRES_3 = data.dualgtdPres / 100.0;
      
      % already in degrees celsius
      case 'dualgtdTemp'
        newData.TEMP_4 = data.dualgtdTemp;
      
      % umol/L -> kg/m^3
      case 'optode'
        newData.DOXY = data.optode * 32.0;
    
      % seconds since jan 1 2000 -> days since jan 1 0000
      case 'time'
        newData.TIME = (data.time / 86400) - datenum('2000-01-00 00:00:00');
      
      % A/D counts to volts
      case {'volt0', 'volt1', 'volt2', 'volt3', 'volt4', 'volt5'}
        newName = ['VOLT_' name(end)];
        newData.(newName) = convertVolts(data.(name), name, header);
      
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
% convertion equation provided with SBE19 calibration sheets.
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
  
  % convert from PSIA to decibar
  pressure = pressure / 1.45037738;
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
