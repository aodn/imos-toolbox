function data = readSBE37hex( dataLines, instHeader )
%READSBE37HEX Parses the given data lines from a SBE37 .DAT hexadecimal data file. 
%
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
% Author:       Guillaume Galibert <guillaume.galibert@utas.edu.au>
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

  % variables used to handle all of the optional entries
  temperature   = [find(instHeader.outputFormat == 't', 1, 'first'), find(instHeader.outputFormat == 't', 1, 'last')];
  conductivity  = [find(instHeader.outputFormat == 'c', 1, 'first'), find(instHeader.outputFormat == 'c', 1, 'last')];
  pressure      = [find(instHeader.outputFormat == 'p', 1, 'first'), find(instHeader.outputFormat == 'p', 1, 'last')];
  time          = [find(instHeader.outputFormat == 'T', 1, 'first'), find(instHeader.outputFormat == 'T', 1, 'last')];
  
  % preallocate space for the sample data
  nLines = length(dataLines);
  preallocZeros = zeros(nLines, 1);
  
  data.temperature                      = preallocZeros;
  data.conductivity                     = preallocZeros;
  if ~isempty(pressure), data.pressure  = preallocZeros; end
  data.time                             = preallocZeros;
  
  % read in the data
  for k = 1:length(dataLines)
    line = dataLines{k};
    
    % according to SeaBird documentation : http://www.seabird.com/pdf_documents/manuals/37IM_027.pdf
    data.temperature (k)                        = uint32(hex2dec(line(temperature(1)   :temperature(2))));
    data.conductivity(k)                        = uint32(hex2dec(line(conductivity(1)  :conductivity(2))));
    if ~isempty(pressure), data.pressure(k)     = swapbytes(uint16(hex2dec(line(pressure(1)      :pressure(2))))); end
    data.time(k)                                = swapbytes(uint32(hex2dec(line(time(1)          :time(2)))));
  end
  
  data = convertData(data, instHeader);
end

function newData = convertData(data, header)
%CONVERTDATA Converts the data contained in the .hex file into IMOS
% compliant parameters.
%
  newData = struct;
  
  names = fieldnames(data);
  
  for k = 1:length(names)
    
    name = names{k};
    
    switch name
        % according to SeaBird documentation : http://www.seabird.com/pdf_documents/manuals/37IM_027.pdf
        case 'temperature'
            newData.TEMP = data.temperature/10000 - 10;
        
        case 'conductivity'
            newData.CNDC = data.conductivity/100000 - 0.5;
            
        case 'pressure'
            pressureRangeInDbar = 0.6894757 * (header.PressureRange - 14.7);
            % pressure in dbar is relative to the ocean surface
            newData.PRES_REL = (data.pressure * pressureRangeInDbar /(0.85*65536)) - (0.05*pressureRangeInDbar);
        
        % seconds since jan 1 2000 -> days since jan 0 0000
        case 'time'
            newData.TIME = (data.time / (3600*24)) + datenum('2000-01-00 00:00:00');
      
    end
  end
end
