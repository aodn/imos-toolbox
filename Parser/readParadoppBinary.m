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
  structures = {};
  lastLen = 0;
  while dIdx < dataLen
    
    [sect len] = readSection(filename, data, dIdx);
    
    if ~isempty(sect), structures{end+1} = sect; end
    if ~isempty(len)
        dIdx = dIdx + len;
    else
        return;
    end
    lastLen = len;
  end
end

%
% The functions below read in each of the data structures 
% specified in the System integrator Manual.
%

function [sect off] = readSection(filename, data, idx)
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
  sectLen  = 0;
  
  % read the section in
  switch sectType
    case 0,   [sect len off] = readUserConfiguration       (data, idx);
    case 1,   [sect len off] = readAquadoppVelocity        (data, idx);
    case 2,   [sect len off] = readVectrinoDistance        (data, idx);
    case 4,   [sect len off] = readHeadConfiguration       (data, idx);
    case 5,   [sect len off] = readHardwareConfiguration   (data, idx);
    case 6,   [sect len off] = readAquadoppDiagHeader      (data, idx);
    case 16,  [sect len off] = readVectorVelocity          (data, idx);
    case 17,  [sect len off] = readVectorSystem            (data, idx);
    case 18,  [sect len off] = readVectorVelocityHeader    (data, idx);
    case 32,  [sect len off] = readAwacVelocityProfile     (data, idx);
    case 33,  [sect len off] = readAquadoppProfilerVelocity(data, idx);
    case 36,  [sect len off] = readContinental             (data, idx);
    case 43,  [sect len off] = readHRAquadoppProfile       (data, idx);
    case 48,  [sect len off] = readAwacWaveData            (data, idx);
    case 49,  [sect len off] = readAwacWaveHeader          (data, idx);
    case 54,  [sect len off] = readAwacWaveData            (data, idx); % from what I've seen in data sets, 54 fits.
    case 66,  [sect len off] = readAwacStageData           (data, idx);
    case 80,  [sect len off] = readVectrinoVelocityHeader  (data, idx);
    case 81,  [sect len off] = readVectrinoVelocity        (data, idx);
    case 128, [sect len off] = readAquadoppDiagnostics     (data, idx);
  end
  
  if isempty(sect), return; end
  
  % generate and compare checksum - all section 
  % structs have a Checksum field
  cs = genChecksum(data, idx, len-2);
  
  if cs ~= sect.Checksum
    fprintf('%s\n', ['Warning : ' filename ' bad checksum (idx '...
        num2str(idx) ', checksum ' num2str(sect.Checksum) ', calculated '...
        num2str(cs) ')']);
  end
end

function cd = readClockData(data, idx)
%READCLOCKDATA Reads a clock data section (pg 29 of system integrator
%manual) and returns a matlab serial date.
% 

  minute = double(...
    10*bitand(bitshift(data(idx  ), -4), 15) + bitand(data(idx  ), 15));
  second = double(...
    10*bitand(bitshift(data(idx+1), -4), 15) + bitand(data(idx+1), 15));
  day    = double(...
    10*bitand(bitshift(data(idx+2), -4), 15) + bitand(data(idx+2), 15));
  hour   = double(...
    10*bitand(bitshift(data(idx+3), -4), 15) + bitand(data(idx+3), 15));
  year   = double(...
    10*bitand(bitshift(data(idx+4), -4), 15) + bitand(data(idx+4), 15));
  month  = double(...
    10*bitand(bitshift(data(idx+5), -4), 15) + bitand(data(idx+5), 15));
  
  % pg 52 of system integrator manual. ugh
  if year >= 90, year = year + 1900;
  else           year = year + 2000;
  end
  
  cd = datenum(year, month, day, hour, minute, second);
end

function [sect len off] = readHardwareConfiguration(data, idx)
%READHARDWARECONFIGURATION Reads a hardware configuration section (pg 29-30
% of system integrator manual).
%
  sect = struct;
  len = 48;
  off = len;

  sect.Sync       = data(idx);
  sect.Id         = data(idx+1);
  sect.Size       = bytecast(data(idx+2:idx+3), 'L', 'uint16');
  sect.SerialNo   = data(idx+4:idx+17);
  sect.SerialNo   = char(sect.SerialNo(sect.SerialNo ~= 0)');
  block           = bytecast(data(idx+18:idx+29), 'L', 'uint16');
  sect.Config     = block(1);
  sect.Frequency  = block(2);
  sect.PICversion = block(3);
  sect.HWrevision = block(4);
  sect.RecSize    = block(5);
  sect.Status     = block(6);
  % bytes 30-41 are free
  sect.FWversion  = data(idx+42:idx+45);
  sect.FWversion  = char(sect.FWversion(sect.FWversion ~= 0)');
  sect.Checksum   = bytecast(data(idx+46:idx+47), 'L', 'uint16');

end

function [sect len off] = readHeadConfiguration(data, idx)
%READHEADCONFIGURATION Reads a head configuration section (pg 30 of system 
% integrator manual).
%
  sect = struct;
  len = 224;
  off = len;

  sect.Sync      = data(idx);
  sect.Id        = data(idx+1);
  block          = bytecast(data(idx+2:idx+9), 'L', 'uint16');
  sect.Size      = block(1);
  sect.Config    = block(2);
  sect.Frequency = block(3);
  sect.Type      = block(4);
  sect.SerialNo  = data(idx+10:idx+21);
  sect.SerialNo  = char(sect.SerialNo(sect.SerialNo ~= 0)');
  sect.System    = 0; % 176 bytes; not sure what's in them
  % bytes 198-219 are free
  block          = bytecast(data(idx+220:idx+223), 'L', 'uint16');
  sect.NBeams    = block(1);
  sect.Checksum  = block(2);

end

function [sect len off] = readUserConfiguration(data, idx)
%readUserConfiguration Reads a user configuration section (pg 30-32 of
% system integrator manual).
%
  sect = struct;
  len = 512;
  off = len;
  
  sect.Sync           = data(idx);
  sect.Id             = data(idx+1);
  block               = bytecast(data(idx+2:idx+39), 'L', 'uint16');
  sect.Size           = block(1);
  sect.T1             = block(2);
  sect.T2             = block(3);
  sect.T3             = block(4);
  sect.T4             = block(5);
  sect.T5             = block(6);
  sect.NPings         = block(7);
  sect.AvgInterval    = block(8);
  sect.NBeams         = block(9);
  sect.TimCtrlReg     = block(10);
  sect.PwrCtrlReg     = block(11);
  sect.A1_1           = block(12);
  sect.B0_1           = block(13);
  sect.B1_1           = block(14);
  sect.CompassUpdRate = block(15);
  sect.CoordSystem    = block(16);
  sect.NBins          = block(17);
  sect.BinLength      = block(18);
  sect.MeasInterval   = block(19);
  sect.DeployName     = data(idx+40:idx+45);
  sect.DeployName     = char(sect.DeployName(sect.DeployName ~= 0)');
  sect.WrapMode       = bytecast(data(idx+46:idx+47), 'L', 'uint16');
  sect.clockDeploy    = readClockData(data, idx+48);
  sect.DiagInterval   = bytecast(data(idx+54:idx+57), 'L', 'uint32');
  block               = bytecast(data(idx+58:idx+73), 'L', 'uint16');
  sect.Mode           = block(1);
  sect.AdjSoundSpeed  = block(2);
  sect.NSampDiag      = block(3);
  sect.NBeamsCellDiag = block(4);
  sect.NPingsDiag     = block(5);
  sect.ModeTest       = block(6);
  sect.AnalnAddr      = block(7);
  sect.SWVersion      = block(8);
  % bytes 74-75 are spare
  sect.VelAdjTable    = 0; % 180 bytes; not sure what to do with them
  sect.Comments       = data(idx+256:idx+435);
  sect.Comments       = char(sect.Comments(sect.Comments ~= 0)');
  block               = bytecast(data(idx+436:idx+463), 'L', 'uint16');
  sect.WMMode         = block(1);
  sect.DynPercPos     = block(2);
  sect.WT1            = block(3);
  sect.WT2            = block(4);
  sect.WT3            = block(5);
  sect.NSamp          = block(6);
  sect.A1_2           = block(7);
  sect.B0_2           = block(8);
  sect.B1_2           = block(9);
  % bytes 454-455 are spare
  sect.AnaOutScale    = block(11);
  sect.CorrThresh     = block(12);
  % bytes 460-461 are spare
  sect.TiLag2         = block(14);
  % bytes 464-493 are spare
  sect.QualConst      = 0; % 16 bytes
  sect.Checksum       = bytecast(data(idx+510:idx+511), 'L', 'uint16');

end

function [sect len off] = readAquadoppVelocity(data, idx)
%READAQUADOPPVELOCITY Reads an Aquadopp velocity data section (pg 33 of 
% system integrator manual).
%
  sect = struct;
  len = 42;
  off = len;
  
  sect.Sync        = data(idx);
  sect.Id          = data(idx+1);
  sect.Size        = bytecast(data(idx+2:idx+3), 'L', 'uint16');
  sect.Time        = readClockData(data, idx+4); 
  % !!! Heading, pitch and roll can be negative => signed integer
  block            = bytecast(data(idx+10:idx+23), 'L', 'int16');
  sect.Error       = block(1);
  sect.Analn1      = block(2);
  sect.Battery     = block(3);
  sect.Analn2      = block(4);
  sect.Heading     = block(5);
  sect.Pitch       = block(6);
  sect.Roll        = block(7);
  
  sect.PressureMSB = bytecast(data(idx+24), 'L', 'uint8');
  sect.Status      = data(idx+25);
  
  block            = bytecast(data(idx+26:idx+29), 'L', 'uint16');
  sect.PressureLSW = block(1);
  sect.Temperature = block(2);
  % !!! velocity can be negative
  block            = bytecast(data(idx+30:idx+35), 'L', 'int16');
  sect.Vel1        = block(1);
  sect.Vel2        = block(2);
  sect.Vel3        = block(3);
  sect.Amp1        = bytecast(data(idx+36), 'L', 'uint8');
  sect.Amp2        = bytecast(data(idx+37), 'L', 'uint8');
  sect.Amp3        = bytecast(data(idx+38), 'L', 'uint8');
  sect.Fill        = bytecast(data(idx+39), 'L', 'uint8');
  sect.Checksum    = bytecast(data(idx+40:idx+41), 'L', 'uint16');

end

function [sect len off] = readAquadoppDiagHeader(data, idx)
%READAQUADOPPDIAGHEADER Reads an Aquadopp diagnostics header section (pg 34
% of system integrator manual).
%
  sect = struct;
  len = 36;
  off = len;
  
  sect.Sync      = data(idx);
  sect.Id        = data(idx+1);
  block          = bytecast(data(idx+2:idx+7), 'L', 'uint16');
  sect.Size      = block(1);
  sect.Records   = block(2);
  sect.Cell      = block(3);
  sect.Noise1    = bytecast(data(idx+8), 'L', 'uint8');
  sect.Noise2    = bytecast(data(idx+9), 'L', 'uint8');
  sect.Noise3    = bytecast(data(idx+10), 'L', 'uint8');
  sect.Noise4    = bytecast(data(idx+11), 'L', 'uint8');
  block          = bytecast(data(idx+12:idx+27), 'L', 'uint16');
  sect.ProcMagn1 = block(1);
  sect.ProcMagn2 = block(2);
  sect.ProcMagn3 = block(3);
  sect.ProcMagn4 = block(4);
  sect.Distance1 = block(5);
  sect.Distance2 = block(6);
  sect.Distance3 = block(7);
  sect.Distance4 = block(8);
  % bytes 28-33 are spare
  sect.Checksum  = bytecast(data(idx+34:idx+35), 'L', 'uint16');
end

function [sect len off] = readAquadoppDiagnostics(data, idx)
%READAQUADOPPDIAGNOSTICS Reads an Aquadopp diagnostics data section (pg 24
% of system integrator manual).
%
  % same structure as velocity section
  [sect len off] = readAquadoppVelocity(data, idx);
end

function [sect len off] = readVectorVelocityHeader(data, idx)
%READVECTORVELOCITYHEADER Reads a Vector velocity data header section (pg 
% 35 of system integrator manual).
%
  sect = struct;
  len = 42;
  off = len;
  
  sect.Sync         = data(idx);
  sect.Id           = data(idx+1);
  sect.Size         = bytecast(data(idx+2:idx+3), 'L', 'uint16');
  sect.Time         = readClockData(data, idx+4);
  sect.NRecords     = bytecast(data(idx+10:idx+11), 'L', 'uint16');
  sect.Noise1       = bytecast(data(idx+12), 'L', 'uint8');
  sect.Noise2       = bytecast(data(idx+13), 'L', 'uint8');
  sect.Noise3       = bytecast(data(idx+14), 'L', 'uint8');
  sect.Noise4       = bytecast(data(idx+15), 'L', 'uint8');
  sect.Correlation1 = bytecast(data(idx+16), 'L', 'uint8');
  sect.Correlation2 = bytecast(data(idx+17), 'L', 'uint8');
  sect.Correlation3 = bytecast(data(idx+18), 'L', 'uint8');
  sect.Correlation4 = bytecast(data(idx+19), 'L', 'uint8');
  % bytes 20-39 are spare
  sect.Checksum     = bytecast(data(idx+40:idx+41), 'L', 'uint16');
end

function [sect len off] = readVectorVelocity(data, idx)
%READVECTORVELOCITY Reads a vector velocity data section (pg 35 of system
% integrator manual).
%
  sect = struct;
  len = 24;
  off = len;
  
  sect.Sync        = data(idx);
  sect.Id          = data(idx+1);
  sect.Analn2LSB   = bytecast(data(idx+2), 'L', 'uint8');
  sect.Count       = bytecast(data(idx+3), 'L', 'uint8');
  sect.PressureMSB = bytecast(data(idx+4), 'L', 'uint8');
  sect.Analn2MSB   = bytecast(data(idx+5), 'L', 'uint8');
  block            = bytecast(data(idx+6:idx+9), 'L', 'uint16');
  sect.PressureLSW = block(1);
  sect.Analn1      = block(2);
  % !!! velocities can be negative
  block            = bytecast(data(idx+10:idx+15), 'L', 'int16');
  sect.VelB1       = block(1);
  sect.VelB2       = block(2);
  sect.VelB3       = block(3);
  sect.AmpB1       = bytecast(data(idx+16), 'L', 'uint8');
  sect.AmpB2       = bytecast(data(idx+17), 'L', 'uint8');
  sect.AmpB3       = bytecast(data(idx+18), 'L', 'uint8');
  sect.CorrB1      = bytecast(data(idx+19), 'L', 'uint8');
  sect.CorrB2      = bytecast(data(idx+20), 'L', 'uint8');
  sect.CorrB3      = bytecast(data(idx+21), 'L', 'uint8');
  sect.Checksum    = bytecast(data(idx+22:idx+23), 'L', 'uint16');
end

function [sect len off] = readVectorSystem(data, idx)
%READVECTORSYSTEM Reads a vector system data section (pg 36 of system
% integrator manual).
%
  sect = struct;
  len = 28;
  off = len;
  
  sect.Sync        = data(idx);
  sect.Id          = data(idx+1);
  sect.Size        = bytecast(data(idx+2:idx+3), 'L', 'uint16');
  sect.Time        = readClockData(data, idx+4);
  % !!! Heading, pitch and roll can be negative
  block            = bytecast(data(idx+10:idx+21), 'L', 'int16');
  sect.Battery     = block(1);
  sect.SoundSpeed  = block(2);
  sect.Heading     = block(3);
  sect.Pitch       = block(4);
  sect.Roll        = block(5);
  sect.Temperature = block(6);
  sect.Error       = data(idx+22);
  sect.Status      = data(idx+23);
  block            = bytecast(data(idx+24:idx+27), 'L', 'uint16');
  sect.Analn       = block(1);
  sect.Checksum    = block(2);
end

function [sect len off] = readAquadoppProfilerVelocity(data, idx)
%READAQUADOPPPROFILERVELOCITY Reads an Aquadopp Profiler velocity data
% section (pg 37 of system integrator manual).
%
  sect = struct;
  len = 0;       % length is variable; determined later
  
  sect.Sync        = data(idx);
  sect.Id          = data(idx+1);
  sect.Size        = bytecast(data(idx+2:idx+3), 'L', 'uint16');
  len              = sect.Size * 2;
  off              = len;
  sect.Time        = readClockData(data, idx+4);
  % !!! Heading, pitch and roll can be negative
  block            = bytecast(data(idx+10:idx+23), 'L', 'int16');
  sect.Error       = block(1);
  sect.Analn1      = block(2);
  sect.Battery     = block(3);
  sect.Analn2      = block(4);
  sect.Heading     = block(5);
  sect.Pitch       = block(6);
  sect.Roll        = block(7);
  
  sect.PressureMSB = bytecast(data(idx+24), 'L', 'uint8');
  sect.Status      = data(idx+25);
  block            = bytecast(data(idx+26:idx+29), 'L', 'uint16');
  sect.PressureLSW = block(1);
  sect.Temperature = block(2);
  
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
  sect.Vel1 = bytecast(data(vel1Off:vel1Off+nCells*2-1), 'L', 'int16');
  sect.Vel2 = bytecast(data(vel2Off:vel2Off+nCells*2-1), 'L', 'int16');
  sect.Vel3 = bytecast(data(vel3Off:vel3Off+nCells*2-1), 'L', 'int16');
  sect.Amp1 = bytecast(data(amp1Off:amp1Off+nCells-1),   'L', 'uint8');
  sect.Amp2 = bytecast(data(amp2Off:amp2Off+nCells-1),   'L', 'uint8');
  sect.Amp3 = bytecast(data(amp3Off:amp3Off+nCells-1),   'L', 'uint8');

  sect.Checksum = bytecast(data(csOff:csOff+1), 'L', 'uint16');

end

function [sect len off] = readHRAquadoppProfile(data, idx)
%READHRAQUADOPPPROFILERVELOCITY Reads a HR Aquadopp Profile data section
% (pg 38 of system integrator manual).
%
  sect = struct;
  len = 0;

  sect.Sync         = data(idx);
  sect.Id           = data(idx+1);
  sect.Size         = bytecast(data(idx+2:idx+3), 'L', 'uint16');
  len               = sect.Size * 2;
  off               = len;
  sect.Time         = readClockData(data, idx+4);
  % !!! Heading, pitch and roll can be negative
  block             = bytecast(data(idx+10:idx+23), 'L', 'int16');
  sect.Milliseconds = block(1);
  sect.Error        = block(2);
  sect.Battery      = block(3);
  sect.Analn2_1     = block(4);
  sect.Heading      = block(5);
  sect.Pitch        = block(6);
  sect.Roll         = block(7);
  sect.PressureMSB  = bytecast(data(idx+24), 'L', 'uint8');
  % byte 25 is a fill byte
  block             = bytecast(data(idx+26:idx+33), 'L', 'uint16');
  sect.PressureLSW  = block(1);
  sect.Temperature  = block(2);
  sect.Analn1       = block(3);
  sect.Analn2_2     = block(4);
  sect.Beams        = bytecast(data(idx+34), 'L', 'uint8');
  sect.Cells        = bytecast(data(idx+35), 'L', 'uint8');
  sect.VelLag2      = bytecast(data(idx+36:idx+41), 'L', 'uint16');
  block             = bytecast(data(idx+42:idx+47), 'L', 'uint8');
  sect.AmpLag2      = block(1:3);
  sect.CorrLag2     = block(4:6);
  % bytes 48-53 are spare  
  velOff  = idx     + 54;
  ampOff  = velOff  + sect.Beams*sect.Cells*2;
  corrOff = ampOff  + sect.Beams*sect.Cells;
  csOff   = corrOff + sect.Beams*sect.Cells;
  
  % fill byte if num cells is odd
  if mod(nCells, 2), csOff = csOff + 1; end
  
  % velocity data
  for k = 1:sect.Beams
    
    sOff = velOff + (k-1) * (sect.Cells * 2);
    eOff = sOff + (sect.Cells * 2)-1;
    % !!! velocity can be negative
    sect.(['Vel' num2str(k)]) = ...
      bytecast(data(sOff:eOff), 'L', 'int16');
  end
  
  % amplitude data
  for k = 1:sect.Beams
    
    sOff = ampOff + (k-1) * (sect.Cells);
    eOff = sOff + (sect.Cells * 2)-1;
    
    vel.(['Amp' num2str(k)]) = ...
      bytecast(data(sOff:eOff), 'L', 'uint8');
  end
  
  % correlation data
  for k = 1:sect.Beams
    
    sOff = corrOff + (k-1) * (sect.Cells);
    eOff = sOff + (sect.Cells * 2)-1;
    
    sect.(['Corr' num2str(k)]) = ...
      bytecast(data(sOff:eOff), 'L', 'uint8');
  end
  
  sect.Checksum = bytecast(data(csOff:csOff+1), 'L', 'uint16');

end

function [sect len off] = readAwacVelocityProfile(data, idx)
%READAWACVELOCITYPROFILE Reads an AWAC Velocity Profile data section (pg 39
% of the system integrator manual).
%
  sect = struct;
  len = 0;

  sect.Sync        = data(idx);
  sect.Id          = data(idx+1);
  sect.Size        = bytecast(data(idx+2:idx+3), 'L', 'uint16');
  len              = sect.Size * 2;
  off              = len;
  sect.Time        = readClockData(data, idx+4);
  % !!! Heading, pitch and roll can be negative
  block            = bytecast(data(idx+10:idx+23), 'L', 'int16');
  sect.Error       = block(1);
  sect.Analn1      = block(2);
  sect.Battery     = block(3);
  sect.Analn2      = block(4);
  sect.Heading     = block(5);
  sect.Pitch       = block(6);
  sect.Roll        = block(7);
  sect.PressureMSB = bytecast(data(idx+24), 'L', 'uint8');
  sect.Status      = data(idx+25);
  block            = bytecast(data(idx+ 26:idx+29), 'L', 'uint16');
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
  
  % !!! Velocity can be negative
  sect.Vel1 = bytecast(data(vel1Off:vel1Off+nCells*2-1), 'L', 'int16'); %U comp (East)
  sect.Vel2 = bytecast(data(vel2Off:vel2Off+nCells*2-1), 'L', 'int16'); %V comp (North)
  sect.Vel3 = bytecast(data(vel3Off:vel3Off+nCells*2-1), 'L', 'int16'); %W comp (up)
  sect.Amp1 = bytecast(data(amp1Off:amp1Off+nCells-1),   'L', 'uint8');
  sect.Amp2 = bytecast(data(amp2Off:amp2Off+nCells-1),   'L', 'uint8');
  sect.Amp3 = bytecast(data(amp3Off:amp3Off+nCells-1),   'L', 'uint8');
  
  sect.Checksum = bytecast(data(csOff:csOff+1), 'L', 'uint16');

end

function [sect len off] = readAwacWaveHeader(data, idx)
%READAWACWAVEHEADER Reads an AWAC wave header section (pg 
% 40 of system integrator manual).
%
  sect = struct;
  len = 60;
  off = len;
  sect = [];
%   sect.Sync         = data(idx);
%   sect.Id           = data(idx+1);
%   sect.Size         = bytecast(data(idx+2:idx+3), 'L', 'uint16');
%   sect.Time         = readClockData(data, idx+4);
%   block             = bytecast(data(idx+10:idx+17), 'L', 'uint16');
%   sect.NRecords     = block(1);
%   sect.Blanking     = block(2);
%   sect.Battery      = block(3);
%   sect.SoundSpeed   = block(4);
%   block             = bytecast(data(idx+18:idx+23), 'L', 'int16');
%   sect.Heading      = block(1);
%   sect.Pitch        = block(2);
%   sect.Roll         = block(3);
%   block             = bytecast(data(idx+24:idx+31), 'L', 'uint16');
%   sect.MinPress     = block(1);
%   sect.HMaxPress    = block(2);
%   sect.Temperature  = block(3);
%   sect.CellSize     = block(4);
%   sect.Noise1       = bytecast(data(idx+32), 'L', 'uint8');
%   sect.Noise2       = bytecast(data(idx+33), 'L', 'uint8');
%   sect.Noise3       = bytecast(data(idx+34), 'L', 'uint8');
%   sect.Noise4       = bytecast(data(idx+35), 'L', 'uint8');
%   block             = bytecast(data(idx+36:idx+43), 'L', 'uint16');
%   sect.ProcMagn1    = block(1);
%   sect.ProcMagn2    = block(2);
%   sect.ProcMagn3    = block(3);
%   sect.ProcMagn4    = block(4);
%   % bytes 44-57 are spare
%   sect.Checksum     = bytecast(data(idx+58:idx+59), 'L', 'uint16');
end

function [sect len off] = readAwacWaveData(data, idx)
%READAWACWAVEDATA Reads an AWAC Wave data section (pg 41
% of the system integrator manual).
%
%   sect = struct;
  len = 24;
  off = len;
  sect = [];
%   sect.Sync        = data(idx);
%   sect.Id          = data(idx+1);
%   sect.Size        = bytecast(data(idx+2:idx+3), 'L', 'uint16');
%   block            = bytecast(data(idx+4:idx+9), 'L', 'uint16');
%   sect.Pressure    = block(1);
%   sect.Distance    = block(2);
%   sect.Analn       = block(3);
%   % !!! velocity can be negative
%   block            = bytecast(data(idx+10:idx+17), 'L', 'int16');
%   sect.Vel1        = block(1);
%   sect.Vel2        = block(2);
%   sect.Vel3        = block(3);
%   sect.Vel4        = block(4);
%   sect.Amp1        = bytecast(data(idx+18), 'L', 'uint8');
%   sect.Amp2        = bytecast(data(idx+19), 'L', 'uint8');
%   sect.Amp3        = bytecast(data(idx+20), 'L', 'uint8');
%   sect.Amp4        = bytecast(data(idx+21), 'L', 'uint8');
%   sect.Checksum    = bytecast(data(idx+22:idx+23), 'L', 'uint16');
end

function [sect len off] = readAwacStageData(data, idx)
%READAWACSTAGEDATA Reads an AWAC Stage data section (pg 41
% of the system integrator manual).
%
  sect = struct;
  len = 0;

%   sect.Sync        = data(idx);
%   sect.Id          = data(idx+1);
  sect.Size        = bytecast(data(idx+2:idx+3), 'L', 'uint16');
  
  len              = sect.Size * 2;
  off              = len;
  sect = [];
%   sect.Blanking    = bytecast(data(idx+4:idx+5), 'L', 'uint16');
%   % !!! Heading, pitch and roll can be negative
%   block            = bytecast(data(idx+6:idx+9), 'L', 'int16');
%   sect.Pitch       = block(1);
%   sect.Roll        = block(2);
%   block            = bytecast(data(idx+10:idx+21), 'L', 'uint16');
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
%   sect.Amp = bytecast(data(ampOff:ampOff+nCells-1),   'L', 'uint8');
%   
%   sect.Checksum = bytecast(data(csOff:csOff+1), 'L', 'uint16');
end

function [sect len off] = readContinental(data, idx)
%READCONTINENTAL Reads a Continental Data section (pg 42 of the System
% Integrator Manual).
%
  % structure is same as awac velocity profile data
  [sect len off] = readAwacVelocityProfile(data, idx);
end


function [sect len off] = readVectrinoVelocityHeader(data, idx)
%READVECTRINOVELOCITYHEADER Reads a Vectrino velocity data header section
% (pg 42 of system integrator manual).
%
  sect = struct;
  len = 42;
  off = len;

  sect.Sync         = data(idx);
  sect.Id           = data(idx+1);
  block             = bytecast(data(idx+2:idx+11), 'L', 'uint16');
  sect.Size         = block(1);
  sect.Distance     = block(2);
  sect.DistQuality  = block(3);
  sect.Lag1         = block(4);
  sect.Lag2         = block(5);
  sect.Noise1       = bytecast(data(idx+12), 'L', 'uint8');
  sect.Noise2       = bytecast(data(idx+13), 'L', 'uint8');
  sect.Noise3       = bytecast(data(idx+14), 'L', 'uint8');
  sect.Noise4       = bytecast(data(idx+15), 'L', 'uint8');
  sect.Correlation1 = bytecast(data(idx+16), 'L', 'uint8');
  sect.Correlation2 = bytecast(data(idx+17), 'L', 'uint8');
  sect.Correlation3 = bytecast(data(idx+18), 'L', 'uint8');
  sect.Correlation4 = bytecast(data(idx+19), 'L', 'uint8');
  block             = bytecast(data(idx+20:idx+23), 'L', 'uint16');
  sect.Temperature  = block(1);
  sect.SoundSpeed   = block(2);
  sect.AmpZ01       = bytecast(data(idx+24), 'L', 'uint8');
  sect.AmpZ02       = bytecast(data(idx+25), 'L', 'uint8');
  sect.AmpZ03       = bytecast(data(idx+26), 'L', 'uint8');
  sect.AmpZ04       = bytecast(data(idx+27), 'L', 'uint8');
  sect.AmpX11       = bytecast(data(idx+28), 'L', 'uint8');
  sect.AmpX12       = bytecast(data(idx+29), 'L', 'uint8');
  sect.AmpX13       = bytecast(data(idx+30), 'L', 'uint8');
  sect.AmpX14       = bytecast(data(idx+31), 'L', 'uint8');
  sect.AmpZ0PLag11  = bytecast(data(idx+32), 'L', 'uint8');
  sect.AmpZ0PLag12  = bytecast(data(idx+33), 'L', 'uint8');
  sect.AmpZ0PLag13  = bytecast(data(idx+34), 'L', 'uint8');
  sect.AmpZ0PLag14  = bytecast(data(idx+35), 'L', 'uint8');
  sect.AmpZ0PLag21  = bytecast(data(idx+36), 'L', 'uint8');
  sect.AmpZ0PLag22  = bytecast(data(idx+37), 'L', 'uint8');
  sect.AmpZ0PLag23  = bytecast(data(idx+38), 'L', 'uint8');
  sect.AmpZ0PLag24  = bytecast(data(idx+39), 'L', 'uint8');
  sect.Checksum     = bytecast(data(idx+40:idx+41), 'L', 'uint16');
end

function [sect len off] = readVectrinoVelocity(data, idx)
%READVECTRINOVELOCITY Reads a Vectrino Velocity data section (pg 43 of
% system integrator manual).
%
  sect = struct;
  len = 0;
  
  sect.Sync   = data(idx);
  sect.Id     = data(idx+1);
  sect.Size   = 0;           % no size field in spec
  sect.Status = data(idx+2);
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
    sect.(['Vel' num2str(k)]) = ...
      bytecast(data(sOff:eOff), 'L', 'int16');
  end
  
  % amplitude
  for k = 1:nBeams
    
    sOff = ampOff + (k-1) * nCells;
    eOff = sOff + nCells - 1;
    
    sect.(['Amp' num2str(k)]) = ...
      bytecast(data(sOff:eOff), 'L', 'uint8');
  end
  
  % correlation
  for k = 1:nBeams
    
    sOff = corrOff + (k-1) * nCells;
    eOff = sOff + nCells - 1;
    
    vel.(['Corr' num2str(k)]) = ...
      bytecast(data(sOff:eOff), 'L', 'uint8');
  end
  
  sect.Checksum = bytecast(data(csOff:csOff+1), 'L', 'uint16');

end

function [sect len off] = readVectrinoDistance(data, idx)
%READVECTRINODISTANCE Reads a Vectrino distance data section (pg 43 of
% system integrator manual).
%
  sect = struct;
  len = 16;
  off = len;
  
  sect.Sync        = data(idx);
  sect.Id          = data(idx+1);
  block            = bytecast(data(idx+2:idx+15), 'L', 'uint16');
  sect.Size        = block(1);
  sect.Temperature = block(2);
  sect.SoundSpeed  = block(3);
  sect.Distance    = block(4);
  sect.DistQuality = block(5);
  % bytes 12-13 are spare
  sect.Checksum    = block(7);

end

function cs = genChecksum(data, idx, len)
%GENCHECKSUM Generates a checksum over the given data range. See page 52 of
%the System integrator manual.
% 
  % start checksum value is 0xb58c (== 56476)
  cs = 46476;
  
  % the checksum routine relies upon uint16 overflow, but matlab's 
  % 'saturation' of out-of-bounds values makes this impossible. 
  % so i'm doing normal addition, then modding the result by 65536, 
  % which will give the same result
  for k = idx:2:(idx+len-2)
     cs = cs + double(data(k)) + double(data(k+1))*256;
  end
  
  cs = mod(cs, 65536);
  
end
