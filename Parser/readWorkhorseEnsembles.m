function ensembles = readWorkhorseEnsembles( filename )
%READWORKHORSEENSEMBLES Reads in and returns all of the ensembles contained
% in the given binary file retrieved from a Workhorse ADCP.
%
% This function parses a binary file retrieved from a Teledyne RD Workhorse
% ADCP instrument. This function is only able to interpret raw files in the
% PD0 format (as it stands at December 2008). See the Workhorse H-ADCP 
% Operation manual for a description of the output format.
%
% This function is very slow (about 30 seconds on test data of ~8000 
% ensembles/8MB). Re-implementing in C would provide much better performance.
%
% A raw Workhorse data file consists of a set of 'ensembles'. Each ensemble 
% contains data for one sample period. An ensemble is made up of a number
% of sections, the last five of which may or may not be present:
%   - Header:                Ensemble information (size/contents). Always 
%                            present
%   - Fixed Leader Data:     ADCP configuration, serial number etc. Always
%                            present
%   - Variable Leader Data:  Time, temperature, salinity etc. Always
%                            present.
%   - Velocity:              Current velocities for each depth (a.k.a
%                            'bins' or 'cells').
%   - Correlation Magnitude: 'Magnitude of the normalized echo
%                            autocorrelation at the lag used for estimating
%                            the Doppler phase change'. I don't know what
%                            this means.
%   - Echo Intensity:        Echo intensity data. I don't know what this
%                            means.
%   - Percent Good:          Percentage of good data for each depth cell.
%   - Bottom Track Data:     Bottom track data. I don't know what this
%                            means.
%
% This function parses the ensembles, and returns all of them in a cell
% array.
% 
% Inputs:
%   filename  - Raw binary data file retrieved from a Workhorse.
%
% Outputs:
%   ensembles - Cell array of ensembles.
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

  % ensure that there is exactly one argument, 
  % and that it is a string
  error(nargchk(1, 1, nargin));
  if ~ischar(filename), error('filename must be a string'); 
  end

  % check that file exists
  if isempty(dir(filename)), error([filename ' does not exist']); end
  
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
  
  % for performance, the data vector is never sliced. all reads are
  % direct to the data vector. Three absolute indices are used:
  %
  % dIdx == start index of unread data (i.e. after the current ensemble)
  % eIdx == start index of current ensemble
  % sIdx == start index of current section
  % 
  dIdx = 1;
  
  % ensembles are stored in a cell array of structs
  ensembles    = {};
  numEnsembles = 0;
  
  % parse one ensemble at a time until we run out of ensembles
  while dIdx < length(data)
    try
      ensemble = struct;
      
      % find the next ensemble
      eIdx = findEnsemble(data, dIdx);
      
      % no more ensembles in the data
      if isempty(eIdx), break; end
      
      % skip over the ensemble header that was just found
      dIdx = eIdx + 2;
  
      % parse the ensemble header
      [header hLen] = parseHeader(data, eIdx);
      
      % get the ensemble (+2 for checksum)
      eLen = header.numBytesInEnsemble + 2;
      
      % calculate checksum over the entire ensemble
      givenCrc = bytecast(data(eIdx+eLen-2:eIdx+eLen-1), 'L', 'uint16');
      calcCrc  = bitand(sum(data(eIdx:eIdx+eLen-3)), 65535);
      
      % fail if the crcs don't match
      if calcCrc ~= givenCrc, error('ensemble crc check failed'); end
      
      % skip over the entire ensemble
      dIdx = eIdx + eLen;
      
      % parse all the sections in the ensemble
      nCells = 0;
      for m = 1:length(header.dataTypeOffsets)
        
        % get the index to the current section
        sIdx = eIdx + header.dataTypeOffsets(m);
        
        sType = bytecast(data(sIdx:sIdx+1), 'L', 'uint16');
        sect  = [];
        sLen  = 0;
        sName = '';
        
        switch sType
          case 0
            name = 'fixedLeader';
            [sect sLen] = parseFixedLeader(data, sIdx);
            nCells = double(sect.numCells);
          case 128
            name = 'variableLeader';
            [sect sLen] = parseVariableLeader(data, sIdx);
          case 256
            name = 'velocity';
            [sect sLen] = parseVelocity(data, nCells, sIdx);
          case 512
            name = 'corrMag';
            [sect sLen] = parseX(data, nCells, name, sIdx);
          case 768
            name = 'echoIntensity';
            [sect sLen] = parseX(data, nCells, name, sIdx);
          case 1024
            name = 'percentGood';
            [sect sLen] = parseX(data, nCells, name, sIdx);
          case 1280
            % status profile data
          case 1536
            name = 'bottomTrack';
            [sect sLen] = parseBottomTrack(data, sIdx);
          case 2048
            % microCAT data
        end
        
        % add this section to the ensemble struct
        if ~isempty(sect), ensemble.(name) = sect; end
      end
      
      % add this ensemble to the array
      ensembles{numEnsembles+1} = ensemble;
      numEnsembles = numEnsembles + 1;

    catch e
      disp(['skipping ensemble: ' e.message]);
      for m = 1:length(e.stack), disp(e.stack(m)); end
      break;
    end
  end
end

function index = findEnsemble(data, startIdx)
%FINDENSEMBLE Searches in the given byte vector for two consecutive values
% of 7F, indicating the start of the next ensemble section. 
%
% Inputs: 
%   data     - raw byte vector
%   startIdx - index to start searching.
%
% Outputs:
%   index - index into data vector, denoting the start location of the next 
%           ensemble. Empty matrix if no ensemble was found.
%
  index     = [];
  searchIdx = startIdx;

  while searchIdx < length(data)
    
    % this is /so/ much faster than using find(data == 127, 1)
    next = 0;
    for k = searchIdx:length(data)
      if data(k) == 127, next = k; break; end
    end
    
    % no values of 0x7F in the data
    if next == 0, break; end
    
    % we're at the end of the line, and didn't find an ensemble
    if next == length(data), break; end
    
    % found an ensemble
    if data(next+1) == 127
      index = next;
      break; 
    end
    
    % else keep searching
    searchIdx = next+2;
  end
end

function value = bytecast(bytes, endianness, dataType)
%BYTECAST Cast a vector of bytes to the given type. 
% 
% Inputs:
%   bytes      - vector of bytes
%   endianness - endianness of the bytes - 'L' for little, 'B' for big.
%   dataType   - type to cast to, e.g. 'uint8', 'int64' etc.
%
% Outputs:
%   value      - the given bytes cast to the given value.
%
  [m,c,cpuEndianness] = computer;
  if cpuEndianness == endianness, value = typecast(bytes, dataType);
    
  % WILL NOT WORK IF MULTIPLE VALUES ARE PASSED IN. arses
  else                            value = typecast(bytes(end:-1:1), dataType);
  end
  
  value = double(value);
end

function [sect len] = parseHeader( data, idx )
%PARSEHEADER Parses a header section from an ADCP ensemble.
%
% Inputs:
%   data - vector of raw bytes.
%   idx  - index that the header starts at.
%
% Outputs:
%   sect - struct containing the fields that were parsed from the header.
%   len  - number of bytes that were parsed.
%
  sect = struct;
  len = 0;
  
  sect.headerId           = double(data(idx));
  sect.dataSourceId       = double(data(idx+1));
  sect.numBytesInEnsemble = bytecast(data(idx+2:idx+3), 'L', 'uint16');
  % byte 5 is spare
  sect.numDataTypes       = double(data(idx+5));
  
  idx = idx + 6;
  
  sect.dataTypeOffsets = ...
    bytecast(data(idx:idx + 2*sect.numDataTypes-1), 'L', 'uint16');
  
  len = 6 + sect.numDataTypes*2;
end

function [sect len] = parseFixedLeader( data, idx )
%PARSEFIXEDLEADER Parses a fixed leader section from an ADCP ensemble.
%
% Inputs:
%   data - vector of raw bytes.
%   idx  - index that the section starts at.
%
% Outputs:
%   sect - struct containing the fields that were parsed from the fixed 
%          leader section.
%   len  - number of bytes that were parsed.
%
  sect = struct;
  len = 59;
  
  sect.fixedLeaderId       = bytecast(data(idx  :idx+1), 'L', 'uint16');
  sect.cpuFirmwareVersion  = double(data(idx+2));
  sect.cpuFirmwareRevision = double(data(idx+3));
  sect.systemConfiguration = bytecast(data(idx+4:idx+5), 'L', 'uint16');
  sect.realSimFlag         = double(data(idx+6));
  sect.lagLength           = double(data(idx+7));
  sect.numBeams            = double(data(idx+8));
  sect.numCells            = double(data(idx+9));
  block                    = bytecast(data(idx+10:idx+15), 'L', 'uint16');
  sect.pingsPerEnsemble    = block(1);
  sect.depthCellLength     = block(2);
  sect.blankAfterTransmit  = block(3);
  sect.profilingMode       = double(data(idx+16));
  sect.lowCorrThresh       = double(data(idx+17));
  sect.numCodeReps         = double(data(idx+18));
  sect.gdMinimum           = double(data(idx+19));
  sect.errVelocityMax      = bytecast(data(idx+20:idx+21), 'L', 'uint16');
  sect.tppMinutes          = double(data(idx+22));
  sect.tppSeconds          = double(data(idx+23));
  sect.tppHundredths       = double(data(idx+24));
  sect.coordinateTransform = double(data(idx+25));
  block                    = bytecast(data(idx+26:idx+29), 'L', 'int16');
  sect.headingAlignment    = block(1);
  sect.headingBias         = block(2);
  sect.sensorSource        = double(data(idx+30));
  sect.sensorsAvailable    = double(data(idx+31));
  block                    = bytecast(data(idx+32:idx+35), 'L', 'uint16');
  sect.bin1Distance        = block(1);
  sect.xmitPulseLength     = block(2);
  sect.wpRefLayerAvgStart  = double(data(idx+36));
  sect.wpRefLayerAvgEnd    = double(data(idx+37));
  sect.falseTargetThresh   = double(data(idx+38));
  % byte 40 is spare
  sect.transmitLagDistance = bytecast(data(idx+40:idx+41), 'L', 'uint16');
  sect.cpuBoardSerialNo    = bytecast(data(idx+42:idx+49), 'L', 'uint64');
  sect.systemBandwidth     = bytecast(data(idx+50:idx+51), 'L', 'uint16');
  sect.systemPower         = double(data(idx+52));
  % byte 54 is spare
  sect.instSerialNumber    = bytecast(data(idx+54:idx+57), 'L', 'uint32');
  sect.beamAngle           = double(data(idx+58));
end

function [sect len] = parseVariableLeader( data, idx )
%PARSEVARIABLELEADER Parses a variable leader section from an ADCP ensemble.
%
% Inputs:
%   data - vector of raw bytes.
%   idx  - index that the section starts at.
%
% Outputs:
%   sect - struct containing the fields that were parsed from the 
%          variable leader section.
%   len  - number of bytes that were parsed.
%
  sect = struct;
  len = 65;
  
  block                       = bytecast(data(idx  :idx+3), 'L', 'uint16');
  sect.variableLeaderId       = block(1);
  sect.ensembleNumber         = block(2);
  sect.rtcYear                = double(data(idx+4));
  sect.rtcMonth               = double(data(idx+5));
  sect.rtcDay                 = double(data(idx+6));
  sect.rtcHour                = double(data(idx+7));
  sect.rtcMinute              = double(data(idx+8));
  sect.rtcSecond              = double(data(idx+9));
  sect.rtcHundredths          = double(data(idx+10));
  sect.ensembleMsb            = double(data(idx+11));
  block                       = bytecast(data(idx+12:idx+19), 'L', 'uint16');
  sect.bitResult              = block(1);
  sect.speedOfSound           = block(2);
  sect.depthOfTransducer      = block(3);
  sect.heading                = block(4);
  block                       = bytecast(data(idx+20:idx+23), 'L', 'int16');
  sect.pitch                  = block(1);
  sect.roll                   = block(2);
  sect.salinity               = bytecast(data(idx+24:idx+25), 'L', 'uint16');
  sect.temperature            = bytecast(data(idx+26:idx+27), 'L', 'int16');
  sect.mptMinutes             = double(data(idx+28));
  sect.mptSeconds             = double(data(idx+29));
  sect.mptHundredths          = double(data(idx+30));
  sect.hdgStdDev              = double(data(idx+31));
  sect.pitchStdDev            = double(data(idx+32));
  sect.rollStdDev             = double(data(idx+33));
  sect.adcChannel0            = double(data(idx+34));
  sect.adcChannel1            = double(data(idx+35));
  sect.adcChannel2            = double(data(idx+36));
  sect.adcChannel3            = double(data(idx+37));
  sect.adcChannel4            = double(data(idx+38));
  sect.adcChannel5            = double(data(idx+39));
  sect.adcChannel6            = double(data(idx+40));
  sect.adcChannel7            = double(data(idx+41));
  sect.errorStatusWord        = bytecast(data(idx+42:idx+45), 'L', 'uint32');
  % bytes 47-48 are spare
  sect.pressure               = bytecast(data(idx+48:idx+51), 'L', 'uint32');
  sect.pressureSensorVariance = bytecast(data(idx+52:idx+55), 'L', 'uint32');
  % byte 57 is spare
  sect.y2kCentury             = double(data(idx+57));
  sect.y2kYear                = double(data(idx+58));
  sect.y2kMonth               = double(data(idx+59));
  sect.y2kDay                 = double(data(idx+60));
  sect.y2kHour                = double(data(idx+61));
  sect.y2kMinute              = double(data(idx+62));
  sect.y2kSecond              = double(data(idx+63));
  sect.y2kHundredth           = double(data(idx+64));
end

function [sect len] = parseVelocity( data, numCells, idx )
%PARSEVELOCITY Parses a velocity section from an ADCP ensemble.
%
% Inputs:
%   data     - vector of raw bytes.
%   numCells - number of depth cells/bins.
%   idx      - index that the section starts at.
%
% Outputs:
%   sect     - struct containing the fields that were parsed from the 
%              velocity section.
%   len      - number of bytes that were parsed.
%
  sect = struct;
  len = 2 + numCells * 8;
  
  sect.velocityId = bytecast(data(idx:idx+1), 'L', 'uint16');
  
  idx = idx + 2;
  
  vels = bytecast(data(idx:idx + 8*numCells-1), 'L', 'int16');
  
  for k = 1:numCells
    
    sect.velocity1(k) = vels((k-1)*4 + 1);
    sect.velocity2(k) = vels((k-1)*4 + 2);
    sect.velocity3(k) = vels((k-1)*4 + 3);
    sect.velocity4(k) = vels((k-1)*4 + 4);
    
  end
end

function [sect len] = parseX( data, numCells, name, idx )
%PARSEX Parses one of the correlation magnitude, echo intensity or percent 
% good sections from an ADCP ensemble. They all have the same format. 
%
% Inputs:
%   data     - vector of raw bytes.
%   numCells - number of depth cells/bins.
%   name     - what section is being parsed, e.g. 'correlationMagnitude', 
%              'echoIntensity' or 'percentGood'. This is used as a prefix 
%              for the ID field.
%   idx      - index that the section starts at.
%
% Outputs:
%   sect     - struct containing the fields that were parsed from the given 
%              section.
%   len      - number of bytes that were parsed.
%
  sect = struct;
  len = 2 + numCells * 4;
  
  sect.([name 'Id']) = bytecast(data(idx:idx+1), 'L', 'uint16');
  
  idx = idx + 2;
  for k = 1:numCells
    
    sect.field1(k) = double(data(idx  ));
    sect.field2(k) = double(data(idx+1));
    sect.field3(k) = double(data(idx+2));
    sect.field4(k) = double(data(idx+3));
    
    idx = idx + 4;
  end
end

function [sect length] = parseBottomTrack( data, idx )
%PARSEBOTTOMTRACK Parses a bottom track data section from an ADCP
% ensemble.
%
% Inputs:
%   data   - vector of raw bytes.
%   idx    - index that the section starts at.
%
% Outputs:
%   sect   - struct containing the fields that were parsed from trawhe bottom
%            track section.
%   length - number of bytes that were parsed.
%
  sect = struct;
  length = 85;
  
  block                       = bytecast(data(idx  :idx+5), 'L', 'uint16');
  sect.bottomTrackId          = block(1);
  sect.btPingsPerEnsemble     = block(2);
  sect.btDelayBeforeReacquire = block(3);
  sect.btCorrMagMin           = double(data(idx+6));
  sect.btEvalAmpMin           = double(data(idx+7));
  sect.btPercentGoodMin       = double(data(idx+8));
  sect.btMode                 = double(data(idx+9));
  sect.btErrVelMax            = bytecast(data(idx+10:idx+11), 'L', 'uint16');
  % bytes 13-16 are spare
  block                       = bytecast(data(idx+16:idx+31), 'L', 'uint16');
  sect.btBeam1Range           = block(1);
  sect.btBeam2Range           = block(2);
  sect.btBeam3Range           = block(3);
  sect.btBeam4Range           = block(4);
  sect.btBeam1Vel             = block(5);
  sect.btBeam2Vel             = block(6);
  sect.btBeam3Vel             = block(7);
  sect.btBeam4Vel             = block(8);
  sect.btBeam1Corr            = double(data(idx+32));
  sect.btBeam2Corr            = double(data(idx+33));
  sect.btBeam3Corr            = double(data(idx+34));
  sect.btBeam4Corr            = double(data(idx+35));
  sect.btBeam1EvalAmp         = double(data(idx+36));
  sect.btBeam2EvalAmp         = double(data(idx+37));
  sect.btBeam3EvalAmp         = double(data(idx+38));
  sect.btBeam4EvalAmp         = double(data(idx+39));
  sect.btBeam1PercentGood     = double(data(idx+40));
  sect.btBeam2PercentGood     = double(data(idx+41));
  sect.btBeam3PercentGood     = double(data(idx+42));
  sect.btBeam4PercentGood     = double(data(idx+43));
  block                       = bytecast(data(idx+44:idx+49), 'L', 'uint16');
  sect.btRefLayerMin          = block(1);
  sect.btRefLayerNear         = block(2);
  sect.btRefLayerFar          = block(3);
  block                       = bytecast(data(idx+50:idx+57), 'L', 'int16');
  sect.btBeam1RefLayerVel     = block(1);
  sect.btBeam2RefLayerVel     = block(2);
  sect.btBeam3RefLayerVel     = block(3);
  sect.btBeam4RefLayerVel     = block(4);
  sect.btBeam1RefCorr         = double(data(idx+58));
  sect.btBeam2RefCorr         = double(data(idx+59));
  sect.btBeam3RefCorr         = double(data(idx+60));
  sect.btBeam4RefCorr         = double(data(idx+61));
  sect.btBeam1RefInt          = double(data(idx+62));
  sect.btBeam2RefInt          = double(data(idx+63));
  sect.btBeam3RefInt          = double(data(idx+64));
  sect.btBeam4RefInt          = double(data(idx+65));
  sect.btBeam1RefGood         = double(data(idx+66));
  sect.btBeam2RefGood         = double(data(idx+67));
  sect.btBeam3RefGood         = double(data(idx+68));
  sect.btBeam4RefGood         = double(data(idx+69));
  sect.btMaxDepth             = bytecast(data(idx+70:idx+71), 'L', 'uint16');
  sect.btBeam1RssiAmp         = double(data(idx+72));
  sect.btBeam2RssiAmp         = double(data(idx+73));
  sect.btBeam3RssiAmp         = double(data(idx+74));
  sect.btBeam4RssiAmp         = double(data(idx+75));
  sect.btGain                 = double(data(idx+76));
  sect.btBeam1RangeMsb        = double(data(idx+77));
  sect.btBeam2RangeMsb        = double(data(idx+78));
  sect.btBeam3RangeMsb        = double(data(idx+79));
  sect.btBeam4RangeMsb        = double(data(idx+80));
  %bytes 82-85 are spare
end
