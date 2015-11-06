function structures = readParadoppBinary( filename )
%READPARADOPPBINARY Reads a binary file retrieved from a 'Paradopp'
% instrument. Does not support AWAC wave data.
%
% This function is able to parse raw binary data from any Nortek instrument
% which is defined in the Firmware Data Structures section of the Nortek
% System Integrator Guide, June 2008:
%
%   - Aquadopp Current Meter (Velocity)
%   - Aquadopp Profiler
%   - Aquadopp HR Profiler
%   - Continental
%   - Vector
%   - Vectrino
%   - AWAC
%
% Nortek binary files consist of a number of 'sections', the format of
% which are specified in the System Integrator Guide. This function reads
% in all of the sections contained in the file, and returns them within a
% cell array.
%
% AWAC wave data is ignored by this function; see the readAWACWaveAscii
% function.
%
% Inputs:
%   filename   - A string containing the name of a raw binary file to
%                parse.
%
% Outputs:
%   structures - A struct containing all of the data structures that were
%                contained in the file.
%
% Author:       Paul McCarthy <paul.mccarthy@csiro.au>
% Contributor:  Guillaume Galibert <guillaume.galibert@utas.edu.au>
% 				Simon Spagnol <simon.spagnol@utas.edu.au>
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
error(nargchk(1,1,nargin));

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
% all files should start off with the following sections,
% although this is not checked:
%   hardware configuration
%   head configuration
%   user configuration
%
structures = struct;
[~, ~, cpuEndianness] = computer;

while dIdx < dataLen
    
    [sect, len] = readSection(filename, data, dIdx, cpuEndianness);
    if ~isempty(sect)
        curField = ['Id' sprintf('%d', sect.Id)];
        if ~isfield(structures, curField)
            structures.(curField) = sect;
        else
            fieldNames = fieldnames(structures.(curField));
            nField = length(fieldNames);
            for i=1:nField
                structures.(curField).(fieldNames{i})(:, end+1) = sect.(fieldNames{i}); % no pre-allocation is still faster than allocating more than needed and then removing the excess
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

% check sync byte
if data(idx) ~= 165 % hex a5
    fprintf('%s\n', ['Warning : ' filename ' bad sync (idx '...
        num2str(idx) ', val ' num2str(data(idx)) ')']);
    return;
end

sectType = data(idx+1);
%disp(['sectType : hex ' dec2hex(sectType) ' == ' num2str(sectType) ' at offset ' num2str(idx+1)]);

% read the section in
switch sectType
    case 0,   [sect, len, off] = readUserConfiguration            (data, idx, cpuEndianness); % 0x00
    case 1,   [sect, len, off] = readAquadoppVelocity             (data, idx, cpuEndianness); % 0x01
    case 2,   [sect, len, off] = readVectrinoDistance             (data, idx, cpuEndianness); % 0x02
    case 4,   [sect, len, off] = readHeadConfiguration            (data, idx, cpuEndianness); % 0x04
    case 5,   [sect, len, off] = readHardwareConfiguration        (data, idx, cpuEndianness); % 0x05
    case 6,   [sect, len, off] = readAquadoppDiagHeader           (data, idx, cpuEndianness); % 0x06
    case 7,   [sect, len, off] = readVectorProbeCheck             (data, idx, cpuEndianness); % 0x07
    case 16,  [sect, len, off] = readVectorVelocity               (data, idx, cpuEndianness); % 0x10
    case 17,  [sect, len, off] = readVectorSystem                 (data, idx, cpuEndianness); % 0x11
    case 18,  [sect, len, off] = readVectorVelocityHeader         (data, idx, cpuEndianness); % 0x12
    case 32,  [sect, len, off] = readAwacVelocityProfile          (data, idx, cpuEndianness); % 0x20
    case 33,  [sect, len, off] = readAquadoppProfilerVelocity     (data, idx, cpuEndianness); % 0x21
    case 36,  [sect, len, off] = readContinental                  (data, idx, cpuEndianness); % 0x24
    case 42,  [sect, len, off] = readHRAquadoppProfile            (data, idx, cpuEndianness); % 0x2A
    case 48,  [sect, len, off] = readAwacWaveData                 (data, idx, cpuEndianness); % 0x30
    case 49,  [sect, len, off] = readAwacWaveHeader               (data, idx, cpuEndianness); % 0x31
    case 54,  [sect, len, off] = readAwacWaveDataSUV              (data, idx, cpuEndianness); % 0x36
    case 66,  [sect, len, off] = readAwacStageData                (data, idx, cpuEndianness); % 0x42
    case 80,  [sect, len, off] = readVectrinoVelocityHeader       (data, idx, cpuEndianness); % 0x50
    case 81,  [sect, len, off] = readVectrinoVelocity             (data, idx, cpuEndianness); % 0x51
    case 96,  [sect, len, off] = readWaveParameterEstimates       (data, idx, cpuEndianness); % 0x60
    case 97,  [sect, len, off] = readWaveBandEstimates            (data, idx, cpuEndianness); % 0x61
    case 98,  [sect, len, off] = readWaveEnergySpectrum           (data, idx, cpuEndianness); % 0x62
    case 99,  [sect, len, off] = readWaveFourierCoefficentSpectrum(data, idx, cpuEndianness); % 0x63
    case 101, [sect, len, off] = readAwacAST                      (data, idx, cpuEndianness); % 0x65
    case 106, [sect, len, off] = readAwacProcessedVelocity        (data, idx, cpuEndianness); % 0x6A
    case 128, [sect, len, off] = readAquadoppDiagnostics          (data, idx, cpuEndianness); % 0x80
    otherwise
%        disp('Unknown sector type');
%        disp(['sectType : hex ' dec2hex(sectType) ' == ' num2str(sectType) ' at offset ' num2str(idx+1)]);        
        [sect, len, off] = readGeneric(data, idx, cpuEndianness);
end

if isempty(sect), return; end
if numel(data) < idx+len
        fprintf('%s\n', ['Warning : ' filename ' bad idx/len']);
    fprintf('%s\n', ['Sect Type: ' num2str(sectType)]);
    sect = [];
    return;
end

% generate and compare checksum - all section
% structs have a Checksum field
cs = genChecksum(data, idx, len-2);

if cs ~= sect.Checksum
    fprintf('%s\n', ['Warning : ' filename ' bad checksum (idx '...
        num2str(idx) ', checksum ' num2str(sect.Checksum) ', calculated '...
        num2str(cs) ')']);
    fprintf('%s\n', ['Sect Type: ' num2str(sectType)]);
end
end

function cd = readClockData(data, idx)
%READCLOCKDATA Reads a clock data section (pg 29 of system integrator
%manual) and returns a matlab serial date.
%

data = data(idx:idx+5);
date = double(10*bitand(bitshift(data, -4), 15) + bitand(data, 15));

minute = date(1);
second = date(2);
day    = date(3);
hour   = date(4);
year   = date(5);
month  = date(6);

% pg 52 of system integrator manual
if year >= 90, year = year + 1900;
else           year = year + 2000;
end

%   cd = datenum(year, month, day, hour, minute, second);
cd = datenummx(year, month, day, hour, minute, second); % direct access to MEX function, faster
end

function [sect, len, off] = readHardwareConfiguration(data, idx, cpuEndianness)
%READHARDWARECONFIGURATION
% Id=0x05, Hardware Configuration
% SYSTEM INTEGRATOR MANUAL (Dec 2014) pg 28-29

sect = struct;
len = 48;
off = len;

sect.Sync       = data(idx);
sect.Id         = data(idx+1);
sect.Size       = data(idx+2:idx+3); % uint16
sect.SerialNo   = data(idx+4:idx+17);
sect.SerialNo   = char(sect.SerialNo(sect.SerialNo ~= 0)');
block           = data(idx+18:idx+29); % uint16
% bytes 30-41 are free
sect.FWversion  = data(idx+42:idx+45);
sect.FWversion  = char(sect.FWversion(sect.FWversion ~= 0)');
sect.Checksum   = data(idx+46:idx+47); % uint16

% let's process uint16s in one call
blocks = bytecast([sect.Size; block; sect.Checksum], 'L', 'uint16', cpuEndianness);
sect.Size       = blocks(1);
sect.Config     = blocks(2);
sect.Frequency  = blocks(3);
sect.PICversion = blocks(4);
sect.HWrevision = blocks(5);
sect.RecSize    = blocks(6);
sect.Status     = blocks(7);
sect.Checksum   = blocks(8);
end

function [sect, len, off] = readHeadConfiguration(data, idx, cpuEndianness)
%READHEADCONFIGURATION Reads a head configuration section.
% Id=0x04, Head Configuration
% SYSTEM INTEGRATOR MANUAL (Dec 2014) pg 29

sect = struct;
len = 224;
off = len;

sect.Sync      = data(idx);
sect.Id        = data(idx+1);
block1         = data(idx+2:idx+9);  % uint16
sect.SerialNo  = data(idx+10:idx+21);
sect.SerialNo  = char(sect.SerialNo(sect.SerialNo ~= 0)');

% MUST CHECK ARRAY LAYOUT
sect.System5  = double(bytecast(data(idx+22:idx+29), 'L', 'uint16', cpuEndianness))';

sect.TransformationMatrix = reshape(double(bytecast(data(idx+30:idx+47), 'L', 'int16', cpuEndianness))/4096, [3 3])';

sect.System7  = reshape(double(bytecast(data(idx+48:idx+63), 'L', 'int16', cpuEndianness)), [4 2])';
sect.System8  = reshape(double(bytecast(data(idx+66:idx+83), 'L', 'int16', cpuEndianness)), [3 3])';
sect.System9  = reshape(double(bytecast(data(idx+84:idx+101), 'L', 'int16', cpuEndianness)), [3 3])';
sect.System10 = double(bytecast(data(idx+102:idx+109), 'L', 'int16', cpuEndianness))';
sect.System11 = double(bytecast(data(idx+110:idx+117), 'L', 'int16', cpuEndianness))';

sect.PressureSensorCalibration = double(bytecast(data(idx+118:idx+125), 'L', 'uint16', cpuEndianness))';

sect.System13 = double(bytecast(data(idx+126:idx+133), 'L', 'int16', cpuEndianness))';
sect.System14 = reshape(double(bytecast(data(idx+134:idx+149), 'L', 'int16', cpuEndianness)), [4 2])';
sect.System15 = reshape(double(bytecast(data(idx+150:idx+181), 'L', 'int16', cpuEndianness)), [4 4])';
sect.System16 = double(bytecast(data(idx+182:idx+189), 'L', 'int16', cpuEndianness))';
sect.System17 = double(bytecast(data(idx+190:idx+191), 'L', 'int16', cpuEndianness))';
sect.System18 = double(bytecast(data(idx+192:idx+193), 'L', 'int16', cpuEndianness))';
sect.System19 = double(bytecast(data(idx+194:idx+195), 'L', 'int16', cpuEndianness))';
sect.System20 = double(bytecast(data(idx+196:idx+197), 'L', 'int16', cpuEndianness))';

% bytes 198-219 are free
block2         = data(idx+220:idx+223);  % uint16

% let's process uint16s in one call
blocks = bytecast([block1; block2], 'L', 'uint16', cpuEndianness);
sect.Size      = blocks(1);
sect.Config    = blocks(2);
sect.Frequency = blocks(3);
sect.Type      = blocks(4);
sect.NBeams    = blocks(5);
sect.Checksum  = blocks(6);

end

function [sect, len, off] = readUserConfiguration(data, idx, cpuEndianness)
%readUserConfiguration Reads a user configuration section.
% Id=0x00, User Configuration
% SYSTEM INTEGRATOR MANUAL (Dec 2014) pg 30-32

sect = struct;
len = 512;
off = len;

sect.Sync           = data(idx);
sect.Id             = data(idx+1);
block1              = data(idx+2:idx+39);  % uint16
sect.DeployName     = data(idx+40:idx+45);
sect.DeployName     = char(sect.DeployName(sect.DeployName ~= 0)');
sect.WrapMode       = data(idx+46:idx+47);  % uint16
sect.clockDeploy    = readClockData(data, idx+48);
sect.DiagInterval   = bytecast(data(idx+54:idx+57), 'L', 'uint32', cpuEndianness);
block2              = data(idx+58:idx+73); % uint16
% bytes 74-75 are spare
sect.VelAdjTable    = 0; % 180 bytes; not sure what to do with them
sect.Comments       = data(idx+256:idx+435);
sect.Comments       = char(sect.Comments(sect.Comments ~= 0)');
block3              = data(idx+436:idx+463); % uint16
% bytes 464-493 are spare
sect.QualConst      = 0; % 16 bytes
sect.Checksum       = data(idx+510:idx+511); % uint16

% let's process uint16s in one call
blocks = bytecast([block1; sect.WrapMode; block2; block3; sect.Checksum], 'L', 'uint16', cpuEndianness);
sect.Size           = blocks(1);
sect.T1             = blocks(2);
sect.T2             = blocks(3);
sect.T3             = blocks(4);
sect.T4             = blocks(5);
sect.T5             = blocks(6);
sect.NPings         = blocks(7);
sect.AvgInterval    = blocks(8);
sect.NBeams         = blocks(9);
sect.TimCtrlReg     = blocks(10);
sect.PwrCtrlReg     = blocks(11);
sect.A1_1           = blocks(12);
sect.B0_1           = blocks(13);
sect.B1_1           = blocks(14);
sect.CompassUpdRate = blocks(15);
sect.CoordSystem    = blocks(16);
sect.NBins          = blocks(17);
sect.BinLength      = blocks(18);
sect.MeasInterval   = blocks(19);
sect.WrapMode       = blocks(20);
sect.Mode           = dec2bin(blocks(21), 8);
sect.AdjSoundSpeed  = blocks(22);
sect.NSampDiag      = blocks(23);
sect.NBeamsCellDiag = blocks(24);
sect.NPingsDiag     = blocks(25);
sect.ModeTest       = blocks(26);
sect.AnalnAddr      = blocks(27);
sect.SWVersion      = blocks(28);
sect.WMMode         = blocks(29);
sect.DynPercPos     = blocks(30);
sect.WT1            = blocks(31);
sect.WT2            = blocks(32);
sect.WT3            = blocks(33);
sect.NSamp          = blocks(34);
sect.A1_2           = blocks(35);
sect.B0_2           = blocks(36);
sect.B1_2           = blocks(37);
% bytes 454-455 are spare
sect.AnaOutScale    = blocks(39);
sect.CorrThresh     = blocks(40);
% bytes 460-461 are spare
sect.TiLag2         = blocks(42);
sect.Checksum       = blocks(43);
end

function [sect, len, off] = readAquadoppVelocity(data, idx, cpuEndianness)
%READAQUADOPPVELOCITY Reads an Aquadopp velocity data section.
% Id=0x01, Aquadopp Velocity Data
% SYSTEM INTEGRATOR MANUAL (Dec 2014) pg 34-35

sect = struct;
len = 42;
off = len;

sect.Sync        = data(idx);
sect.Id          = data(idx+1);
sect.Size        = data(idx+2:idx+3); % uint16
sect.Time        = readClockData(data, idx+4);
% !!! Heading, pitch and roll can be negative => signed integer
block2           = data(idx+10:idx+23); % int16

sect.PressureMSB = data(idx+24); % uint8
% 8 bits status code http://cs.nortek.no/scripts/customer.fcgi?_sf=0&custSessionKey=&customerLang=en&noCookies=true&action=viewKbEntry&id=7
sect.Status      = uint8(flipud(str2num(dec2bin(data(idx+25), 8)'))); % str2num is used on purpose here. flipud is to bring bit0 first in the array.

block1           = data(idx+26:idx+29); % uint16
% !!! velocity can be negative
block3           = data(idx+30:idx+35); % int16
block4           = data(idx+36:idx+39); % uint8
sect.Checksum    = data(idx+40:idx+41); % uint16

% let's process uint16s in one call
blocks = bytecast([sect.Size; block1; sect.Checksum], 'L', 'uint16', cpuEndianness);
sect.Size        = blocks(1);
sect.PressureLSW = blocks(2);
sect.Temperature = blocks(3);
sect.Checksum    = blocks(4);

% let's process int16s in one call
blocks = bytecast([block2; block3], 'L', 'int16', cpuEndianness);
sect.Error       = blocks(1);
sect.Analn1      = blocks(2);
sect.Battery     = blocks(3);
sect.Analn2      = blocks(4);
sect.Heading     = blocks(5);
sect.Pitch       = blocks(6);
sect.Roll        = blocks(7);
sect.Vel1        = blocks(8);
sect.Vel2        = blocks(9);
sect.Vel3        = blocks(10);

% let's process uint8s in one call
blocks = bytecast([sect.PressureMSB; block4], 'L', 'uint8', cpuEndianness);
sect.PressureMSB = blocks(1);
sect.Amp1        = blocks(2);
sect.Amp2        = blocks(3);
sect.Amp3        = blocks(4);
sect.Fill        = blocks(5);
end

function [sect, len, off] = readAquadoppDiagHeader(data, idx, cpuEndianness)
%READAQUADOPPDIAGHEADER Reads an Aquadopp diagnostics header section.
% Id=0x06, Aquadopp Diagnostics Data Header
% SYSTEM INTEGRATOR MANUAL (Dec 2014) pg 35

sect = struct;
len = 36;
off = len;

sect.Sync      = data(idx);
sect.Id        = data(idx+1);
block1         = data(idx+2:idx+7); % uint16
block3         = data(idx+8:idx+11); % uint8
block2         = data(idx+12:idx+27); % uint16
% bytes 28-33 are spare
sect.Checksum  = data(idx+34:idx+35);

% let's process uint16s in one call
blocks = bytecast([block1; block2; sect.Checksum], 'L', 'uint16', cpuEndianness);
sect.Size      = blocks(1);
sect.Records   = blocks(2);
sect.Cell      = blocks(3);
sect.ProcMagn1 = blocks(4);
sect.ProcMagn2 = blocks(5);
sect.ProcMagn3 = blocks(6);
sect.ProcMagn4 = blocks(7);
sect.Distance1 = blocks(8);
sect.Distance2 = blocks(9);
sect.Distance3 = blocks(10);
sect.Distance4 = blocks(11);
sect.Checksum  = blocks(12);

% let's process uint8s in one call
blocks = bytecast(block3, 'L', 'uint8', cpuEndianness);
sect.Noise1    = blocks(1);
sect.Noise2    = blocks(2);
sect.Noise3    = blocks(3);
sect.Noise4    = blocks(4);
end

function [sect, len, off] = readAquadoppDiagnostics(data, idx, cpuEndianness)
%READAQUADOPPDIAGNOSTICS Reads an Aquadopp diagnostics data section.
% Id=0x80, Aquadopp Diagnostics Data
% SYSTEM INTEGRATOR MANUAL (Dec 2014) pg 36
%
% same structure as velocity section
[sect, len, off] = readAquadoppVelocity(data, idx, cpuEndianness);
end

function [sect, len, off] = readVectorVelocityHeader(data, idx, cpuEndianness)
%READVECTORVELOCITYHEADER Reads a Vector velocity data header section.
% Id=0x12, Vector Velocity Data Header
% SYSTEM INTEGRATOR MANUAL (Dec 2014) pg 36
sect = struct;
len = 42;
off = len;

sect.Sync         = data(idx);
sect.Id           = data(idx+1);
sect.Size         = data(idx+2:idx+3); % uint16
sect.Time         = readClockData(data, idx+4);
sect.NRecords     = data(idx+10:idx+11); % uint16
block             = data(idx+12:idx+19); % uint8
% bytes 20-39 are spare
sect.Checksum     = data(idx+40:idx+41); % uint16

% let's process uint16s in one call
blocks = bytecast([sect.Size; sect.NRecords; sect.Checksum], 'L', 'uint16', cpuEndianness);
sect.Size     = blocks(1);
sect.NRecords = blocks(2);
sect.Checksum = blocks(3);

% let's process uint8s in one call
blocks = bytecast(block, 'L', 'uint8', cpuEndianness);
sect.Noise1       = blocks(1);
sect.Noise2       = blocks(2);
sect.Noise3       = blocks(3);
sect.Noise4       = blocks(4);
sect.Correlation1 = blocks(5);
sect.Correlation2 = blocks(6);
sect.Correlation3 = blocks(7);
sect.Correlation4 = blocks(8);
end

function [sect, len, off] = readVectorVelocity(data, idx, cpuEndianness)
%READVECTORVELOCITY Reads a vector velocity data section.
% Id=0x10, Vector Velocity Data
% SYSTEM INTEGRATOR MANUAL (Dec 2014) pg 37
sect = struct;
len = 24;
off = len;

sect.Sync        = data(idx);
sect.Id          = data(idx+1);
block1           = data(idx+2:idx+5); % uint8
block            = data(idx+6:idx+9); % uint16
% !!! velocities can be negative
block2           = bytecast(data(idx+10:idx+15), 'L', 'int16', cpuEndianness);
sect.VelB1       = block2(1);
sect.VelB2       = block2(2);
sect.VelB3       = block2(3);
block3           = data(idx+16:idx+21); % uint8
sect.Checksum    = data(idx+22:idx+23); % uint16

% let's process uint16s in one call
blocks = bytecast([block; sect.Checksum], 'L', 'uint16', cpuEndianness);
sect.PressureLSW = blocks(1);
sect.Analn1      = blocks(2);
sect.Checksum    = blocks(3);

% let's process uint8s in one call
blocks = bytecast([block1; block3], 'L', 'uint8', cpuEndianness);
sect.Analn2LSB   = blocks(1);
sect.Count       = blocks(2);
sect.PressureMSB = blocks(3);
sect.Analn2MSB   = blocks(4);
sect.AmpB1       = blocks(5);
sect.AmpB2       = blocks(6);
sect.AmpB3       = blocks(7);
sect.CorrB1      = blocks(8);
sect.CorrB2      = blocks(9);
sect.CorrB3      = blocks(10);
end

function [sect, len, off] = readVectorSystem(data, idx, cpuEndianness)
%READVECTORSYSTEM Reads a vector system data section.
% Id=0x11, Vector System Data
% SYSTEM INTEGRATOR MANUAL (Dec 2014) pg 37-38
sect = struct;
len = 28;
off = len;

sect.Sync        = data(idx);
sect.Id          = data(idx+1);
sect.Size        = data(idx+2:idx+3); % uint16
sect.Time        = readClockData(data, idx+4);
% !!! Heading, pitch and roll can be negative
block            = bytecast(data(idx+10:idx+21), 'L', 'int16', cpuEndianness);
sect.Battery     = block(1);
sect.SoundSpeed  = block(2);
sect.Heading     = block(3);
sect.Pitch       = block(4);
sect.Roll        = block(5);
sect.Temperature = block(6);
sect.Error       = data(idx+22);
% 8 bits status code http://cs.nortek.no/scripts/customer.fcgi?_sf=0&custSessionKey=&customerLang=en&noCookies=true&action=viewKbEntry&id=7
sect.Status      = uint8(flipud(str2num(dec2bin(data(idx+23), 8)'))); % str2num is used on purpose here. flipud is to bring bit0 first in the array.
block            = data(idx+24:idx+27); % uint16

% let's process uint16s in one call
blocks = bytecast([sect.Size; block], 'L', 'uint16', cpuEndianness);
sect.Size        = blocks(1);
sect.Analn       = blocks(2);
sect.Checksum    = blocks(3);
end

function [sect, len, off] = readAquadoppProfilerVelocity(data, idx, cpuEndianness)
%READAQUADOPPPROFILERVELOCITY Reads an Aquadopp Profiler velocity data
% section.
% Id=0x21, Aquadopp Profiler Velocity Data
% SYSTEM INTEGRATOR MANUAL (Dec 2014) pg 42-43
sect = struct;

sect.Sync        = data(idx);
sect.Id          = data(idx+1);
sect.Size        = data(idx+2:idx+3); % uint16
sect.Time        = readClockData(data, idx+4);
% !!! Heading, pitch and roll can be negative
block1           = data(idx+10:idx+23); % int16

sect.PressureMSB = data(idx+24); % uint8
% 8 bits status code http://cs.nortek.no/scripts/customer.fcgi?_sf=0&custSessionKey=&customerLang=en&noCookies=true&action=viewKbEntry&id=7
sect.Status      = uint8(flipud(str2num(dec2bin(data(idx+25), 8)'))); % str2num is used on purpose here. flipud is to bring bit0 first in the array.
block2           = data(idx+26:idx+29); % uint16

% let's process uint16s in one call
blocks = bytecast([sect.Size; block2], 'L', 'uint16', cpuEndianness);
sect.Size        = blocks(1);
sect.PressureLSW = blocks(2);
sect.Temperature = blocks(3);

len              = sect.Size * 2;
off              = len;

% calculate number of cells from structure size
% (* 2 because size is specified in 16 bit words)
nCells = floor(((sect.Size) * 2 - (30+2)) / (3*2 + 3));

% offsets for each velocity/amplitude section
vel1Off = idx+30;
vel2Off = vel1Off + nCells*2;
vel3Off = vel2Off + nCells*2;
amp1Off = vel3Off + nCells*2;
amp2Off = amp1Off + nCells;
amp3Off = amp2Off + nCells;
csOff   = amp3Off + nCells;

% a fill byte is present if the number of cells is odd
if mod(nCells, 2), csOff = csOff + 1; end

% !!! velocity can be negative
block3 = data(vel1Off:vel3Off+nCells*2-1); % int16
block4 = data(amp1Off:amp3Off+nCells-1); % uint8

sect.Checksum = bytecast(data(csOff:csOff+1), 'L', 'uint16', cpuEndianness); % uint16

% let's process int16s in one call
blocks = bytecast([block1; block3], 'L', 'int16', cpuEndianness);
sect.Error       = blocks(1);
sect.Analn1      = blocks(2);
sect.Battery     = blocks(3);
sect.Analn2      = blocks(4);
sect.Heading     = blocks(5);
sect.Pitch       = blocks(6);
sect.Roll        = blocks(7);
sect.Vel1        = blocks(8          :8+nCells  -1);
sect.Vel2        = blocks(8+nCells   :8+nCells*2-1);
sect.Vel3        = blocks(8+nCells*2 :8+nCells*3-1);

% let's process uint8s in one call
blocks = bytecast([sect.PressureMSB; block4], 'L', 'uint8', cpuEndianness);
sect.PressureMSB = blocks(1);
sect.Amp1        = blocks(2           :2+nCells  -1);
sect.Amp2        = blocks(2+nCells    :2+nCells*2-1);
sect.Amp3        = blocks(2+nCells*2  :2+nCells*3-1);

end

function [sect, len, off] = readHRAquadoppProfile(data, idx, cpuEndianness)
%READHRAQUADOPPPROFILERVELOCITY Reads a HR Aquadopp Profile data section
% (pg 38 of system integrator manual).
% Id=0x2A, High Resolution Aquadopp Profiler Data
% SYSTEM INTEGRATOR MANUAL (Dec 2014) pg 43-45
sect = struct;

%   sect.Sync         = data(idx);
%   sect.Id           = data(idx+1);
%   sect.Size         = bytecast(data(idx+2:idx+3), 'L', 'uint16', cpuEndianness);
%   len               = sect.Size * 2;
%   off               = len;
%   sect.Time         = readClockData(data, idx+4);
%   % !!! Heading, pitch and roll can be negative
%   block             = bytecast(data(idx+10:idx+23), 'L', 'int16', cpuEndianness);
%   sect.Milliseconds = block(1);
%   sect.Error        = block(2);
%   sect.Battery      = block(3);
%   sect.Analn2_1     = block(4);
%   sect.Heading      = block(5);
%   sect.Pitch        = block(6);
%   sect.Roll         = block(7);
%   sect.PressureMSB  = bytecast(data(idx+24), 'L', 'uint8', cpuEndianness);
%   % byte 25 is a fill byte
%   block             = bytecast(data(idx+26:idx+33), 'L', 'uint16', cpuEndianness);
%   sect.PressureLSW  = block(1);
%   sect.Temperature  = block(2);
%   sect.Analn1       = block(3);
%   sect.Analn2_2     = block(4);
%   sect.Beams        = bytecast(data(idx+34), 'L', 'uint8', cpuEndianness);
%   sect.Cells        = bytecast(data(idx+35), 'L', 'uint8', cpuEndianness);
%   sect.VelLag2      = bytecast(data(idx+36:idx+41), 'L', 'uint16', cpuEndianness);
%   block             = bytecast(data(idx+42:idx+47), 'L', 'uint8', cpuEndianness);
%   sect.AmpLag2      = block(1:3);
%   sect.CorrLag2     = block(4:6);
%   % bytes 48-53 are spare
%   velOff  = idx     + 54;
%   ampOff  = velOff  + sect.Beams*sect.Cells*2;
%   corrOff = ampOff  + sect.Beams*sect.Cells;
%   csOff   = corrOff + sect.Beams*sect.Cells;
% 
%   nCells = floor(((sect.Size) * 2 - (30+2)) / (3*2 + 3));
%   
%   % fill byte if num cells is odd
%   if mod(nCells, 2), csOff = csOff + 1; end
% 
%   % velocity data
%   for k = 1:sect.Beams
% 
%     sOff = velOff + (k-1) * (sect.Cells * 2);
%     eOff = sOff + (sect.Cells * 2)-1;
%     % !!! velocity can be negative
%     sect.(['Vel' sprintf('%d', k)]) = ...
%       bytecast(data(sOff:eOff), 'L', 'int16', cpuEndianness);
%   end
% 
%   % amplitude data
%   for k = 1:sect.Beams
% 
%     sOff = ampOff + (k-1) * (sect.Cells);
%     eOff = sOff + (sect.Cells * 2)-1;
% 
%     sect.(['Amp' sprintf('%d', k)]) = ...
%       bytecast(data(sOff:eOff), 'L', 'uint8', cpuEndianness);
%   end
% 
%   % correlation data
%   for k = 1:sect.Beams
% 
%     sOff = corrOff + (k-1) * (sect.Cells);
%     eOff = sOff + (sect.Cells * 2)-1;
% 
%     sect.(['Corr' sprintf('%d', k)]) = ...
%       bytecast(data(sOff:eOff), 'L', 'uint8', cpuEndianness);
%   end
% 
%   sect.Checksum = bytecast(data(csOff:csOff+1), 'L', 'uint16', cpuEndianness);

% should be faster this way but need to validate results against previous
% algo above

sect.Sync         = data(idx);
sect.Id           = data(idx+1);
sect.Size         = data(idx+2:idx+3); % uint16

len              = bytecast(sect.Size, 'L', 'uint16', cpuEndianness) * 2;
off              = len;

% if a section (typically the last one) is shorter than expected, 
% abort further data read
if numel(data) < idx+len
    fprintf('%s\n', 'Warning : readHRAquadoppProfile bad idx/len');
    sect = [];
    return;
end

sect.Time         = readClockData(data, idx+4);
% !!! Heading, pitch and roll can be negative
block1            = data(idx+10:idx+23); % int16
sect.PressureMSB  = data(idx+24); % uint8
% byte 25 is a fill byte
block2            = data(idx+26:idx+33); % uint16

sect.Beams        = data(idx+34); % uint8
sect.Cells        = data(idx+35); % uint8
sect.VelLag2      = data(idx+36:idx+41); % uint16
block3            = data(idx+42:idx+47); % uint8

% let's process uint16s in one call
blocks = bytecast([sect.Size; block2; sect.VelLag2], 'L', 'uint16', cpuEndianness);
sect.Size         = blocks(1);
sect.PressureLSW  = blocks(2);
sect.Temperature  = blocks(3);
sect.Analn1       = blocks(4);
sect.Analn2       = blocks(5);
sect.VelLag2      = blocks(6);

% let's process int16s in one call
blocks = bytecast(block1, 'L', 'int16', cpuEndianness);
sect.Milliseconds = blocks(1);
sect.Error        = blocks(2);
sect.Battery      = blocks(3);
sect.SpeedOfSound = blocks(4);
sect.Heading      = blocks(5);
sect.Pitch        = blocks(6);
sect.Roll         = blocks(7);

% let's process uint8s in one call
blocks = bytecast([sect.PressureMSB; sect.Beams; sect.Cells; block3], 'L', 'uint8', cpuEndianness);
sect.PressureMSB  = blocks(1);
sect.Beams        = blocks(2);
sect.Cells        = blocks(3);
sect.AmpLag2      = blocks(4:6);
sect.CorrLag2     = blocks(7:9);

% bytes 48-53 are spare
velOff  = idx     + 54;
ampOff  = velOff  + sect.Beams*sect.Cells*2;
corrOff = ampOff  + sect.Beams*sect.Cells;
csOff   = corrOff + sect.Beams*sect.Cells;

sect.Checksum = bytecast(data(csOff:csOff+1), 'L', 'uint16', cpuEndianness); % uint16

% cellDataVel = [];
% cellDataAmp = [];
% cellDataCor = [];
% for k = 1:sect.Beams
%     % velocity data
%     sVelOff = velOff + (k-1) * (sect.Cells * 2);
%     eVelOff = sVelOff + (sect.Cells * 2)-1;
%     % !!! velocity can be negative
%     sect.(['Vel' sprintf('%d', k)]) = data(sVelOff:eVelOff); % int16
%     
%     % amplitude data
%     sAmpOff = ampOff + (k-1) * (sect.Cells);
%     eAmpOff = sAmpOff + sect.Cells - 1;
%     
%     sect.(['Amp' sprintf('%d', k)]) = data(sAmpOff:eAmpOff); % uint8
%     
%     % correlation data
%     sCorOff = corrOff + (k-1) * (sect.Cells);
%     eCorOff = sCorOff + sect.Cells - 1;
%     
%     sect.(['Corr' sprintf('%d', k)]) = data(sCorOff:eCorOff); % uint8
%     
%     cellDataVel = [cellDataVel; sect.(['Vel' sprintf('%d', k)])];
%     cellDataAmp = [cellDataAmp; sect.(['Amp' sprintf('%d', k)])];
%     cellDataCor = [cellDataCor; sect.(['Corr' sprintf('%d', k)])];
% end
% 
% % let's process int16s and uint8s in one call each
% cellDataVel = bytecast(cellDataVel, 'L', 'int16', cpuEndianness);
% blocksUint8 = bytecast([cellDataAmp; cellDataCor], 'L', 'uint8', cpuEndianness);
% for k = 1:sect.Beams
%     sect.(['Vel' sprintf('%d', k)]) = cellDataVel((k - 1)*sect.Cells + 1:k*sect.Cells);
%     sect.(['Amp' sprintf('%d', k)]) = blocksUint8((k - 1)*sect.Cells + 1:k*sect.Cells);
%     sect.(['Corr' sprintf('%d', k)]) = blocksUint8(sect.Beams*sect.Cells + 1:(k + sect.Beams)*sect.Cells);
% end

for k = 1:sect.Beams
    % velocity data, velocity can be negative, int16
    sVelOff = velOff + (k-1) * (sect.Cells * 2);
    eVelOff = sVelOff + (sect.Cells * 2)-1;
    sect.(['Vel' sprintf('%d', k)]) = bytecast(data(sVelOff:eVelOff), 'L', 'int16', cpuEndianness); % int16
    
    % amplitude data, uint8
    sAmpOff = ampOff + (k-1) * (sect.Cells);
    eAmpOff = sAmpOff + sect.Cells - 1;
    sect.(['Amp' sprintf('%d', k)]) = bytecast(data(sAmpOff:eAmpOff), 'L', 'uint8', cpuEndianness); % uint8
    
    % correlation data, uint8
    sCorOff = corrOff + (k-1) * (sect.Cells);
    eCorOff = sCorOff + sect.Cells - 1;
    sect.(['Corr' sprintf('%d', k)]) = bytecast(data(sCorOff:eCorOff), 'L', 'uint8', cpuEndianness); % uint8
end

end

function [sect, len, off] = readAwacVelocityProfile(data, idx, cpuEndianness)
%READAWACVELOCITYPROFILE Reads an AWAC Velocity Profile data section (pg 39
% of the system integrator manual).
% Id=0x20, AWAC Velocity Profile Data
% SYSTEM INTEGRATOR MANUAL (Dec 2014) pg 46-47
sect = struct;

sect.Sync        = data(idx);
sect.Id          = data(idx+1);
sect.Size        = bytecast(data(idx+2:idx+3), 'L', 'uint16', cpuEndianness); % uint16
len              = sect.Size * 2;
off              = len;
sect.Time        = readClockData(data, idx+4);
% !!! Heading, pitch and roll can be negative
block            = bytecast(data(idx+10:idx+23), 'L', 'int16', cpuEndianness); % int16
sect.Error       = block(1);
sect.Analn1      = block(2);
sect.Battery     = block(3);
sect.Analn2      = block(4);
sect.Heading     = block(5);
sect.Pitch       = block(6);
sect.Roll        = block(7);
sect.PressureMSB = bytecast(data(idx+24), 'L', 'uint8', cpuEndianness);
% 8 bits status code http://cs.nortek.no/scripts/customer.fcgi?_sf=0&custSessionKey=&customerLang=en&noCookies=true&action=viewKbEntry&id=7
sect.Status      = uint8(flipud(str2num(dec2bin(data(idx+25), 8)'))); % str2num is used on purpose here. flipud is to bring bit0 first in the array.
block            = bytecast(data(idx+ 26:idx+29), 'L', 'uint16', cpuEndianness); % uint16
sect.PressureLSW = block(1);
sect.Temperature = block(2);
% bytes 30-117 are spare

% calculate number of cells from structure size
% (size is in 16 bit words)
nCells = floor(((sect.Size) * 2 - (118 + 2)) / (3*2 + 3));

vel1Off = idx+118;
vel2Off = vel1Off + nCells*2;
vel3Off = vel2Off + nCells*2;
amp1Off = vel3Off + nCells*2;
amp2Off = amp1Off + nCells;
amp3Off = amp2Off + nCells;
csOff   = amp3Off + nCells;

% fill value is included if number of cells is odd
if mod(nCells, 2), csOff = csOff + 1; end

lastIdx = csOff+2;

if lastIdx <= length(data) % sometimes dataset are cut before being properly ended?
    % !!! Velocity can be negative
    sect.Vel1 = bytecast(data(vel1Off:vel1Off+nCells*2-1), 'L', 'int16', cpuEndianness); % U comp (East)  % int16
    sect.Vel2 = bytecast(data(vel2Off:vel2Off+nCells*2-1), 'L', 'int16', cpuEndianness); % V comp (North) % int16
    sect.Vel3 = bytecast(data(vel3Off:vel3Off+nCells*2-1), 'L', 'int16', cpuEndianness); % W comp (up)    % int16
    sect.Amp1 = bytecast(data(amp1Off:amp1Off+nCells-1),   'L', 'uint8', cpuEndianness);
    sect.Amp2 = bytecast(data(amp2Off:amp2Off+nCells-1),   'L', 'uint8', cpuEndianness);
    sect.Amp3 = bytecast(data(amp3Off:amp3Off+nCells-1),   'L', 'uint8', cpuEndianness);
    
    sect.Checksum = bytecast(data(csOff:csOff+1), 'L', 'uint16', cpuEndianness); % uint16
else
    fprintf('%s\n', ['Warning : readAwacVelocityProfile bad end of file with ' ...
        'expected last index greater than file size. Give up reading this ensemble.']);
    sect = [];
    return;
end
if lastIdx < length(data) 
if data(lastIdx) ~= 165 % hex a5
    fprintf('%s\n', ['Warning : readAwacVelocityProfile bad end sync (idx '...
        num2str(lastIdx) ', val ' num2str(data(lastIdx)) ')']);
    return;
end
end

% variant below is twice slower so we're keeping the original code

%   sect.Sync        = data(idx);
%   sect.Id          = data(idx+1);
%   sect.Size        = data(idx+2:idx+3); % uint16
%
%   sect.Time        = readClockData(data, idx+4);
%
%   sect.Status      = data(idx+25);
%   block2           = data(idx+ 26:idx+29); % uint16
%   % bytes 30-117 are spare
%
%   % let's process uint16s in one call
%   blocks = bytecast([sect.Size; block2], 'L', 'uint16', cpuEndianness);
%   sect.Size         = blocks(1);
%   sect.PressureLSW  = blocks(2);
%   sect.Temperature  = blocks(3);
%
%   len               = sect.Size * 2;
%   off               = len;
%
%   % !!! Heading, pitch and roll can be negative
%   block1           = data(idx+10:idx+23); % int16
%
%   sect.PressureMSB = data(idx+24); % uint8
%
%   % calculate number of cells from structure size
%   % (size is in 16 bit words)
%   nCells = floor((len - (118 + 2)) / (3*2 + 3));
%
%   vel1Off = idx + 118;
%   vel2Off = vel1Off + nCells*2;
%   vel3Off = vel2Off + nCells*2;
%   amp1Off = vel3Off + nCells*2;
%   amp2Off = amp1Off + nCells;
%   amp3Off = amp2Off + nCells;
%   csOff   = amp3Off + nCells;
%
%   % fill value is included if number of cells is odd
%   if mod(nCells, 2), csOff = csOff + 1; end
%
%   % !!! Velocity can be negative
%   sect.Vel1 = data(vel1Off:vel1Off+nCells*2-1); % U comp (East)  % int16
%   sect.Vel2 = data(vel2Off:vel2Off+nCells*2-1); % V comp (North) % int16
%   sect.Vel3 = data(vel3Off:vel3Off+nCells*2-1); % W comp (up)    % int16
%   sect.Amp1 = data(amp1Off:amp1Off+nCells-1);
%   sect.Amp2 = data(amp2Off:amp2Off+nCells-1);
%   sect.Amp3 = data(amp3Off:amp3Off+nCells-1);
%
%   sect.Checksum = bytecast(data(csOff:csOff+1), 'L', 'uint16', cpuEndianness); % uint16
%
%   % let's process int16s in one call
%   blocks = bytecast([block1; sect.Vel1; sect.Vel2; sect.Vel3], 'L', 'int16', cpuEndianness);
%   sect.Error       = blocks(1);
%   sect.Analn1      = blocks(2);
%   sect.Battery     = blocks(3);
%   sect.Analn2      = blocks(4);
%   sect.Heading     = blocks(5);
%   sect.Pitch       = blocks(6);
%   sect.Roll        = blocks(7);
%   sect.Vel1        = blocks(8            :8 +   nCells - 1);
%   sect.Vel2        = blocks(8 +   nCells :8 + 2*nCells - 1);
%   sect.Vel3        = blocks(8 + 2*nCells :8 + 3*nCells - 1);
%
%   % let's process uint8s in one call
%   blocks = bytecast([sect.PressureMSB; sect.Amp1; sect.Amp2; sect.Amp3], 'L', 'uint8', cpuEndianness);
%   sect.PressureMSB = blocks(1);
%   sect.Amp1 = blocks(2              :2 +   nCells - 1);
%   sect.Amp2 = blocks(2 +   nCells   :2 + 2*nCells - 1);
%   sect.Amp3 = blocks(2 + 2*nCells   :2 + 3*nCells - 1);
end

function [sect, len, off] = readAwacWaveHeader(data, idx, cpuEndianness)
%READAWACWAVEHEADER Reads an AWAC wave header section.
% Id=0x31, Awac Wave Data Header
% SYSTEM INTEGRATOR MANUAL (Dec 2014) pg 49
%sect = struct;
len = 60;
off = len;
sect = [];
%   sect.Sync         = data(idx);
%   sect.Id           = data(idx+1);
%   sect.Size         = bytecast(data(idx+2:idx+3), 'L', 'uint16', cpuEndianness);
%   sect.Time         = readClockData(data, idx+4);
%   block             = bytecast(data(idx+10:idx+17), 'L', 'uint16', cpuEndianness);
%   sect.NRecords     = block(1);
%   sect.Blanking     = block(2);
%   sect.Battery      = block(3);
%   sect.SoundSpeed   = block(4);
%   block             = bytecast(data(idx+18:idx+23), 'L', 'int16', cpuEndianness);
%   sect.Heading      = block(1);
%   sect.Pitch        = block(2);
%   sect.Roll         = block(3);
%   block             = bytecast(data(idx+24:idx+31), 'L', 'uint16', cpuEndianness);
%   sect.MinPress     = block(1);
%   sect.HMaxPress    = block(2);
%   sect.Temperature  = block(3);
%   sect.CellSize     = block(4);
%   sect.Noise1       = bytecast(data(idx+32), 'L', 'uint8', cpuEndianness);
%   sect.Noise2       = bytecast(data(idx+33), 'L', 'uint8', cpuEndianness);
%   sect.Noise3       = bytecast(data(idx+34), 'L', 'uint8', cpuEndianness);
%   sect.Noise4       = bytecast(data(idx+35), 'L', 'uint8', cpuEndianness);
%   block             = bytecast(data(idx+36:idx+43), 'L', 'uint16', cpuEndianness);
%   sect.ProcMagn1    = block(1);
%   sect.ProcMagn2    = block(2);
%   sect.ProcMagn3    = block(3);
%   sect.ProcMagn4    = block(4);
%   % bytes 44-57 are spare
%   sect.Checksum     = bytecast(data(idx+58:idx+59), 'L', 'uint16', cpuEndianness);
end

function [sect, len, off] = readAwacWaveData(data, idx, cpuEndianness)
%READAWACWAVEDATA Reads an AWAC Wave data section.
% Id=0x30, Awac Wave Data
% SYSTEM INTEGRATOR MANUAL (Dec 2014) pg 49
len = 24;
off = len;
sect = [];

%   sect.Sync        = data(idx);
%   sect.Id          = data(idx+1);
%   sect.Size        = bytecast(data(idx+2:idx+3), 'L', 'uint16', cpuEndianness);
%   block            = bytecast(data(idx+4:idx+9), 'L', 'uint16', cpuEndianness);
%   sect.Pressure    = block(1);
%   sect.Distance    = block(2);
%   sect.Analn       = block(3);
%   % !!! velocity can be negative
%   block            = bytecast(data(idx+10:idx+17), 'L', 'int16', cpuEndianness);
%   sect.Vel1        = block(1);
%   sect.Vel2        = block(2);
%   sect.Vel3        = block(3);
%   sect.Vel4        = block(4);
%   sect.Amp1        = bytecast(data(idx+18), 'L', 'uint8', cpuEndianness);
%   sect.Amp2        = bytecast(data(idx+19), 'L', 'uint8', cpuEndianness);
%   sect.Amp3        = bytecast(data(idx+20), 'L', 'uint8', cpuEndianness);
%   sect.Amp4        = bytecast(data(idx+21), 'L', 'uint8', cpuEndianness);
%   sect.Checksum    = bytecast(data(idx+22:idx+23), 'L', 'uint16', cpuEndianness);
end

function [sect, len, off] = readAwacWaveDataSUV(data, idx, cpuEndianness)
%READAWACWAVEDATASUV Reads an AWAC Wave data SUV section.
% Id=0x36, Awac Wave Data for SUV
% SYSTEM INTEGRATOR MANUAL (Dec 2014) pg 49-50

sect = struct;
len = 24;
off = len;
sect = [];

% sect.Sync        = data(idx);
% sect.Id          = data(idx+1);
% block            = bytecast(data(idx+2:idx+7), 'L', 'uint16', cpuEndianness);
% sect.Heading     = block(1);
% sect.Pressure    = block(2);
% sect.Distance    = block(3);
% sect.Pitch = data(idx+8);
% sect.Roll = data(idx+9);
% % !!! velocity can be negative
% block            = bytecast(data(idx+9:idx+17), 'L', 'int16', cpuEndianness);
% sect.Vel1        = block(1);
% sect.Vel2        = block(2);
% sect.Vel3        = block(3);
% sect.Vel4Distance2 = block(4);
% sect.Amp1        = bytecast(data(idx+18), 'L', 'uint8', cpuEndianness);
% sect.Amp2        = bytecast(data(idx+19), 'L', 'uint8', cpuEndianness);
% sect.Amp3        = bytecast(data(idx+20), 'L', 'uint8', cpuEndianness);
% sect.Amp4ASTQual = bytecast(data(idx+21), 'L', 'uint8', cpuEndianness);
% sect.Checksum    = bytecast(data(idx+22:idx+23), 'L', 'uint16', cpuEndianness);
end

function [sect, len, off] = readAwacStageData(data, idx, cpuEndianness)
%READAWACSTAGEDATA Reads an AWAC Stage data section.
% Id=0x42, Awac Stage Data
% SYSTEM INTEGRATOR MANUAL (Dec 2014) pg 48

sect = struct;

sect.Size        = bytecast(data(idx+2:idx+3), 'L', 'uint16', cpuEndianness);
len              = sect.Size * 2;
off              = len;
sect = [];
%warning('readAwacStageData not implemented yet.');

%   sect.Blanking    = bytecast(data(idx+4:idx+5), 'L', 'uint16', cpuEndianness);
%   % !!! Heading, pitch and roll can be negative
%   block            = bytecast(data(idx+6:idx+9), 'L', 'int16', cpuEndianness);
%   sect.Pitch       = block(1);
%   sect.Roll        = block(2);
%   block            = bytecast(data(idx+10:idx+21), 'L', 'uint16', cpuEndianness);
%   sect.Pressure    = block(1);
%   sect.Stage       = block(2);
%   sect.Quality     = block(3);
%   sect.SoundSpeed  = block(4);
%   sect.StageP      = block(5);
%   % bytes 22-31 are spare
%
%   % calculate number of cells from structure size
%   % (size is in 16 bit words)
%   nCells = floor(((sect.Size) * 2 - (32 + 2)));
%
%   ampOff = idx+32;
%   csOff  = ampOff + nCells;
%
%   % fill value is included if number of cells is odd
%   if mod(nCells, 2), csOff = csOff + 1; end
%
%   sect.Amp = bytecast(data(ampOff:ampOff+nCells-1),   'L', 'uint8', cpuEndianness);
%
%   sect.Checksum = bytecast(data(csOff:csOff+1), 'L', 'uint16', cpuEndianness);
end

function [sect, len, off] = readContinental(data, idx, cpuEndianness)
%READCONTINENTAL Reads a Continental Data section.
% Id=0x42, Continental Data
% SYSTEM INTEGRATOR MANUAL (Dec 2014) pg 50
% structure is same as awac velocity profile data
[sect, len, off] = readAwacVelocityProfile(data, idx, cpuEndianness);
end


function [sect, len, off] = readVectrinoVelocityHeader(data, idx, cpuEndianness)
%READVECTRINOVELOCITYHEADER Reads a Vectrino velocity data header section
% (pg 42 of system integrator manual).
% Id=0x12, Vectrino velocity data header
% SYSTEM INTEGRATOR MANUAL (Dec 2014) pg 57-58
sect = struct;
len = 42;
off = len;

sect.Sync         = data(idx);
sect.Id           = data(idx+1);
block             = bytecast(data(idx+2:idx+11), 'L', 'uint16', cpuEndianness);
sect.Size         = block(1);
sect.Distance     = block(2);
sect.DistQuality  = block(3);
sect.Lag1         = block(4);
sect.Lag2         = block(5);
sect.Noise1       = bytecast(data(idx+12), 'L', 'uint8', cpuEndianness);
sect.Noise2       = bytecast(data(idx+13), 'L', 'uint8', cpuEndianness);
sect.Noise3       = bytecast(data(idx+14), 'L', 'uint8', cpuEndianness);
sect.Noise4       = bytecast(data(idx+15), 'L', 'uint8', cpuEndianness);
sect.Correlation1 = bytecast(data(idx+16), 'L', 'uint8', cpuEndianness);
sect.Correlation2 = bytecast(data(idx+17), 'L', 'uint8', cpuEndianness);
sect.Correlation3 = bytecast(data(idx+18), 'L', 'uint8', cpuEndianness);
sect.Correlation4 = bytecast(data(idx+19), 'L', 'uint8', cpuEndianness);
block             = bytecast(data(idx+20:idx+23), 'L', 'uint16', cpuEndianness);
sect.Temperature  = block(1);
sect.SoundSpeed   = block(2);
sect.AmpZ01       = bytecast(data(idx+24), 'L', 'uint8', cpuEndianness);
sect.AmpZ02       = bytecast(data(idx+25), 'L', 'uint8', cpuEndianness);
sect.AmpZ03       = bytecast(data(idx+26), 'L', 'uint8', cpuEndianness);
sect.AmpZ04       = bytecast(data(idx+27), 'L', 'uint8', cpuEndianness);
sect.AmpX11       = bytecast(data(idx+28), 'L', 'uint8', cpuEndianness);
sect.AmpX12       = bytecast(data(idx+29), 'L', 'uint8', cpuEndianness);
sect.AmpX13       = bytecast(data(idx+30), 'L', 'uint8', cpuEndianness);
sect.AmpX14       = bytecast(data(idx+31), 'L', 'uint8', cpuEndianness);
sect.AmpZ0PLag11  = bytecast(data(idx+32), 'L', 'uint8', cpuEndianness);
sect.AmpZ0PLag12  = bytecast(data(idx+33), 'L', 'uint8', cpuEndianness);
sect.AmpZ0PLag13  = bytecast(data(idx+34), 'L', 'uint8', cpuEndianness);
sect.AmpZ0PLag14  = bytecast(data(idx+35), 'L', 'uint8', cpuEndianness);
sect.AmpZ0PLag21  = bytecast(data(idx+36), 'L', 'uint8', cpuEndianness);
sect.AmpZ0PLag22  = bytecast(data(idx+37), 'L', 'uint8', cpuEndianness);
sect.AmpZ0PLag23  = bytecast(data(idx+38), 'L', 'uint8', cpuEndianness);
sect.AmpZ0PLag24  = bytecast(data(idx+39), 'L', 'uint8', cpuEndianness);
sect.Checksum     = bytecast(data(idx+40:idx+41), 'L', 'uint16', cpuEndianness);
end

function [sect, len, off] = readVectrinoVelocity(data, idx, cpuEndianness)
%READVECTRINOVELOCITY Reads a Vectrino Velocity data section (pg 43 of
% system integrator manual).
% Id=0x51, Vectrino velocity data Size Name Offset Description
% SYSTEM INTEGRATOR MANUAL (Dec 2014) pg 58
sect = struct;

sect.Sync   = data(idx);
sect.Id     = data(idx+1);
sect.Size   = 0;           % no size field in spec

% [exvcccbb] status bits, where
% e = error (0 = no error, 1 = error condition)
% x = not used
% v = velocity scaling (0 = mm/s, 1 = 0.1mm/s)
% ccc = #cells -1
% bb = #beams -1
sect.Status = dec2bin(data(idx+2), 8);

sect.Count  = data(idx+3);

% number of cells/beams is in status byte
nBeams = bitor(sect.Status, 3) + 1;
nCells = bitor(bitshift(sect.Status, 2), 7) + 1;

len = 4 + (4*2 + 4 + 4)*nCells + 2;
sect.Size = len;
off = len;

velOff  = idx + 4;
ampOff  = velOff  + nCells*nBeams*2;
corrOff = ampOff  + nCells*nBeams;
csOff   = corrOff + nCells*nBeams;

% velocity
for k = 1:nBeams
    
    sOff = velOff + (k-1) * (nCells * 2);
    eOff = sOff + (nCells * 2) - 1;
    % !!! Velocity can be negative
    sect.(['Vel' sprintf('%d', k)]) = ...
        bytecast(data(sOff:eOff), 'L', 'int16', cpuEndianness);
end

% amplitude
for k = 1:nBeams
    
    sOff = ampOff + (k-1) * nCells;
    eOff = sOff + nCells - 1;
    
    sect.(['Amp' sprintf('%d', k)]) = ...
        bytecast(data(sOff:eOff), 'L', 'uint8', cpuEndianness);
end

% correlation
for k = 1:nBeams
    
    sOff = corrOff + (k-1) * nCells;
    eOff = sOff + nCells - 1;
    
    vel.(['Corr' sprintf('%d', k)]) = ...
        bytecast(data(sOff:eOff), 'L', 'uint8', cpuEndianness);
end

sect.Checksum = bytecast(data(csOff:csOff+1), 'L', 'uint16', cpuEndianness);

end

function [sect, len, off] = readVectrinoDistance(data, idx, cpuEndianness)
%READVECTRINODISTANCE Reads a Vectrino distance data section.
% Id=0x02, Vectrino distance data
% SYSTEM INTEGRATOR MANUAL (Dec 2014) pg 58-59
sect = struct;
len = 16;
off = len;

sect.Sync        = data(idx);
sect.Id          = data(idx+1);
block            = bytecast(data(idx+2:idx+15), 'L', 'uint16', cpuEndianness);
sect.Size        = block(1);
sect.Temperature = block(2);
sect.SoundSpeed  = block(3);
sect.Distance    = block(4);
sect.DistQuality = block(5);
% bytes 12-13 are spare
sect.Checksum    = block(7);

end

function [sect, len, off] = readGeneric(data, idx, cpuEndianness)
%READGENERIC Skip past an unknown sector type

Sync        = data(idx);
Id          = data(idx+1);
Size   = bytecast(data(idx+2:idx+3), 'L', 'uint16', cpuEndianness);
len              = Size * 2;
off              = len;
sect = [];
%warning(['Skipping sector type ' num2str(Id) ' at ' num2str(idx) ' size ' num2str(Size)]);
disp(['Skipping sector type ' num2str(Id) ' at ' num2str(idx) ' size ' num2str(Size)]);

end

function [sect, len, off] = readAwacAST(data, idx, cpuEndianness)
%READAWACAST
% Awac Cleaned Up AST Time Series
% Id=0x65 SYSTEM INTEGRATOR MANUAL (Dec 2014) pg 54-55

sect.Sync   = data(idx);
sect.Id     = data(idx+1);
sect.Size   = bytecast(data(idx+2:idx+3), 'L', 'uint16', cpuEndianness);
sect.Time   = readClockData(data, idx+4);
len         = sect.Size * 2;
off         = len;

sect.Samples   = bytecast(data(idx+10:idx+11), 'L', 'uint16', cpuEndianness);
sect.Spare   = bytecast(data(idx+12:idx+23), 'L', 'uint8', cpuEndianness);

astOff = idx+24;
csOff   = astOff + (sect.Samples*2)*2 + 1;
sect.ast = bytecast(data(astOff:csOff-1), 'L', 'uint16', cpuEndianness);

sect.Checksum  = bytecast(data(csOff:csOff+1), 'L', 'uint16', cpuEndianness);

sect = [];
%warning(['Skipping sector type ' num2str(Id) ' at ' num2str(idx) ' size ' num2str(Size)]);
%disp(['Skipping sector type ' num2str(Id) ' at ' num2str(idx) ' size ' num2str(Size)]);

end

function [sect, len, off] = readAwacProcessedVelocity(data, idx, cpuEndianness)
% Awac Processed Velocity Profile Data
% Id=0x6A SYSTEM INTEGRATOR MANUAL (Dec 2014) pg 55-56

sect.Sync    = data(idx);
sect.Id      = data(idx+1);
sect.Size    = bytecast(data(idx+2:idx+3), 'L', 'uint16', cpuEndianness);
len          = sect.Size * 2;
off          = len;
 
sect.Time    = readClockData(data, idx+4);
milliSeconds = bytecast(data(idx+10:idx+11), 'L', 'uint16', cpuEndianness);
sect.Time    = sect.Time + (milliSeconds/1000/60/60/24);

sect.Beams   = bytecast(data(idx+12), 'L', 'uint8', cpuEndianness);
nCells       = bytecast(data(idx+13), 'L', 'uint8', cpuEndianness);
sect.nCells  = nCells;

% velocity
vel1Off = idx+14;
vel2Off = vel1Off + nCells*2;
vel3Off = vel2Off + nCells*2;

% signal to noise ratio
snr1Off = vel3Off + nCells*2;
snr2Off = snr1Off + nCells*2;
snr3Off = snr2Off + nCells*2;

% standard deviation
std1Off = snr3Off + nCells*2;
std2Off = std1Off + nCells*2;
std3Off = std2Off + nCells*2;

% error code
erc1Off = std3Off + nCells*2;
erc2Off = erc1Off + nCells;
erc3Off = erc2Off + nCells;

spdOff  = erc3Off + nCells;   % speed
dirOff  = spdOff  + nCells*2; % direction
vdtOff  = dirOff  + nCells*2; % vertical distance
percOff = vdtOff  + nCells*2; % profile error code
qcOff   = percOff + nCells;   % qc flag

csOff   = qcOff   + nCells;   % checksum
if mod(nCells, 2), csOff = csOff + 1; end % unconfirmed but was the only way to make this work

sect.Vel1 = bytecast(data(vel1Off:vel1Off+nCells*2-1), 'L', 'int16', cpuEndianness); % U comp (East)  % int16
sect.Vel2 = bytecast(data(vel2Off:vel2Off+nCells*2-1), 'L', 'int16', cpuEndianness); % V comp (North) % int16
sect.Vel3 = bytecast(data(vel3Off:vel3Off+nCells*2-1), 'L', 'int16', cpuEndianness); % W comp (up)    % int16

sect.Snr1 = bytecast(data(snr1Off:snr1Off+nCells*2-1), 'L', 'uint16', cpuEndianness);
sect.Snr2 = bytecast(data(snr2Off:snr2Off+nCells*2-1), 'L', 'uint16', cpuEndianness);
sect.Snr3 = bytecast(data(snr3Off:snr3Off+nCells*2-1), 'L', 'uint16', cpuEndianness);

sect.Std1 = bytecast(data(std1Off:std1Off+nCells*2-1), 'L', 'uint16', cpuEndianness);
sect.Std2 = bytecast(data(std2Off:std2Off+nCells*2-1), 'L', 'uint16', cpuEndianness);
sect.Std3 = bytecast(data(std3Off:std3Off+nCells*2-1), 'L', 'uint16', cpuEndianness);

sect.Erc1 = bytecast(data(erc1Off:erc1Off+nCells-1),   'L', 'uint8', cpuEndianness);
sect.Erc2 = bytecast(data(erc2Off:erc2Off+nCells-1),   'L', 'uint8', cpuEndianness);
sect.Erc3 = bytecast(data(erc3Off:erc3Off+nCells-1),   'L', 'uint8', cpuEndianness);

sect.speed            = bytecast(data(spdOff:spdOff+nCells*2-1), 'L', 'uint16', cpuEndianness);
sect.direction        = bytecast(data(dirOff:dirOff+nCells*2-1), 'L', 'uint16', cpuEndianness);
sect.verticalDistance = bytecast(data(vdtOff:vdtOff+nCells*2-1), 'L', 'uint16', cpuEndianness);
sect.profileErrorCode = bytecast(data(percOff:percOff+nCells-1), 'L', 'uint8',  cpuEndianness);
sect.qcFlag           = bytecast(data(qcOff:qcOff+nCells-1),     'L', 'uint8',  cpuEndianness);
sect.Checksum         = bytecast(data(csOff:csOff+1),            'L', 'uint16', cpuEndianness);

end

function [sect, len, off] = readVectorProbeCheck(data, idx, cpuEndianness)
%READVECTORPROBECHECK Reads an Vector Probe Check section.
% Id=0x07, Vector and Vectrino Probe Check Data
% SYSTEM INTEGRATOR MANUAL (Dec 2014) pg 38
% The structure of the probe check is the same for both Vectrino and Vector. 
% The difference is that a Vector has 3 beams and 300 samples, while the 
% Vectrino has 4 beams and 500 samples

Size   = bytecast(data(idx+2:idx+3), 'L', 'uint16', cpuEndianness);
len              = Size * 2;
off              = len;
sect = [];
%warning('readVectorProbeCheck not implemented yet.');

end

function [sect, len, off] = readWaveParameterEstimates(data, idx, cpuEndianness)
%READWAVEPARAMETERESTIMATES Reads an AWAC Wave Parameter Estimates section.
% Id=0x60, Wave parameter estimates
% SYSTEM INTEGRATOR MANUAL (Dec 2014) pg 52-53

len = 80;
off = len;
sect = [];
%warning('readWaveParameterEstimates not implemented yet.');

% % Need to confirm below is correct
% sect = struct;
% sect.Sync   = data(idx);
% sect.Id     = data(idx+1);
% sect.Size   = bytecast(data(idx+2:idx+3), 'L', 'uint16', cpuEndianness);
% sect.clock = readClockData(data, idx+4); %clock layout needs checking
% sect.hSpectrumTyp = bytecast(data(idx+10), 'L', 'uint8', cpuEndianness);
% sect.hProcMethod = bytecast(data(idx+11), 'L', 'uint8', cpuEndianness);
% block = bytecast(data(idx+12:idx+33), 'L', 'uint16', cpuEndianness);
% sect.Hm0 = block(1) / 1000; %metre
% sect.H3 = block(2) /1000; %metre
% sect.H10 = block(3) /1000; %metre
% sect.Hmax = block(4) /1000; %metre
% sect.Tm02 = block(5) * 0.01; %seconds
% sect.Tp = block(6) * 0.01; %seconds
% sect.DirTp = block(7) * 0.01; %seconds
% sect.DirMean = block(8) * 0.01; %seconds
% sect.SprTp = block(9) * 0.01; %seconds
% sect.DirMean = block(10) * 0.01; %degrees
% sect.UI = block(11) / 65535;
% sect.hPressureMean = bytecast(data(idx+34:idx+37), 'L', 'uint32', cpuEndianness) * 0.001; %dbar
% sect.NumNoDet = bytecast(data(idx+38:idx+39), 'L', 'uint16', cpuEndianness);
% sect.NumBadDet = bytecast(data(idx40:idx+42), 'L', 'uint16', cpuEndianness);
% sect.CurSpeedMean = bytecast(data(idx42:idx+43), 'L', 'uint16', cpuEndianness) /1000; %m/s
% sect.CurDirMean = bytecast(data(idx43:idx+44), 'L', 'uint16', cpuEndianness) * 0.01; %degrees
% sect.hError = bytecast(data(idx46:idx+49), 'L', 'uint32', cpuEndianness);
% sect.ASTdistMean = bytecast(data(idx50:idx+53), 'L', 'uint32', cpuEndianness) / 1000; %metre
% sect.ICEdistMean = bytecast(data(idx54:idx+57), 'L', 'uint32', cpuEndianness) / 1000; %metre
% block = bytecast(data(idx+60:idx+67), 'L', 'uint16', cpuEndianness);
% sect.fregDirAmbLimit = block(1) * 0.001; %hertz
% set.T3 = block(2); %seconds
% sect.T10 = block(3) * 0.1; %sec
% sect.Tmax = block(4); %seconds
% sect.Hmean = block(5) / 1000; %metre
% % bytes idx+88 to idx+77 spare
% sect.checksum = bytecast(data(idx+78:idx+79), 'L', 'uint16', cpuEndianness);

end

function [sect, len, off] = readWaveBandEstimates(data, idx, cpuEndianness)
%READWAVEBANDESTIMATES Reads an AWAC Wave Parameter Estimates section.
% Id=0x61, Wave band estimates
% SYSTEM INTEGRATOR MANUAL (Dec 2014) pg 53

len = 48;
off = len;
sect = [];
%warning('readWaveBandEstimates not implemented yet.');

% % Need to confirm below is correct
% sect = struct;
% sect.Sync   = data(idx);
% sect.Id     = data(idx+1);
% sect.Size   = bytecast(data(idx+2:idx+3), 'L', 'uint16', cpuEndianness);
% sect.Time   = readClockData(data, idx+4);
% sect.hSpectrumType     = data(idx+10);
% sect.hProcMethod     = data(idx+11);
% block              = bytecast(data(idx+12:idx+27), 'L', 'uint16', cpuEndianness);
% sect.LowFrequency  = block(1) * 0.001;
% sect.HighFrequency = block(2) * 0.001;
% sect.Hm0 = block(3)/1000;
% sect.Tm02 = block(4) * 0.01;
% sect.Tp = block(5) * 0.01;
% sect.DirTp = block(6) * 0.01;
% sect.DirMean = block(7) * 0.01;
% sect.SprTp = block(8) * 0.01;
% sect.hError = bytecast(data(idx+28:idx+31), 'L', 'uint32', cpuEndianness);
% % bytes 32 to 45 spare
% sect.checksum = bytecast(data(idx+46:idx+47), 'L', 'uint16', cpuEndianness);

end

function [sect, len, off] = readWaveEnergySpectrum(data, idx, cpuEndianness)
%READWAVEENERGYSPECTRUM Reads an AWAC Wave Parameter Estimates section.
% Id=0x62, Wave energy spectrum
% SYSTEM INTEGRATOR MANUAL (Dec 2014) pg 53-54

Size   = bytecast(data(idx+2:idx+3), 'L', 'uint16', cpuEndianness);
len              = Size * 2;
off              = len;
sect = [];
%warning('readWaveEnergySpectrum not implemented yet.');

% % work this out later
% sect = struct;
% sect.Sync   = data(idx);
% sect.Id     = data(idx+1);
% sect.Size   = bytecast(data(idx+2:idx+3), 'L', 'uint16', cpuEndianness);
% sect.Time   = readClockData(data, idx+4);
% sect.cSpectrumType     = data(idx+10);
% % idx+11 is cSpare
% block              = bytecast(data(idx+12:idx+19), 'L', 'uint16', cpuEndianness);
% sect.hNumSpectrum  = block(1);
% sect.LowFrequency  = block(2);
% sect.HighFrequency = block(3);
% sect.StepFrequency = block(4);
% % idx+20 to idx+37 are Spares
% sect.hEnergyMultiplier = bytecast(data(idx38:idx+41), 'L', 'uint32', cpuEndianness);
% % read in Energy values
%
% sect.Checksum     = bytecast(data(len+1:len+2), 'L', 'uint16', cpuEndianness);

end

function [sect, len, off] = readWaveFourierCoefficentSpectrum(data, idx, cpuEndianness)
%READWAVEFOURIERCOEFFICIENTSSPECTRUM Reads an AWAC Wave Fourier Coefficient Spectrum section.
% Id=0x63, Wave fourier coefficient spectrum
% SYSTEM INTEGRATOR MANUAL (Dec 2014) pg 54

len = 816;
off = len;
sect = [];
%warning('readWaveFourierCoefficentSpectrum not implemented yet.');

% % Need to confirm below is correct
% sect = struct;
% sect.Sync   = data(idx);
% sect.Id     = data(idx+1);
% sect.Size   = bytecast(data(idx+2:idx+3), 'L', 'uint16', cpuEndianness);
% sect.Time   = readClockData(data, idx+4);
% % idx+10 is cSpare
% sect.cProcMethod     = data(idx+11);
% block              = bytecast(data(idx+12:idx+19), 'L', 'uint16', cpuEndianness);
% sect.NumSpectrum  = block(1);
% sect.LowFrequency  = block(2) * 0.001; %Hz
% sect.HighFrequency = block(3) * 0.001; %Hz
% sect.StepFrequency = block(4) * 0.001; %Hz
% % idx+20 to idx+29 are Spares
% sect.A1 = bytecast(data(idx+30:idx+225), 'L', 'int16', cpuEndianness) ./ 32767;
% sect.B1 = bytecast(data(idx+226:idx+421), 'L', 'int16', cpuEndianness) ./ 32767;
% sect.A2 = bytecast(data(idx+422:idx+617), 'L', 'int16', cpuEndianness) ./ 32767;
% sect.B2 = bytecast(data(idx+618:idx+813), 'L', 'int16', cpuEndianness) ./ 32767;
% sect.checksum = bytecast(data(idx+814:idx+815), 'L', 'uint16', cpuEndianness);

end

function cs = genChecksum(data, idx, len)
%GENCHECKSUM Generates a checksum over the given data range. See page 52 of
%the System integrator manual.
%
% start checksum value is 0xb58c (== 46476)
cs = 46476;

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
