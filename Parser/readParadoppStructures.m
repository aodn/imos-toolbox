function structures = readParadoppStructures( filename )
%READPARADOPPSTRUCTURES Reads a binary file retrieved from a 'Paradopp'
% instrument. 
%
% This function is able to parse raw binary data from any Nortek instrument 
% which is defined in the Firmware Data Structures section of the Nortek 
% System Integrator Guide, June 2008:
%
%   - Aquadopp Current Meter
%   - Aquadopp Profiler
%   - Aquadopp HR Profiler
%   - Continental
%   - Vector
%   - Vectrino
%   - AWAC
%
% Inputs:
%   filename   - A string containing the name of a raw binary file to
%                parse.
% 
% Outputs:
%   structures - A struct containing all of the data structures that were
%                contained in the file.
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
%  error(nargchk(1,1,nargin));

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
  
  while dIdx < dataLen
    
    [sect len] = readSection(data, dIdx);
    
    structures{end+1} = sect;
    dIdx = dIdx + len;
  end
end

%
% The functions below read in each of the data structures 
% specified in the System integrator Manual.
%

function [sect len] = readSection(data, idx)
%READSECTION Reads the next data structure in the data array, starting at
% the given index.
%

  % check sync byte
  if data(idx) ~= 165
    error(['bad sync (idx ' num2str(dIdx) ', val ' num2str(data(dIdx)) ')']); 
  end
  
  sectType = data(idx+1);
  sectLen  = 0;
  
  % read the section in
  switch sectType
    case 0,   [sect len] = readUserConfiguration       (data, idx);
    case 1,   [sect len] = readAquadoppVelocity        (data, idx);
    case 2,   [sect len] = readVectrinoDistance        (data, idx);
    case 4,   [sect len] = readHeadConfiguration       (data, idx);
    case 5,   [sect len] = readHardwareConfiguration   (data, idx);
    case 6,   [sect len] = readAquadoppDiagHeader      (data, idx);
    case 16,  [sect len] = readVectorVelocity          (data, idx);
    case 17,  [sect len] = readVectorSystem            (data, idx);
    case 18,  [sect len] = readVectorVelocityHeader    (data, idx);
    case 32,  [sect len] = readAwacVelocityProfile     (data, idx);
    case 33,  [sect len] = readAquadoppProfilerVelocity(data, idx);
    case 36,  [sect len] = readContinental             (data, idx);
    case 43,  [sect len] = readHRAquadoppProfile       (data, idx);
    case 48,  [sect len] = readAwacWave                (data, idx);
    case 49,  [sect len] = readAwacWaveHeader          (data, idx);
    case 66,  [sect len] = readAwacStage               (data, idx);
    case 80,  [sect len] = readVectrinoVelocityHeader  (data, idx);
    case 81,  [sect len] = readVectrinoVelocity        (data, idx);
    case 128, [sect len] = readAquadoppDiagnostics     (data, idx);
  end
  
  % generate and compare checksum - all section 
  % structs have a Checksum field
  cs = genChecksum(data, idx, len-2);
  
  if cs ~= sect.Checksum
    error(['bad checksum ' ...
           '(idx ' num2str(idx) ', ' ...
           'checksum ' num2str(sect.Checksum) ', ' ...
           'calculated ' num2str(cs) ')']); 
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

function [sect len] = readHardwareConfiguration(data, idx)
%READHARDWARECONFIGURATION Reads a hardware configuration section (pg 29-30
% of system integrator manual).
%
  sect = struct;
  len = 48;

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

function [sect len] = readHeadConfiguration(data, idx)
%READHEADCONFIGURATION Reads a head configuration section (pg 30 of system 
% integrator manual).
%
  sect = struct;
  len = 224;

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

function [sect len] = readUserConfiguration(data, idx)
%readUserConfiguration Reads a user configuration section (pg 30-32 of
% system integrator manual).
%
  sect = struct;
  len = 512;
  
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

function [sect len] = readAquadoppVelocity(data, idx)
%READAQUADOPPVELOCITY Reads an Aquadopp velocity data section (pg 33 of 
% system integrator manual).
%
  sect = struct;
  len = 42;
  
  sect.Sync        = data(idx);
  sect.Id          = data(idx+1);
  sect.Size        = bytecast(data(idx+2:idx+3), 'L', 'uint16');
  sect.Time        = readClockData(data, idx+4); 
  block            = bytecast(data(idx+10:idx+23), 'L', 'uint16');
  sect.Error       = block(1);
  sect.Analn1      = block(2);
  sect.Battery     = block(3);
  sect.Analn2      = block(4);
  sect.Heading     = block(5);
  sect.Pitch       = block(6);
  sect.Roll        = block(7);
  sect.PressureMSB = data(idx+24);
  sect.Status      = data(idx+25);
  block            = bytecast(data(idx+16:idx+33), 'L', 'uint16');
  sect.PressureLSW = block(1);
  sect.Temperature = block(2); 
  sect.VelB1       = block(3);
  sect.VelB2       = block(4);
  sect.VelB3       = block(5);
  sect.AmpB1       = data(idx+36);
  sect.AmpB2       = data(idx+37);
  sect.AmpB3       = data(idx+38);
  sect.Fill        = data(idx+39);
  sect.Checksum    = bytecast(data(idx+40:idx+41), 'L', 'uint16');

end

function [sect len] = readAquadoppDiagHeader(data, idx)
%READAQUADOPPDIAGHEADER Reads an Aquadopp diagnostics header section (pg 34
% of system integrator manual).
%
  sect = struct;
  len = 36;
  
  sect.Sync      = data(idx);
  sect.Id        = data(idx+1);
  block          = bytecast(data(idx+2:idx+7), 'L', 'uint16');
  sect.Size      = block(1);
  sect.Records   = block(2);
  sect.Cell      = block(3);
  sect.Noise1    = data(idx+8);
  sect.Noise2    = data(idx+9);
  sect.Noise3    = data(idx+10);
  sect.Noise4    = data(idx+11);
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

function [sect len] = readAquadoppDiagnostics(data, idx)
%READAQUADOPPDIAGNOSTICS Reads an Aquadopp diagnostics data section (pg 24
% of system integrator manual).
%
  % same structure as velocity section
  [sect len] = readAquadoppVelocity(data, idx);
end

function [sect len] = readVectorVelocityHeader(data, idx)
%READVECTORVELOCITYHEADER Reads a Vector velocity data header section (pg 
% 35 of system integrator manual).
%
  sect = struct;
  len = 42;
  
  sect.Sync         = data(idx);
  sect.Id           = data(idx+1);
  sect.Size         = bytecast(data(idx+2:idx+3), 'L', 'uint16');
  sect.Time         = readClockData(data, idx+4);
  sect.NRecords     = bytecast(data(idx+10:idx+11), 'L', 'uint16');
  sect.Noise1       = data(idx+12);
  sect.Noise2       = data(idx+13);
  sect.Noise3       = data(idx+14);
  sect.Noise4       = data(idx+15);
  sect.Correlation1 = data(idx+16);
  sect.Correlation2 = data(idx+17);
  sect.Correlation3 = data(idx+18);
  sect.Correlation4 = data(idx+19);
  % bytes 20-39 are spare
  sect.Checksum     = bytecast(data(idx+40:idx+41), 'L', 'uint16');
end

function [sect len] = readVectorVelocity(data, idx)
%READVECTORVELOCITY Reads a vector velocity data section (pg 35 of system
% integrator manual).
%
  sect = struct;
  len = 24;
  
  sect.Sync        = data(idx);
  sect.Id          = data(idx+1);
  sect.Analn2LSB   = data(idx+2);
  sect.Count       = data(idx+3);
  sect.PressureMSB = data(idx+4);
  sect.Analn2MSB   = data(idx+5);
  block            = bytecast(data(idx+6:idx+15), 'L', 'uint16');
  sect.PressureLSW = block(1);
  sect.Analn1      = block(2);
  sect.VelB1       = block(3);
  sect.VelB2       = block(4);
  sect.VelB3       = block(5);
  sect.AmpB1       = data(idx+16);
  sect.AmpB2       = data(idx+17);
  sect.AmpB3       = data(idx+18);
  sect.CorrB1      = data(idx+19);
  sect.CorrB2      = data(idx+20);
  sect.CorrB3      = data(idx+21);
  sect.Checksum    = bytecast(data(idx+22:idx+23), 'L', 'uint16');
end

function [sect len] = readVectorSystem(data, idx)
%READVECTORSYSTEM Reads a vector system data section (pg 36 of system
% integrator manual).
%
  sect = struct;
  len = 28;
  
  sect.Sync        = data(idx);
  sect.Id          = data(idx+1);
  sect.Size        = bytecast(data(idx+2:idx+3), 'L', 'uint16');
  sect.Time        = readClockData(data, idx+4);
  block            = bytecast(data(idx+10:idx+19), 'L', 'uint16');
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

function [sect len] = readAquadoppProfilerVelocity(data, idx)
%READAQUADOPPPROFILERVELOCITY Reads an Aquadopp Profiler velocity data
% section (pg 37 of system integrator manual).
%
  sect = struct;
  len = 0;       % length is variable; determined later
  
  sect.Sync        = data(idx);
  sect.Id          = data(idx+1);
  sect.Size        = bytecast(data(idx+2:idx+3), 'L', 'uint16');
  len              = sect.Size * 2;
  sect.Time        = readClockData(data, idx+4);
  block            = bytecast(data(idx+10:idx+23), 'L', 'uint16');
  sect.Error       = block(1);
  sect.Analn1      = block(2);
  sect.Battery     = block(3);
  sect.Analn2      = block(4);
  sect.Heading     = block(5);
  sect.Pitch       = block(6);
  sect.Roll        = block(7);
  sect.PressureMSB = data(idx+24);
  sect.Status      = data(idx+25);
  block            = bytecast(data(idx+26:idx+29), 'L', 'uint16');
  sect.PressureLSW = block(1);
  sect.Temperature = block(2);
  
  % calculate number of cells from structure size 
  % (* 2 because size is specified in 16 bit words)
  nCells = floor(((sect.Size) * 2 - 32) / 9);
  
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
 
  sect.vel1 = bytecast(data(vel1Off:vel1Off+nCells*2-1), 'L', 'uint16');
  sect.vel2 = bytecast(data(vel2Off:vel2Off+nCells*2-1), 'L', 'uint16');
  sect.vel3 = bytecast(data(vel3Off:vel3Off+nCells*2-1), 'L', 'uint16');
  sect.amp1 = bytecast(data(amp1Off:amp1Off+nCells-1),   'L', 'uint8');
  sect.amp2 = bytecast(data(amp2Off:amp2Off+nCells-1),   'L', 'uint8');
  sect.amp3 = bytecast(data(amp3Off:amp3Off+nCells-1),   'L', 'uint8');

  sect.Checksum = bytecast(data(csOff:csOff+1), 'L', 'uint16');

end

function [sect len] = readHRAquadoppProfile(data, idx)
%READHRAQUADOPPPROFILERVELOCITY Reads a HR Aquadopp Profile data section
% (pg 38 of system integrator manual).
%
  sect = struct;
  len = 0;

  sect.Sync         = data(idx);
  sect.Id           = data(idx+1);
  sect.Size         = bytecast(data(idx+2:idx+3), 'L', 'uint16');
  len               = sect.Size * 2;
  sect.Time         = readClockData(data, idx+4);
  block             = bytecast(data(idx+10:idx+23), 'L', 'uint16');
  sect.Milliseconds = block(1);
  sect.Error        = block(2);
  sect.Battery      = block(3);
  sect.Analn2_1     = block(4);
  sect.Heading      = block(5);
  sect.Pitch        = block(6);
  sect.Roll         = block(7);
  sect.PressureMSB  = data(idx+24);
  % byte 25 is a fill byte
  block             = bytecast(data(idx+26:idx+33), 'L', 'uint16');
  sect.PressureLSW  = block(1);
  sect.Temperature  = block(2);
  sect.Analn1       = block(3);
  sect.Analn2_2     = block(4);
  sect.Beams        = data(idx+34);
  sect.Cells        = data(idx+35);
  
  % the spec is a little confusing here; the VelLag2, 
  % AmpLag2 and CorrLag2 fields contain 3 values each, 
  % '1 per beam', but i thought there were a variable 
  % number of beams? also, as the spec currently stands, 
  % it contains a typo - the offset of Spare1 should 
  % be 48; this change propagates on to all following 
  % fields. I've posted a query on the nortek forum, but
  % am yet to receive a response (as of 10/08/2009)
  % http://www.nortek-as.com/en/knowledge-center/forum/
  % system-integration-and-telemetry/47868554
  
  sect.VelLag2      = bytecast(data(idx+36:idx+41), 'L', 'uint16');
  block             = bytecast(data(idx+42:idx+47), 'L', 'uint8');
  sect.AmpLag2      = block(1:3);
  sect.CorrLag2     = block(4:6);
  % bytes 48-53 are spare
  
  % another spec issue here - there's no indication of 
  % size for Vel, Amp and Corr - 1 byte or 2? I'm assuming 
  % 2 bytes for Vel, 1 for Amp and Corr. I'm also assuming 
  % that Beams is the slowest changing dimension, as it is 
  % with the Aquadopp Profiler Velocity data
  
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
    
    sect.(['Vel' num2str(k)]) = bytecast(data(sOff:eOff), 'L', 'uint16');
  end
  
  % amplitude data
  for k = 1:sect.Beams
    
    sOff = ampOff + (k-1) * (sect.Cells);
    eOff = sOff + (sect.Cells * 2)-1;
    
    vel.(['Amp' num2str(k)]) = bytecast(data(sOff:eOff), 'L', 'uint8');
  end
  
  % correlation data
  for k = 1:sect.Beams
    
    sOff = corrOff + (k-1) * (sect.Cells);
    eOff = sOff + (sect.Cells * 2)-1;
    
    sect.(['Corr' num2str(k)]) = bytecast(data(sOff:eOff), 'L', 'uint8');
  end
  
  sect.Checksum = bytecast(data(csOff:csOff+1), 'L', 'uint16');

end

function [sect len] = readAwacVelocityProfile(data, idx)
%READAWACVELOCITYPROFILE Reads an AWAC Velocity Profile data section (pg 39
% of the system integrator manual).
%
  sect = struct;
  len = 0;

  sect.Sync        = data(idx);
  sect.Id          = data(idx+1);
  sect.Size        = bytecast(data(idx+2:idx+3), 'L', 'uint16');
  len              = sect.Size * 2;
  sect.Time        = readClockData(data, idx+4);
  block            = bytecast(data(idx+10:idx+23), 'L', 'uint16');
  sect.Error       = block(1);
  sect.Analn1      = block(2);
  sect.Battery     = block(3);
  sect.Analn2      = block(4);
  sect.Heading     = block(5);
  sect.Pitch       = block(6);
  sect.Roll        = block(7);
  sect.PressureMSB = data(idx+24);
  sect.Status      = data(idx+25);
  block            = bytecast(data(idx+ 26:idx+29), 'L', 'uint16');
  sect.PressureLSW = block(1);
  sect.Temperature = block(2);
  % bytes 30-117 are spare
  
  % calculate number of celfrom structure size
  % (size is in 16 bit words)
  nCells = floor(((sect.Size) * 2 - 120) / 9);
  
  vel1Off = idx+118;
  vel2Off = vel1Off + nCells*2;
  vel3Off = vel2Off + nCells*2;
  amp1Off = vel3Off + nCells*2;
  amp2Off = amp1Off + nCells;
  amp3Off = amp2Off + nCells;
  csOff   = amp3Off + nCells;
  
  % fill value is included if number of cells is odd
  if mod(nCells, 2), csOff = csOff + 1; end
  
  sect.Vel1 = bytecast(data(vel1Off:vel1Off+nCells*2-1), 'L', 'uint16');
  sect.Vel2 = bytecast(data(vel2Off:vel2Off+nCells*2-1), 'L', 'uint16');
  sect.Vel3 = bytecast(data(vel3Off:vel3Off+nCells*2-1), 'L', 'uint16');
  sect.Amp1 = bytecast(data(amp1Off:amp1Off+nCells-1),   'L', 'uint8');
  sect.Amp2 = bytecast(data(amp2Off:amp2Off+nCells-1),   'L', 'uint8');
  sect.Amp3 = bytecast(data(amp3Off:amp3Off+nCells-1),   'L', 'uint8');
  
  sect.Checksum = bytecast(data(csOff:csOff+1), 'L', 'uint16');

end

function [sect len] = readAwacWaveHeader(data, idx)
%READAWACWAVEHEADER Reads an Awac Wave Data Header section (pg 40 of system
% integrator manual).
%
  sect = struct;
  len = 60;

  sect.Sync        = data(idx);
  sect.Id          = data(idx+1);
  sect.Size        = bytecast(data(idx+2:idx+3), 'L', 'uint16');
  sect.Time        = readClockData(data, idx+4);
  block            = bytecast(data(idx+10:idx+31), 'L', 'uint16');
  sect.NRecords    = block(1);
  sect.Blanking    = block(2);
  sect.Battery     = block(3);
  sect.SoundSpeed  = block(4);
  sect.Heading     = block(5);
  sect.Pitch       = block(6);
  sect.Roll        = block(7);
  sect.MinPress    = block(8);
  sect.hMaxPress   = block(9);
  sect.Temperature = block(10);
  sect.CellSize    = block(11);
  sect.Noise1      = data(idx+32);
  sect.Noise2      = data(idx+33);
  sect.Noise3      = data(idx+34);
  sect.Noise4      = data(idx+35);
  block            = bytecast(data(idx+36:idx+43), 'L', 'uint16');
  sect.ProgMagn1   = block(1);
  sect.ProgMagn2   = block(2);
  sect.ProgMagn3   = block(3);
  sect.ProgMagn4   = block(4);
  % bytes 44-57 are spare
  sect.Checksum    = bytecast(data(idx+58:idx+59), 'L', 'uint16');
end

function [sect len] = readAwacStage(data, idx)
%READAWACSTAGE Reads an Awac Stage Data section (pg 41 of system
% integrator manual).
%
  sect = struct;
  len = 0;

  sect.Sync       = data(idx);
  sect.Id         = data(idx+1);
  block           = bytecast(data(idx+2:idx+21), 'L', 'uint16');
  sect.Size       = block(1);
  len             = sect.Size * 2;
  sect.Blanking   = block(2);
  sect.Pitch      = block(3);
  sect.Roll       = block(4);
  sect.Pressure   = block(5);
  sect.Stage      = block(6);
  sect.Quality    = block(7);
  sect.SoundSpeed = block(8);
  sect.StageP     = block(9);
  sect.QualityP   = block(10);
  % bytes 22-31 are spare
  
  % figure out number of cells from structure size
  nCells = (sect.Size * 2) - 34;
  
  sect.Amp        = bytecast(data(idx+32:idx+32+nCells),   'L', 'uint8');
  sect.Checksum   = bytecast(data(idx+32:idx+32+nCells+1), 'L', 'uint16');
  
end

function [sect len] = readAwacWave(data, idx)
%READAWACWAVE Reads an Awac Wave section (pg 41 of system integrator
% manual).
%
  sect = struct;
  len = 24;

  sect.Sync     = data(idx);
  sect.Id       = data(idx+1);
  block         = bytecast(data(idx+2:idx+17), 'L', 'uint16');
  sect.Size     = block(1);
  sect.Pressure = block(2);
  sect.Distance = block(3);
  sect.Analn    = block(4);
  sect.Vel1     = block(5);
  sect.Vel2     = block(6);
  sect.Vel3     = block(7);
  sect.Vel4     = block(8);
  sect.Amp1     = data(idx+18);
  sect.Amp2     = data(idx+19);
  sect.Amp3     = data(idx+20);
  sect.Amp4     = data(idx+21);
  sect.Checksum = bytecast(data(idx+22:idx+23), 'L', 'uint16');

end

function [sect len] = readContinental(data, idx)
%READCONTINENTAL Reads a Continental Data section (pg 42 of the System
% Integrator Manual).
%
  % structure is same as awac velocity profile data
  [sect len] = readAwacVelocityProfile(data, idx);
end


function [sect len] = readVectrinoVelocityHeader(data, idx)
%READVECTRINOVELOCITYHEADER Reads a Vectrino velocity data header section
% (pg 42 of system integrator manual).
%
  sect = struct;
  len = 42;

  sect.Sync         = data(idx);
  sect.Id           = data(idx+1);
  block             = bytecast(data(idx+2:idx+11), 'L', 'uint16');
  sect.Size         = block(1);
  sect.Distance     = block(2);
  sect.DistQuality  = block(3);
  sect.Lag1         = block(4);
  sect.Lag2         = block(5);
  sect.Noise1       = data(idx+12);
  sect.Noise2       = data(idx+13);
  sect.Noise3       = data(idx+14);
  sect.Noise4       = data(idx+15);
  sect.Correlation1 = data(idx+16);
  sect.Correlation2 = data(idx+17);
  sect.Correlation3 = data(idx+18);
  sect.Correlation4 = data(idx+19);
  block             = bytecast(data(idx+20:idx+23), 'L', 'uint16');
  sect.Temperature  = block(1);
  sect.SoundSpeed   = block(2);
  sect.AmpZ01       = data(idx+24);
  sect.AmpZ02       = data(idx+25);
  sect.AmpZ03       = data(idx+26);
  sect.AmpZ04       = data(idx+27);
  sect.AmpX11       = data(idx+28);
  sect.AmpX12       = data(idx+29);
  sect.AmpX13       = data(idx+30);
  sect.AmpX14       = data(idx+31);
  sect.AmpZ0PLag11  = data(idx+32);
  sect.AmpZ0PLag12  = data(idx+33);
  sect.AmpZ0PLag13  = data(idx+34);
  sect.AmpZ0PLag14  = data(idx+35);
  sect.AmpZ0PLag21  = data(idx+36);
  sect.AmpZ0PLag22  = data(idx+37);
  sect.AmpZ0PLag23  = data(idx+38);
  sect.AmpZ0PLag24  = data(idx+39);
  sect.Checksum     = bytecast(data(idx+40:idx+41), 'L', 'uint16');
end

function [sect len] = readVectrinoVelocity(data, idx)
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
  
  len = 6 + 16*nCells;
  sect.Size = len;
  
  velOff  = idx + 4;
  ampOff  = velOff  + nCells*nBeams*2;
  corrOff = ampOff  + nCells*nBeams;
  csOff   = corrOff + nCells*nBeams;
  
  % velocity
  for k = 1:nBeams
    
    sOff = velOff + (k-1) * (nCells * 2);
    eOff = sOff + (nCells * 2) - 1;
    
    sect.(['Vel' num2str(k)]) = bytecast(data(sOff:eOff), 'L', 'uint16');
  end
  
  % amplitude
  for k = 1:nBeams
    
    sOff = ampOff + (k-1) * nCells;
    eOff = sOff + nCells - 1;
    
    sect.(['Amp' num2str(k)]) = bytecast(data(sOff:eOff), 'L', 'uint8');
  end
  
  % correlation
  for k = 1:nBeams
    
    sOff = corrOff + (k-1) * nCells;
    eOff = sOff + nCells - 1;
    
    vel.(['Corr' num2str(k)]) = bytecast(data(sOff:eOff), 'L', 'uint8');
  end
  
  sect.Checksum = bytecast(data(csOff:csOff+1), 'L', 'uint16');

end

function [sect len] = readVectrinoDistance(data, idx)
%READVECTRINODISTANCE Reads a Vectrino distance data section (pg 43 of
% system integrator manual).
%
  sect = struct;
  len = 16;
  
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
