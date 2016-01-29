function structures = readAD2CPBinary( filename )
%READAD2CPBINARY Reads a binary file retrieved from an 'AD2CP'
% instrument.
%
% This function is able to parse raw binary data from any Nortek instrument
% which is defined in the Data formats chapter of the Nortek
% Integrator Guide AD2CP, 2015.
%
% Nortek AD2CP binary files consist of 2 'sections': header and data record, the format of
% which are specified in the Integrator Guide. This function reads
% in all of the sections contained in the file, and returns them within a
% cell array.
%
%
% Inputs:
%   filename   - A string containing the name of a raw binary file to
%                parse.
%
% Outputs:
%   structures - A struct containing all of the data structures that were
%                contained in the file.
%
% Author:       Guillaume Galibert <guillaume.galibert@utas.edu.au>
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
narginchk(1,1);

if ~ischar(filename),         error('filename must be a string');  end
if ~exist( filename, 'file'), error([filename ' does not exist']); end

% read in the whole file into 'data'
fid = -1;
data = [];
try
    fid = fopen(filename, 'rb');
    data = fread(fid, inf, '*uint8');
    fclose(fid);
catch e
    if fid ~= -1, fclose(fid); end
    rethrow e;
end

dataLen = length(data);
dIdx    = 1;

% read in all of the structures contained in the file
%
structures = struct;
[~, ~, cpuEndianness] = computer;

while dIdx < dataLen
    [sect, len] = readSection(filename, data, dIdx, cpuEndianness);
    
    if ~isempty(sect)
        if isfield(sect.Data, 'Version')
            curField = ['Id' sprintf('%s', sect.Header.Id) 'Version' sprintf('%d', sect.Data.Version)];
        else
            curField = ['Id' sprintf('%s', sect.Header.Id)];
        end
        theFieldNames = fieldnames(sect);
        nField = length(theFieldNames);
        
        if ~isfield(structures, curField)
            % copy first instance of IdX structure
            structures.(curField) = sect;
        else
            % append current IdX structure to existing
            % no pre-allocation is still faster than allocating more than needed and then removing the excess
            for i=1:nField
                structures.(curField).(theFieldNames{i})(:, end+1) = sect.(theFieldNames{i});
            end
        end
    end
    
    dIdx = dIdx + len; % if len is empty, then dIdx is going to be empty and will fail the while test
end

return;
end

%
% The functions below read in each of the data structures
% specified in the System integrator Manual.
%

function [sect, off] = readSection(filename, data, idx, cpuEndianness)
%READSECTION Reads the next data structure in the data array, starting at
% the given index.
%
sect = [];
off = [];

% we assume a section always starts with a header
% check sync byte
if data(idx) ~= hex2dec('A5') % hex 0xA5
    fprintf('%s\n', ['Warning : ' filename ' bad sync (idx '...
        num2str(idx) ', hex val ' num2str(dec2hex(data(idx))) ')']);
    return;
end

% if a section (typically the last one) is shorter than expected, 
% abort further data read
headerSize = bytecast(data(idx+1), 'L', 'uint8', cpuEndianness);
dataSize = bytecast(data(idx+4:idx+5), 'L', 'uint16', cpuEndianness);
len = headerSize + dataSize;
if length(data) < idx-1+len
    fprintf('%s\n', ['Warning : ' filename ' bad idx/len']);
    fprintf('%s\n', ['idx-1+len: ' num2str(idx-1+len) ' length(data): ' num2str(length(data))]);
    return;
end

% read the section in
id = dec2hex(data(idx+2));
switch id
    case '15'
        [sect, len, off] = readBurstAverage        (data, idx, cpuEndianness); % 0x15
    case '16'
        [sect, len, off] = readBurstAverage        (data, idx, cpuEndianness); % 0x16
    case '17'
        [sect, len, off] = readBottomTrack         (data, idx, cpuEndianness); % 0x17
    case '18'
        % [sect, len, off] = readInterleavedBurst    (data, idx, cpuEndianness); % 0x18
        disp('Interleaved Burst Data Record not supported');
        disp(['ID : hex ' id ' at offset ' num2str(idx+2)]);
    case 'A0'
        [sect, len, off] = readString              (data, idx, cpuEndianness); % 0xA0
    otherwise
        disp('Unknown section type');
        disp(['ID : hex ' id ' at offset ' num2str(idx+2)]);
end

if isempty(sect), return; end

% generate and compare checksum - all section
% structs have a Checksum field
cs = genChecksum(data, idx+headerSize, dataSize);

if cs ~= sect.Header.DataChecksum
    fprintf('%s\n', ['Warning : ' filename ' bad data checksum (idx '...
        num2str(idx+headerSize) ', checksum ' num2str(sect.Header.DataChecksum) ', calculated '...
        num2str(cs) ')']);
end
end

function cd = readClockData(data, idx, cpuEndianness)
%READCLOCKDATA Reads a clock data section and returns a matlab serial date.
%

data = data(idx:idx+7);

year    = bytecast(data(1), 'L', 'uint8', cpuEndianness);
month   = bytecast(data(2), 'L', 'uint8', cpuEndianness);
day     = bytecast(data(3), 'L', 'uint8', cpuEndianness);
hour    = bytecast(data(4), 'L', 'uint8', cpuEndianness);
minute  = bytecast(data(5), 'L', 'uint8', cpuEndianness);
second  = bytecast(data(6), 'L', 'uint8', cpuEndianness);
hundredsusecond  = bytecast(data(7:8), 'L', 'uint16', cpuEndianness);

second  = second + hundredsusecond/10000;
year = year + 1900;

cd = datenummx(year, month, day, hour, minute, second); % direct access to MEX function, faster
end

function [header, len, off] = readHeader(data, idx, cpuEndianness)
%READHEADER
% Id=0xA5, Header

header = struct;

header.Sync            = dec2hex(data(idx));
header.HeaderSize      = bytecast(data(idx+1), 'L', 'uint8', cpuEndianness);
header.Id              = dec2hex(data(idx+2));
header.Family          = dec2hex(data(idx+3));
header.DataSize        = bytecast(data(idx+4:idx+5), 'L', 'uint16', cpuEndianness);
header.DataChecksum    = bytecast(data(idx+6:idx+7), 'L', 'uint16', cpuEndianness);
header.HeaderChecksum  = bytecast(data(idx+8:idx+9), 'L', 'uint16', cpuEndianness);

len = header.HeaderSize;
off = len;

% generate and compare checksum
cs = genChecksum(data, idx, len-2);

if cs ~= header.HeaderChecksum
    fprintf('%s\n', ['Warning : ' filename ' bad header checksum (idx '...
        num2str(idx) ', checksum ' num2str(header.HeaderChecksum) ', calculated '...
        num2str(cs) ')']);
end

end

function [sect, len, off] = readBurstAverage(data, idx, cpuEndianness)
%READBURST
% Id=0x15, Burst/Average Data Record

sect = struct;
[sect.Header, len, off] = readHeader(data, idx, cpuEndianness);

idx = idx+off;

len = len + sect.Header.DataSize;
off = len;

sect.Data.Version           = bytecast(data(idx), 'L', 'uint8', cpuEndianness);

switch sect.Data.Version
    case 1
        sect.Data = readBurstAverageVersion1(data, idx, cpuEndianness);
    case 2
        sect.Data = readBurstAverageVersion2(data, idx, cpuEndianness);
    case 3
        sect.Data = readBurstAverageVersion3(data, idx, cpuEndianness);
    otherwise
        disp('Unknown burst version');
        disp(['Version : ' num2str(sect.Data.Version) ' at offset ' num2str(idx)]);
        sect = [];
end

end

function sect = readBurstAverageVersion1(data, idx, cpuEndianness)
%READBURSTAVERAGEVERSION1
% Id=0x15 or 0x16, Burst/Average Data Record
% Version=1

sect = struct;

sect.Version           = bytecast(data(idx), 'L', 'uint8', cpuEndianness);
sect.Configuration     = dec2bin(bytecast(data(idx+1), 'L', 'uint8', cpuEndianness), 8);

isVelocity      = sect.Configuration(end-6+1) == '1';
isAmplitude     = sect.Configuration(end-7+1) == '1';
isCorrelation   = sect.Configuration(end-8+1) == '1';

sect.Time              = readClockData(data, idx+2, cpuEndianness);
sect.SpeedOfSound      = bytecast(data(idx+10:idx+11), 'L', 'uint16', cpuEndianness); % 0.1 m/s
sect.Temperature       = bytecast(data(idx+12:idx+13), 'L', 'int16', cpuEndianness); % 0.01 Degree Celsius
sect.Pressure          = bytecast(data(idx+14:idx+17), 'L', 'uint32', cpuEndianness); % 0.001 dBar
sect.Heading           = bytecast(data(idx+18:idx+19), 'L', 'uint16', cpuEndianness); % 0.01 Deg
sect.Pitch             = bytecast(data(idx+20:idx+21), 'L', 'int16', cpuEndianness); % 0.01 Deg
sect.Roll              = bytecast(data(idx+22:idx+23), 'L', 'int16', cpuEndianness); % 0.01 Deg
sect.Error             = bytecast(data(idx+24:idx+25), 'L', 'uint16', cpuEndianness);
sect.Status            = bytecast(data(idx+26:idx+27), 'L', 'uint16', cpuEndianness);

sect.Beams_CoordSys_Cells = dec2bin(bytecast(data(idx+28:idx+29), 'L', 'uint16', cpuEndianness), 16);
iStartCell = 1;
iEndCell = 10;
iStartBeam = 13;
iEndBeam = 16;
sect.nCells            = bin2dec(sect.Beams_CoordSys_Cells(end-iEndCell+1:end-iStartCell+1));
sect.nBeams            = bin2dec(sect.Beams_CoordSys_Cells(end-iEndBeam+1:end-iStartBeam+1));

sect.CellSize          = bytecast(data(idx+30:idx+31), 'L', 'uint16', cpuEndianness); % 1 mm
sect.Blanking          = bytecast(data(idx+32:idx+33), 'L', 'uint16', cpuEndianness); % 1 mm
sect.VelocityRange     = bytecast(data(idx+34:idx+35), 'L', 'uint16', cpuEndianness); % 1 m/s
sect.VelocityScale     = bytecast(data(idx+36), 'L', 'int8', cpuEndianness); % used to scale velocity data
sect.BatteryVoltage    = bytecast(data(idx+37:idx+38), 'L', 'uint16', cpuEndianness); % 0.1 volt

% idx+39 is not used
off = 39;
if isVelocity
    sect.VelocityData       = reshape(bytecast(data(idx+off+1:idx+off+sect.nBeams*sect.nCells*2), 'L', 'int16', cpuEndianness), sect.nCells, sect.nBeams)'; % 10^(velocity scaling) m/s
    off = off+sect.nBeams*sect.nCells*2;
end

if isAmplitude
    sect.AmplitudeData      = reshape(bytecast(data(idx+off+1:idx+off+sect.nBeams*sect.nCells), 'L', 'uint8', cpuEndianness), sect.nCells, sect.nBeams)'; % 1 count
    off = off+sect.nBeams*sect.nCells;
end

if isCorrelation
    sect.CorrelationData    = reshape(bytecast(data(idx+off+1:idx+off+sect.nBeams*sect.nCells), 'L', 'uint8', cpuEndianness), sect.nCells, sect.nBeams)'; % [0-100]
    off = off+sect.nBeams*sect.nCells;
end

end

function sect = readBurstAverageVersion2(data, idx, cpuEndianness)
%READBURSTAVERAGEVERSION2
% Id=0x15 or 0x16, Burst/Average Data Record
% Version=2

sect = struct;

sect.Version           = bytecast(data(idx), 'L', 'uint8', cpuEndianness);
sect.OffsetOfData      = bytecast(data(idx+1), 'L', 'uint8', cpuEndianness);
sect.SerialNumber      = bytecast(data(idx+2:idx+5), 'L', 'uint32', cpuEndianness);
sect.Configuration     = dec2bin(bytecast(data(idx+6:idx+7), 'L', 'uint16', cpuEndianness), 16);

isVelocity      = sect.Configuration(end-6+1) == '1';
isAmplitude     = sect.Configuration(end-7+1) == '1';
isCorrelation   = sect.Configuration(end-8+1) == '1';

sect.Time              = readClockData(data, idx+8, cpuEndianness);
sect.SpeedOfSound      = bytecast(data(idx+16:idx+17), 'L', 'uint16', cpuEndianness); % 0.1 m/s
sect.Temperature       = bytecast(data(idx+18:idx+19), 'L', 'int16', cpuEndianness); % 0.01 Degree Celsius
sect.Pressure          = bytecast(data(idx+20:idx+23), 'L', 'uint32', cpuEndianness); % 0.001 dBar
sect.Heading           = bytecast(data(idx+24:idx+25), 'L', 'uint16', cpuEndianness); % 0.01 Deg
sect.Pitch             = bytecast(data(idx+26:idx+27), 'L', 'int16', cpuEndianness); % 0.01 Deg
sect.Roll              = bytecast(data(idx+28:idx+29), 'L', 'int16', cpuEndianness); % 0.01 Deg
sect.Error             = bytecast(data(idx+30:idx+31), 'L', 'uint16', cpuEndianness);
sect.Status            = bytecast(data(idx+32:idx+33), 'L', 'uint16', cpuEndianness);

sect.Beams_CoordSys_Cells = dec2bin(bytecast(data(idx+34:idx+35), 'L', 'uint16', cpuEndianness), 16);
iStartCell = 1;
iEndCell = 10;
iStartBeam = 13;
iEndBeam = 16;
sect.nCells            = bin2dec(sect.Beams_CoordSys_Cells(end-iEndCell+1:end-iStartCell+1));
sect.nBeams            = bin2dec(sect.Beams_CoordSys_Cells(end-iEndBeam+1:end-iStartBeam+1));

sect.CellSize          = bytecast(data(idx+36:idx+37), 'L', 'uint16', cpuEndianness); % 1 mm
sect.Blanking          = bytecast(data(idx+38:idx+39), 'L', 'uint16', cpuEndianness); % 1 mm
sect.VelocityRange     = bytecast(data(idx+40:idx+41), 'L', 'uint16', cpuEndianness); % 1 m/s
sect.BatteryVoltage    = bytecast(data(idx+42:idx+43), 'L', 'uint16', cpuEndianness); % 0.1 volt
sect.MagRawX           = bytecast(data(idx+44:idx+45), 'L', 'int16', cpuEndianness); % magnetometer Raw, X axis value in last measurement interval
sect.MagRawY           = bytecast(data(idx+46:idx+47), 'L', 'int16', cpuEndianness);
sect.MagRawZ           = bytecast(data(idx+48:idx+49), 'L', 'int16', cpuEndianness);
sect.AccRawX           = bytecast(data(idx+50:idx+51), 'L', 'int16', cpuEndianness); % accelerometer Raw, X axis value in last measurement interval (16384 = 1.0)
sect.AccRawY           = bytecast(data(idx+52:idx+53), 'L', 'int16', cpuEndianness);
sect.AccRawZ           = bytecast(data(idx+54:idx+55), 'L', 'int16', cpuEndianness);
sect.AmbiguityVelocity = bytecast(data(idx+56:idx+57), 'L', 'uint16', cpuEndianness); % 0.1mm/s ; corrected for sound velocity
sect.DatasetDesc       = dec2bin(bytecast(data(idx+58:idx+59), 'L', 'uint16', cpuEndianness), 16);
sect.TransmitEnergy    = bytecast(data(idx+60:idx+61), 'L', 'uint16', cpuEndianness);
sect.VelocityScaling   = bytecast(data(idx+62), 'L', 'int8', cpuEndianness);
sect.PowerLevel        = bytecast(data(idx+63), 'L', 'int8', cpuEndianness); % dB

% idx+64 to 67 is not used
off = 67;
if isVelocity
    sect.VelocityData       = reshape(bytecast(data(idx+off+1:idx+off+sect.nBeams*sect.nCells*2), 'L', 'int16', cpuEndianness), sect.nCells, sect.nBeams)'; % 10^(velocity scaling) m/s
    off = off+sect.nBeams*sect.nCells*2;
end

if isAmplitude
    sect.AmplitudeData      = reshape(bytecast(data(idx+off+1:idx+off+sect.nBeams*sect.nCells), 'L', 'uint8', cpuEndianness), sect.nCells, sect.nBeams)'; % 1 count
    off = off+sect.nBeams*sect.nCells;
end

if isCorrelation
    sect.CorrelationData    = reshape(bytecast(data(idx+off+1:idx+off+sect.nBeams*sect.nCells), 'L', 'uint8', cpuEndianness), sect.nCells, sect.nBeams)'; % [0-100]
    off = off+sect.nBeams*sect.nCells;
end

end

function sect = readBurstAverageVersion3(data, idx, cpuEndianness)
%READBURSTAVERAGEVERSION3
% Id=0x15 or 0x16, Burst/Average Data Record
% Version=3

sect = struct;

sect.Version           = bytecast(data(idx), 'L', 'uint8', cpuEndianness);
sect.OffsetOfData      = bytecast(data(idx+1), 'L', 'uint8', cpuEndianness);
sect.Configuration     = dec2bin(bytecast(data(idx+2:idx+3), 'L', 'uint16', cpuEndianness), 16);

isVelocity      = sect.Configuration(end-6+1) == '1';
isAmplitude     = sect.Configuration(end-7+1) == '1';
isCorrelation   = sect.Configuration(end-8+1) == '1';
isAltimeter     = sect.Configuration(end-9+1) == '1';
isAltimeterRaw  = sect.Configuration(end-10+1) == '1';
isAST           = sect.Configuration(end-11+1) == '1';

sect.SerialNumber      = bytecast(data(idx+4:idx+7), 'L', 'uint32', cpuEndianness);
sect.Time              = readClockData(data, idx+8, cpuEndianness);
sect.SpeedOfSound      = bytecast(data(idx+16:idx+17), 'L', 'uint16', cpuEndianness); % 0.1 m/s
sect.Temperature       = bytecast(data(idx+18:idx+19), 'L', 'int16', cpuEndianness); % 0.01 Degree Celsius
sect.Pressure          = bytecast(data(idx+20:idx+23), 'L', 'uint32', cpuEndianness); % 0.001 dBar
sect.Heading           = bytecast(data(idx+24:idx+25), 'L', 'uint16', cpuEndianness); % 0.01 Deg
sect.Pitch             = bytecast(data(idx+26:idx+27), 'L', 'int16', cpuEndianness); % 0.01 Deg
sect.Roll              = bytecast(data(idx+28:idx+29), 'L', 'int16', cpuEndianness); % 0.01 Deg

sect.Beams_CoordSys_Cells = dec2bin(bytecast(data(idx+30:idx+31), 'L', 'uint16', cpuEndianness), 16);
iStartCell = 1;
iEndCell = 10;
iStartBeam = 13;
iEndBeam = 16;
sect.nCells            = bin2dec(sect.Beams_CoordSys_Cells(end-iEndCell+1:end-iStartCell+1));
sect.nBeams            = bin2dec(sect.Beams_CoordSys_Cells(end-iEndBeam+1:end-iStartBeam+1));

sect.CellSize          = bytecast(data(idx+32:idx+33), 'L', 'uint16', cpuEndianness); % 1 mm
sect.Blanking          = bytecast(data(idx+34:idx+35), 'L', 'uint16', cpuEndianness); % 1 mm
sect.NominalCorrelation= bytecast(data(idx+36), 'L', 'uint8', cpuEndianness); % percent ; nominal correlation for the configured combination of cell size and velocity range
sect.TempPresSensor    = bytecast(data(idx+37), 'L', 'uint8', cpuEndianness); % 0.2 deg C ; T=(val/5)-4.0
sect.BatteryVoltage    = bytecast(data(idx+38:idx+39), 'L', 'uint16', cpuEndianness); % 0.1 volt
sect.MagRawX           = bytecast(data(idx+40:idx+41), 'L', 'int16', cpuEndianness); % magnetometer Raw, X axis value in last measurement interval
sect.MagRawY           = bytecast(data(idx+42:idx+43), 'L', 'int16', cpuEndianness);
sect.MagRawZ           = bytecast(data(idx+44:idx+45), 'L', 'int16', cpuEndianness);
sect.AccRawX           = bytecast(data(idx+46:idx+47), 'L', 'int16', cpuEndianness); % accelerometer Raw, X axis value in last measurement interval (16384 = 1.0)
sect.AccRawY           = bytecast(data(idx+48:idx+49), 'L', 'int16', cpuEndianness);
sect.AccRawZ           = bytecast(data(idx+50:idx+51), 'L', 'int16', cpuEndianness);
sect.AmbiguityVelocity = bytecast(data(idx+52:idx+53), 'L', 'uint16', cpuEndianness); % 10^(Velocity scaling) m/s ; corrected for sound velocity
sect.DatasetDesc       = dec2bin(bytecast(data(idx+54:idx+55), 'L', 'uint16', cpuEndianness), 16);
sect.TransmitEnergy    = bytecast(data(idx+56:idx+57), 'L', 'uint16', cpuEndianness);
sect.VelocityScaling   = bytecast(data(idx+58), 'L', 'int8', cpuEndianness);
sect.PowerLevel        = bytecast(data(idx+59), 'L', 'int8', cpuEndianness); % dB
sect.MagTemperature    = bytecast(data(idx+60:idx+61), 'L', 'int16', cpuEndianness); % uncalibrated
sect.RTCTemperature    = bytecast(data(idx+62:idx+63), 'L', 'int16', cpuEndianness); % 0.01 deg C
sect.Error             = bytecast(data(idx+64:idx+67), 'L', 'uint32', cpuEndianness);
sect.Status            = dec2bin(bytecast(data(idx+68:idx+71), 'L', 'uint32', cpuEndianness), 32);
sect.EnsembleCounter   = bytecast(data(idx+72:idx+75), 'L', 'uint32', cpuEndianness); % counts the number of ensembles in both averaged and burst data

off = 75;
if isVelocity
    sect.VelocityData       = reshape(bytecast(data(idx+off+1:idx+off+sect.nBeams*sect.nCells*2), 'L', 'int16', cpuEndianness), sect.nCells, sect.nBeams)'; % 10^(velocity scaling) m/s
    off = off+sect.nBeams*sect.nCells*2;
end

if isAmplitude
    sect.AmplitudeData      = reshape(bytecast(data(idx+off+1:idx+off+sect.nBeams*sect.nCells), 'L', 'uint8', cpuEndianness), sect.nCells, sect.nBeams)'; % 1 count
    off = off+sect.nBeams*sect.nCells;
end

if isCorrelation
    sect.CorrelationData    = reshape(bytecast(data(idx+off+1:idx+off+sect.nBeams*sect.nCells), 'L', 'uint8', cpuEndianness), sect.nCells, sect.nBeams)'; % [0-100]
    off = off+sect.nBeams*sect.nCells;
end

if isAltimeter
    off = off + 1;
    sect.AltimeterDistance  = bytecast(data(idx+off:idx+off+3), 'L', 'single', cpuEndianness); % m
    off = off + 3;
    sect.AltimeterQuality   = bytecast(data(idx+off:idx+off+1), 'L', 'uint16', cpuEndianness);
    off = off + 1;
    sect.AltimeterStatus    = dec2bin(bytecast(data(idx+off:idx+off+1), 'L', 'uint16', cpuEndianness), 16);
    off = off + 1;
end

if isAST
    off = off + 1;
    sect.ASTDistance        = bytecast(data(idx+off:idx+off+3), 'L', 'single', cpuEndianness); % m
    off = off + 3;
    sect.ASTQuality         = bytecast(data(idx+off:idx+off+1), 'L', 'uint16', cpuEndianness);
    off = off + 1;
    sect.ASTOffset100uSec   = bytecast(data(idx+off:idx+off+1), 'L', 'int16', cpuEndianness); % 100 us
    off = off + 1;
    sect.ASTPressure        = bytecast(data(idx+off:idx+off+3), 'L', 'single', cpuEndianness); % dbar
    off = off + 3;
end

end

function sect = readBottomTrack(data, idx, cpuEndianness)
%READBOTTOMTRACK
% Id=0x17, Bottom Track Data Record

sect = struct;
[sect.Header, len, off] = readHeader(data, idx, cpuEndianness);

idx = idx+off;

len = len + sect.Header.DataSize;
off = len;

sect.Data.Version           = bytecast(data(idx), 'L', 'uint8', cpuEndianness);
sect.Data.OffsetOfData      = bytecast(data(idx+1), 'L', 'uint8', cpuEndianness);
sect.Data.Configuration     = dec2bin(bytecast(data(idx+2:idx+3), 'L', 'uint16', cpuEndianness), 16);

isVelocity      = sect.Data.Configuration(end-6+1) == '1';
isDistance      = sect.Data.Configuration(end-7+1) == '1';
isFigureOfMerit = sect.Data.Configuration(end-8+1) == '1';

sect.Data.SerialNumber      = bytecast(data(idx+4:idx+7), 'L', 'uint32', cpuEndianness);
sect.Data.Time              = readClockData(data, idx+8, cpuEndianness);
sect.Data.SpeedOfSound      = bytecast(data(idx+16:idx+17), 'L', 'uint16', cpuEndianness); % 0.1 m/s
sect.Data.Temperature       = bytecast(data(idx+18:idx+19), 'L', 'int16', cpuEndianness); % 0.01 Degree Celsius
sect.Data.Pressure          = bytecast(data(idx+20:idx+23), 'L', 'uint32', cpuEndianness); % 0.001 dBar
sect.Data.Heading           = bytecast(data(idx+24:idx+25), 'L', 'uint16', cpuEndianness); % 0.01 Deg
sect.Data.Pitch             = bytecast(data(idx+26:idx+27), 'L', 'int16', cpuEndianness); % 0.01 Deg
sect.Data.Roll              = bytecast(data(idx+28:idx+29), 'L', 'int16', cpuEndianness); % 0.01 Deg

sect.Data.Beams_CoordSys_Cells = dec2bin(bytecast(data(idx+30:idx+31), 'L', 'uint16', cpuEndianness), 16);
iStartBeam = 13;
iEndBeam = 16;
sect.Data.nBeams            = bin2dec(sect.Beams_CoordSys_Cells(end-iEndBeam+1:end-iStartBeam+1));

sect.Data.CellSize          = bytecast(data(idx+32:idx+33), 'L', 'uint16', cpuEndianness); % 1 mm
sect.Data.Blanking          = bytecast(data(idx+34:idx+35), 'L', 'uint16', cpuEndianness); % 1 mm
sect.Data.NominalCorrelation= bytecast(data(idx+36), 'L', 'uint8', cpuEndianness); % percent ; nominal correlation for the configured combination of cell size and velocity range
% idx+37 is not used
sect.Data.BatteryVoltage    = bytecast(data(idx+38:idx+39), 'L', 'uint16', cpuEndianness); % 0.1 volt
sect.Data.MagRawX           = bytecast(data(idx+40:idx+41), 'L', 'int16', cpuEndianness); % magnetometer Raw, X axis value in last measurement interval
sect.Data.MagRawY           = bytecast(data(idx+42:idx+43), 'L', 'int16', cpuEndianness);
sect.Data.MagRawZ           = bytecast(data(idx+44:idx+45), 'L', 'int16', cpuEndianness);
sect.Data.AccRawX           = bytecast(data(idx+46:idx+47), 'L', 'int16', cpuEndianness); % accelerometer Raw, X axis value in last measurement interval (16384 = 1.0)
sect.Data.AccRawY           = bytecast(data(idx+48:idx+49), 'L', 'int16', cpuEndianness);
sect.Data.AccRawZ           = bytecast(data(idx+50:idx+51), 'L', 'int16', cpuEndianness);
sect.Data.AmbiguityVelocity = bytecast(data(idx+52:idx+53), 'L', 'uint16', cpuEndianness); % 10^(Velocity scaling) m/s ; corrected for sound velocity
sect.Data.DatasetDesc       = dec2bin(bytecast(data(idx+54:idx+55), 'L', 'uint16', cpuEndianness), 16);
sect.Data.TransmitEnergy    = bytecast(data(idx+56:idx+57), 'L', 'uint16', cpuEndianness);
sect.Data.VelocityScaling   = bytecast(data(idx+58), 'L', 'int8', cpuEndianness);
sect.Data.PowerLevel        = bytecast(data(idx+59), 'L', 'int8', cpuEndianness); % dB
sect.Data.MagTemperature    = bytecast(data(idx+60:idx+61), 'L', 'int16', cpuEndianness); % uncalibrated
sect.Data.RTCTemperature    = bytecast(data(idx+62:idx+63), 'L', 'int16', cpuEndianness); % 0.01 deg C
sect.Data.Error             = bytecast(data(idx+64:idx+67), 'L', 'uint32', cpuEndianness);
sect.Status                 = dec2bin(bytecast(data(idx+68:idx+71), 'L', 'uint32', cpuEndianness), 32);
sect.Data.EnsembleCounter   = bytecast(data(idx+72:idx+75), 'L', 'uint32', cpuEndianness); % counts the number of ensembles in both averaged and burst data

off = 75;
if isVelocity
    sect.VelocityData       = bytecast(data(idx+off+1:idx+off+sect.nBeams*4), 'L', 'int32', cpuEndianness); % 10^(velocity scaling) m/s
    off = off+sect.nBeams*4;
end

if isDistance
    sect.DistanceData       = bytecast(data(idx+off+1:idx+off+sect.nBeams*4), 'L', 'int32', cpuEndianness); % mm
    off = off+sect.nBeams*4;
end

if isFigureOfMerit
    sect.FigureOfMeritData  = bytecast(data(idx+off+1:idx+off+sect.nBeams*2), 'L', 'uint16', cpuEndianness);
    off = off+sect.nBeams*2;
end

end

function [sect, len, off] = readString(data, idx, cpuEndianness)
%READSTRING Reads a string data record section.
% Id=0xA0, String Data Record

sect = struct;
[sect.Header, len, off] = readHeader(data, idx, cpuEndianness);

idx = idx+off;

len = len + sect.Header.DataSize;
off = len;

sect.Data.Id      = bytecast(data(idx), 'L', 'uint8', cpuEndianness);
sect.Data.String  = char(data(idx+1:len)');

end

function cs = genChecksum(data, idx, len)
%GENCHECKSUM Generates a checksum over the given data range. See page 52 of
%the System integrator manual.
%
% start checksum value is 0xB58C (== 46476)
cs = hex2dec('B58C');

% the checksum routine relies upon uint16 overflow, but matlab's
% 'saturation' of out-of-bounds values makes this impossible.
% so i'm doing normal addition, then modding the result by 65536,
% which will give the same result
data = double(data(idx:idx+len-1));

dataO = data(1:2:len-1);
dataE = data(2:2:len);

cs = cs + sum(dataO) + sum(dataE)*256;

cs = mod(cs, 65536);

end
