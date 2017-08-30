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

% read in all of the structures contained in the file
% all files should start off with the following sections,
% although this is not checked:
%   hardware configuration
%   head configuration
%   user configuration
%
structures = struct;
[~, ~, cpuEndianness] = computer;

% list of sectors with their Ids and their Size
genericIds  = [ 5;   4;   0];
genericSize = [48; 224; 512];

continentalIds  = 36;
continentalSize = NaN; % NaN means variable

aquadoppVelocityIds  = [ 1;  6; 128];
aquadoppVelocitySize = [42; 36;  42];

aquadoppProfilerIds  = [ 33; 48; 49;  42];
aquadoppProfilerSize = [NaN; 24; 60; NaN];

awacIds  = [ 32; 54;  66];
awacSize = [NaN; 24; NaN];

prologIds  = [96; 97;  98;  99; 101; 106];
prologSize = [80; 48; NaN; NaN; NaN; NaN]; % Wave fourier coefficient spectrum (id99) is actually not fixed length of 816!

knownIds   = [genericIds;  continentalIds;  aquadoppVelocityIds;  aquadoppProfilerIds;  awacIds;  prologIds];
knownSizes = [genericSize; continentalSize; aquadoppVelocitySize; aquadoppProfilerSize; awacSize; prologSize];

noSizeIds  = [16; 54; 81]; % a few sectors do not include their size in their data
noSizeSize = [24; 24; 22]; % yet for these sectors the size is known

% we look for any start of record structure
% Sync = 165 % hex a5
iSync = data == 165;

% we check that the id following any Sync is known
% otherwise we get rid of those false Syncs
iId = ismember(data, knownIds);
iSync = [iSync(1:end-1) & iId(2:end); false];

% we check that the size read in data record (when exist) is consistent 
% with the expected one (when known) otherwise we get rid of those false Syncs.
iIds = [false; iSync(1:end-1)];
ids = data(iIds);
uniqIds = unique(sort(ids));

iSizes = [false; false; iSync(1:end-2)] | [false; false; false; iSync(1:end-3)];
sizesFromData = bytecast(data(iSizes), 'L', 'uint16', cpuEndianness)*2; % 1 word = 2 bytes

% when size info not available from sector we replace it with its expected value
for i=1:length(noSizeIds), sizesFromData(ids == noSizeIds(i)) = noSizeSize(i); end

sizesExpected = NaN(size(ids)); % when size is not known, set to NaN
for i = 1:length(uniqIds)
    sectorType = uniqIds(i);
    sizesExpected(ids == sectorType) = knownSizes(sectorType == knownIds);
end
iUnkownSize = isnan(sizesExpected);
sizesExpected(iUnkownSize) = sizesFromData(iUnkownSize);

iSizeConsistent = sizesFromData == sizesExpected;
iSync(iSync) = iSizeConsistent;
clear sizesExpected;

% we check that the size read in data record (when exist) is consistent 
% with the one found between 2 Sync
iIds = [false; iSync(1:end-1)];
ids = data(iIds);
uniqIds = unique(sort(ids));

iSizes = [false; false; iSync(1:end-2)] | [false; false; false; iSync(1:end-3)];
sizesFromData = bytecast(data(iSizes), 'L', 'uint16', cpuEndianness)*2; % 1 word = 2 bytes

% when size info not available from sector we replace it with its expected value
for i=1:length(noSizeIds), sizesFromData(ids == noSizeIds(i)) = noSizeSize(i); end

sizesFromSync = diff(find([iSync; true]));
isSizeConsistent = sizesFromData == sizesFromSync;

% most of the time inconsistencies are due to false Sync detection,
% a false Sync will divide a section in multiple pairs
isPairInconsistent = [false; (~isSizeConsistent(1:end-1) & ~isSizeConsistent(2:end))];

% when several inconsistent pairs in a row (next to each other), we only 
% want to remove one at a time (the last one)
isPairInconsistent = [xor(isPairInconsistent(1:end-1), isPairInconsistent(2:end)); false] & isPairInconsistent;

while any(isPairInconsistent)
    iSync(iSync) = ~isPairInconsistent;
    
    iIds = [false; iSync(1:end-1)];
    ids = data(iIds);
    uniqIds = unique(sort(ids));
   
    iSizes = [false; false; iSync(1:end-2)] | [false; false; false; iSync(1:end-3)];
    sizesFromData = bytecast(data(iSizes), 'L', 'uint16', cpuEndianness)*2; % 1 word = 2 bytes
    
    % when size info not available from sector we replace it with its expected value
    for i=1:length(noSizeIds), sizesFromData(ids == noSizeIds(i)) = noSizeSize(i); end

    sizesFromSync = diff(find([iSync; true]));
    isSizeConsistent = sizesFromData == sizesFromSync;
    isPairInconsistent = [false; ~isSizeConsistent(1:end-1) & ~isSizeConsistent(2:end)];
    
    isPairInconsistent = [xor(isPairInconsistent(1:end-1), isPairInconsistent(2:end)); false] & isPairInconsistent;
end

% now we need to deal with any fault sync detection left alone
if any(~isSizeConsistent)
    iSync(iSync) = [true; isSizeConsistent(1:end-1)];
    
    % we also handle the case when the last section has been truncated so 
    % that we don't try to read it at all
    if ~isSizeConsistent(end)
        iSync(iSync) = [true(sum(iSync)-1, 1); false];
    end
    
    iIds = [false; iSync(1:end-1)];
    ids = data(iIds);
    uniqIds = unique(sort(ids));
    
    iSizes = [false; false; iSync(1:end-2)] | [false; false; false; iSync(1:end-3)];
    sizesFromData = bytecast(data(iSizes), 'L', 'uint16', cpuEndianness)*2; % 1 word = 2 bytes
    
    % when size info not available from sector we replace it with its expected value
    for i=1:length(noSizeIds), sizesFromData(ids == noSizeIds(i)) = noSizeSize(i); end
end
clear iIds iSizes sizesFromSync;

% now we can read data sectors by type
for i = 1:length(uniqIds)
    sectorType = uniqIds(i);
    
    iId = ids == sectorType;
    
    sizeSections = sizesFromData(iId);
    
    sizeSections = unique(sizeSections);
    
    if length(sizeSections) > 1
        fprintf('%s\n', ['Warning : ' filename ' contains data sector type of varying size!']);
        fprintf('%s\n', ['Cannot read this sector type : hex ' dec2hex(sectorType) ' == ' num2str(sectorType) ', with vectorised code.']);
        continue;
    end
    
    iSyncThisId = iSync;
    iSyncThisId(iSyncThisId) = iId;
    
    indexSyncStart = find(iSyncThisId);
    indexSyncEnd   = indexSyncStart + sizeSections - 1;
    for j=1:length(indexSyncStart)
        iSyncThisId(indexSyncStart(j):indexSyncEnd(j)) = true;
    end
    clear indexSyncStart indexSyncEnd indexSync;
    
    dataSection = data(iSyncThisId);
    clear iSyncThisId;
    dataSection = reshape(dataSection, sizeSections, length(dataSection)/sizeSections)';
    
    % read the section in
    switch sectorType
        case 0,   sect = readUserConfiguration            (dataSection, cpuEndianness); % 0x00
        case 1,   sect = readAquadoppVelocity             (dataSection, cpuEndianness); % 0x01
        case 2,   sect = readVectrinoDistance             (dataSection, cpuEndianness); % 0x02
        case 4,   sect = readHeadConfiguration            (dataSection, cpuEndianness); % 0x04
        case 5,   sect = readHardwareConfiguration        (dataSection, cpuEndianness); % 0x05
        case 6,   sect = readAquadoppDiagHeader           (dataSection, cpuEndianness); % 0x06
        case 7,   sect = readVectorProbeCheck             (dataSection, cpuEndianness); % 0x07
        case 16,  sect = readVectorVelocity               (dataSection, cpuEndianness); % 0x10
        case 17,  sect = readVectorSystem                 (dataSection, cpuEndianness); % 0x11
        case 18,  sect = readVectorVelocityHeader         (dataSection, cpuEndianness); % 0x12
        case 32,  sect = readAwacVelocityProfile          (dataSection, cpuEndianness); % 0x20
        case 33,  sect = readAquadoppProfilerVelocity     (dataSection, cpuEndianness); % 0x21, 3-beam aquadopp
        %    case 34,  sect = readAquadoppProfilerVelocity     (dataSection, cpuEndianness); % 0x22, 2-beam aquadopp
        %    case 35,  sect = readAquadoppProfilerVelocity     (dataSection, cpuEndianness); % 0x23, 1-beam aquadopp
        case 36,  sect = readContinental                  (dataSection, cpuEndianness); % 0x24, 3-beam continental
        %    case 37,  sect = readContinental                  (dataSection, cpuEndianness); % 0x25, 2-beam continental
        %    case 38,  sect = readContinental                  (dataSection, cpuEndianness); % 0x26, 1-beam continental
        case 42,  sect = readHRAquadoppProfile            (dataSection, cpuEndianness); % 0x2A
        case 48,  sect = readAwacWaveData                 (dataSection, cpuEndianness); % 0x30
        case 49,  sect = readAwacWaveHeader               (dataSection, cpuEndianness); % 0x31
        case 54,  sect = readAwacWaveDataSUV              (dataSection, cpuEndianness); % 0x36
        case 66,  sect = readAwacStageData                (dataSection, cpuEndianness); % 0x42
        case 80,  sect = readVectrinoVelocityHeader       (dataSection, cpuEndianness); % 0x50
        case 81,  sect = readVectrinoVelocity             (dataSection, cpuEndianness); % 0x51
        case 96,  sect = readWaveParameterEstimates       (dataSection, cpuEndianness); % 0x60
        case 97,  sect = readWaveBandEstimates            (dataSection, cpuEndianness); % 0x61
        case 98,  sect = readWaveEnergySpectrum           (dataSection, cpuEndianness); % 0x62
        case 99,  sect = readWaveFourierCoefficentSpectrum(dataSection, cpuEndianness); % 0x63
        case 101, sect = readAwacAST                      (dataSection, cpuEndianness); % 0x65
        case 106, sect = readAwacProcessedVelocity        (dataSection, cpuEndianness); % 0x6A
        case 128, sect = readAquadoppDiagnostics          (dataSection, cpuEndianness); % 0x80
    end

    if isempty(sect), continue; end
    
    % generate and compare checksum - all section
    % structs have a Checksum field
    cs = genChecksum(dataSection(:, 1:end-2));
    clear dataSection;
    iBadChecksum = cs ~= vertcat(sect(:).Checksum);
    if any(iBadChecksum)
        % we don't want to keep a record with erroneous data in it
        sect(iBadChecksum) = [];
        
        if isempty(sect), continue; end
    end
    clear cs iBadChecksum;
    
    curField = ['Id' sprintf('%d', sect(1).Id)];
    structures.(curField) = sect;
    clear sect;
end
clear data iSync sizesFromData;

end

%
% The functions below read in each of the data structures
% specified in the System integrator Manual.
%

function cd = readClockData(data)
%READCLOCKDATA Reads a clock data section (pg 29 of system integrator
%manual) and returns a matlab serial date.
%

date = double(10*bitand(bitshift(data, -4), 15) + bitand(data, 15));

minute = date(:, 1);
second = date(:, 2);
day    = date(:, 3);
hour   = date(:, 4);
year   = date(:, 5);
month  = date(:, 6);

% pg 52 of system integrator manual
if year >= 90, year = year + 1900;
else           year = year + 2000;
end

%   cd = datenum(year, month, day, hour, minute, second);
cd = datenummx(year, month, day, hour, minute, second); % direct access to MEX function, faster
end

function sect = readHardwareConfiguration(data, cpuEndianness)
%READHARDWARECONFIGURATION
% Id=0x05, Hardware Configuration
% SYSTEM INTEGRATOR MANUAL (Dec 2014) pg 28-29

nRecords = size(data, 1);

Sync       = data(:, 1);
Id         = data(:, 2);
Size       = data(:, 3:4); % uint16
SerialNo   = data(:, 5:18);
SerialNo(SerialNo == 0) = 32; % replace 0 by 32: code for whitespace
SerialNo   = char(SerialNo);
block      = data(:, 19:30); % uint16
% bytes 30-41 are free, but
% data(idx+30:idx+31) == (103,103) if HR
Spare      = data(:, 31:42);

FWversion  = data(:, 43:46);
FWversion(FWversion == 0) = 32; % replace 0 by 32: code for whitespace
FWversion  = char(FWversion);
Checksum   = data(:, 47:48); % uint16

% let's process uint16s in one call
blocks = bytecast(reshape([Size block Checksum]', [], 1), 'L', 'uint16', cpuEndianness);
Size       = blocks(1:8:end);
Config     = blocks(2:8:end);
Frequency  = blocks(3:8:end);
PICversion = blocks(4:8:end);
HWrevision = blocks(5:8:end);
RecSize    = blocks(6:8:end);
Status     = uint16(blocks(7:8:end));
Checksum   = blocks(8:8:end);

if nRecords > 1
    Sync       = num2cell(Sync);
    Id         = num2cell(Id);
    Size       = num2cell(Size);
    SerialNo   = mat2cell(SerialNo, ones(1, nRecords), 14);
    FWversion  = mat2cell(SerialNo, ones(1, nRecords), 4);
    Checksum   = num2cell(Checksum);
    Config     = num2cell(Config);
    Frequency  = num2cell(Frequency);
    PICversion = num2cell(PICversion);
    HWrevision = num2cell(HWrevision);
    RecSize    = num2cell(RecSize);
    Status     = num2cell(Status);
end

SerialNo = strtrim(SerialNo);
FWversion = strtrim(FWversion);

% safety check that if instrument type is HR then the returned
% structure should contain Id42 sectors.
instrumentType = 'UNKNOWN';
if any(strfind(SerialNo, 'VNO'))
    instrumentType = 'VECTRINO';
elseif any(strfind(SerialNo, 'VEC'))
    instrumentType = 'VECTOR';
elseif any(strfind(SerialNo, 'AQD'))
    %https://github.com/pjrusello/Nortek-Binary-Ready-Utilities/blob/master/NortekDataStructure.py
    %hrFlag == '\x67\x67', hex 0x67 = dec 103
    if Spare(1, 1) == 103 && Spare(1, 2) == 103
        instrumentType = 'HR_PROFILER';
    else
        instrumentType = 'AQUADOPP_PROFILER';
    end
elseif any(strfind(SerialNo, 'WPR'))
    instrumentType = 'AWAC';
end

if nRecords > 1
    nChar = length(instrumentType);
    instrumentType = repmat(instrumentType, nRecords, 1);
    instrumentType = mat2cell(instrumentType, ones(1, nRecords), nChar);
end

sect = struct('Sync', Sync, ...
    'Id', Id, ...
    'Size', Size, ...
    'SerialNo', SerialNo, ...
    'FWversion', FWversion, ...
    'Checksum', Checksum, ...
    'Config', Config, ...
    'Frequency', Frequency, ...
    'PICversion', PICversion, ...
    'HWrevision', HWrevision, ...
    'RecSize', RecSize, ...
    'Status', Status, ...
    'instrumentType', instrumentType);

end

function sect = readHeadConfiguration(data, cpuEndianness)
%READHEADCONFIGURATION Reads a head configuration section.
% Id=0x04, Head Configuration
% SYSTEM INTEGRATOR MANUAL (Dec 2014) pg 29

nRecords = size(data, 1);

Sync      = data(:, 1);
Id        = data(:, 2);
block1    = data(:, 3:10);  % uint16
SerialNo  = data(:, 11:22);
SerialNo(SerialNo == 0) = 32; % replace 0 by 32: code for whitespace
SerialNo  = char(SerialNo);

% MUST CHECK ARRAY LAYOUT
System5  = bytecast(reshape(data(:, 23:30)', [], 1), 'L', 'uint16', cpuEndianness);
System5  = reshape(System5, [], nRecords)';

TransformationMatrix = bytecast(reshape(data(:, 31:48)', [], 1), 'L', 'int16', cpuEndianness)/4096;
TransformationMatrix = permute(reshape(TransformationMatrix, 3, 3, nRecords), [2 1 3]); % transpose a 3d matrix with permute

System7 = bytecast(reshape(data(:, 49:64)', [], 1), 'L', 'int16', cpuEndianness);
System7 = permute(reshape(System7, 4, 2, nRecords), [2 1 3]); % transpose a 3d matrix with permute

System8 = bytecast(reshape(data(:, 67:84)', [], 1), 'L', 'int16', cpuEndianness);
System8 = permute(reshape(System8, 3, 3, nRecords), [2 1 3]); % transpose a 3d matrix with permute

System9 = bytecast(reshape(data(:, 85:102)', [], 1), 'L', 'int16', cpuEndianness);
System9 = permute(reshape(System9, 3, 3, nRecords), [2 1 3]); % transpose a 3d matrix with permute

System10 = bytecast(reshape(data(:, 103:110)', [], 1), 'L', 'int16', cpuEndianness);
System10 = reshape(System10, [], nRecords)';

System11 = bytecast(reshape(data(:, 111:118)', [], 1), 'L', 'int16', cpuEndianness);
System11 = reshape(System11, [], nRecords)';

PressureSensorCalibration = bytecast(reshape(data(:, 119:126)', [], 1), 'L', 'uint16', cpuEndianness);
PressureSensorCalibration = reshape(PressureSensorCalibration, [], nRecords)';

System13 = bytecast(reshape(data(:, 127:134)', [], 1), 'L', 'int16', cpuEndianness);
System13 = reshape(System13, [], nRecords)';

System14 = bytecast(reshape(data(:, 135:150)', [], 1), 'L', 'int16', cpuEndianness);
System14 = permute(reshape(System14, 4, 2, nRecords), [2 1 3]); % transpose a 3d matrix with permute

System15 = bytecast(reshape(data(:, 151:182)', [], 1), 'L', 'int16', cpuEndianness);
System15 = permute(reshape(System15, 4, 4, nRecords), [2 1 3]); % transpose a 3d matrix with permute

System16 = bytecast(reshape(data(:, 183:190)', [], 1), 'L', 'int16', cpuEndianness);
System16 = reshape(System16, [], nRecords)';

System17 = bytecast(reshape(data(:, 191:192)', [], 1), 'L', 'int16', cpuEndianness);
System17 = reshape(System17, [], nRecords)';

System18 = bytecast(reshape(data(:, 193:194)', [], 1), 'L', 'int16', cpuEndianness);
System18 = reshape(System18, [], nRecords)';

System19 = bytecast(reshape(data(:, 195:196)', [], 1), 'L', 'int16', cpuEndianness);
System19 = reshape(System19, [], nRecords)';

System20 = bytecast(reshape(data(:, 197:198)', [], 1), 'L', 'int16', cpuEndianness);
System20 = reshape(System20, [], nRecords)';

% bytes 198-219 are free
block2   = data(:, 221:224);  % uint16

% let's process uint16s in one call
blocks    = bytecast(reshape([block1, block2]', [], 1), 'L', 'uint16', cpuEndianness);
Size      = blocks(1:6:end);
Config    = blocks(2:6:end);
Frequency = blocks(3:6:end);
Type      = blocks(4:6:end);
NBeams    = blocks(5:6:end);
Checksum  = blocks(6:6:end);

if nRecords > 1
    Sync = num2cell(Sync);
    Id = num2cell(Id);
    SerialNo = mat2cell(SerialNo, ones(1, nRecords), 12);
    System5 = mat2cell(System5, ones(1, nRecords), 4);
    TransformationMatrix = mat2cell(TransformationMatrix, 3, 3, ones(1, nRecords));
    System7 = mat2cell(System7, 2, 4, ones(1, nRecords));
    System8 = mat2cell(System8, 3, 3, ones(1, nRecords));
    System9 = mat2cell(System9, 3, 3, ones(1, nRecords));
    System10 = mat2cell(System10, ones(1, nRecords), 4);
    System11 = mat2cell(System11, ones(1, nRecords), 4);
    PressureSensorCalibration = mat2cell(PressureSensorCalibration, ones(1, nRecords), 4);
    System13 = mat2cell(System13, ones(1, nRecords), 4);
    System14 = mat2cell(System14, 2, 4, ones(1, nRecords));
    System15 = mat2cell(System15, 4, 4, ones(1, nRecords));
    System16 = mat2cell(System16, ones(1, nRecords), 4);
    System17 = num2cell(System17);
    System18 = num2cell(System18);
    System19 = num2cell(System19);
    System20 = num2cell(System20);
    Size = num2cell(Size);
    Config = num2cell(Config);
    Frequency = num2cell(Frequency);
    Type = num2cell(Type);
    NBeams = num2cell(NBeams);
    Checksum = num2cell(Checksum);
end

SerialNo = strtrim(SerialNo);

sect = struct('Sync', Sync, ...
    'Id', Id, ...
    'SerialNo', SerialNo, ...
    'System5', System5, ...
    'TransformationMatrix', squeeze(permute(TransformationMatrix, [3 1 2])), ...
    'System7', squeeze(permute(System7, [3 1 2])), ...
    'System8', squeeze(permute(System8, [3 1 2])), ...
    'System9', squeeze(permute(System9, [3 1 2])), ...
    'System10', System10, ...
    'System11', System11, ...
    'PressureSensorCalibration', PressureSensorCalibration, ...
    'System13', System13, ...
    'System14', squeeze(permute(System14, [3 1 2])), ...
    'System15', squeeze(permute(System15, [3 1 2])), ...
    'System16', System16, ...
    'System17', System17, ...
    'System18', System18, ...
    'System19', System19, ...
    'System20', System20, ...
    'Size', Size, ...
    'Config', Config, ...
    'Frequency', Frequency, ...
    'Type', Type, ...
    'NBeams', NBeams, ...
    'Checksum', Checksum);
end

function sect = readUserConfiguration(data, cpuEndianness)
%readUserConfiguration Reads a user configuration section.
% Id=0x00, User Configuration
% SYSTEM INTEGRATOR MANUAL (Dec 2014) pg 30-32

nRecords = size(data, 1);

Sync           = data(:, 1);
Id             = data(:, 2);
block1         = data(:, 3:40);  % uint16
DeployName     = data(:, 41:46);
DeployName(DeployName == 0) = 32; % replace 0 by 32: code for whitespace
DeployName     = char(DeployName);
WrapMode       = data(:, 47:48);  % uint16
clockDeploy    = readClockData(data(:, 49:54));
DiagInterval   = bytecast(reshape(data(:, 55:58)', [], 1), 'L', 'uint32', cpuEndianness);
block2         = data(:, 59:74); % uint16
% bytes 74-75 are spare
VelAdjTable    = 0; % 180 bytes; not sure what to do with them
Comments       = data(:, 257:436);
Comments(Comments == 0) = 32; % replace 0 by 32: code for whitespace
Comments       = char(Comments);
block3         = data(:, 437:464); % uint16
% bytes 464-493 are spare
QualConst      = 0; % 16 bytes
Checksum       = data(:, 511:512); % uint16

% let's process uint16s in one call
blocks = bytecast(reshape([block1 WrapMode block2 block3 Checksum]', [], 1), 'L', 'uint16', cpuEndianness);
Size           = blocks(1:43:end);
T1             = blocks(2:43:end);
T2             = blocks(3:43:end);
T3             = blocks(4:43:end);
T4             = blocks(5:43:end);
T5             = blocks(6:43:end);
NPings         = blocks(7:43:end);
AvgInterval    = blocks(8:43:end);
NBeams         = blocks(9:43:end);
TimCtrlReg     = uint16(blocks(10:43:end));
PwrCtrlReg     = uint16(blocks(11:43:end));
A1_1           = blocks(12:43:end);
B0_1           = blocks(13:43:end);
B1_1           = blocks(14:43:end);
CompassUpdRate = blocks(15:43:end);
CoordSystem    = blocks(16:43:end);
NBins          = blocks(17:43:end);
BinLength      = blocks(18:43:end);
MeasInterval   = blocks(19:43:end);
WrapMode       = blocks(20:43:end);
Mode           = uint16(blocks(21:43:end));
AdjSoundSpeed  = blocks(22:43:end);
NSampDiag      = blocks(23:43:end);
NBeamsCellDiag = blocks(24:43:end);
NPingsDiag     = blocks(25:43:end);
ModeTest       = uint16(blocks(26:43:end));
AnalnAddr      = blocks(27:43:end);
SWVersion      = blocks(28:43:end);
WMMode         = blocks(29:43:end);
DynPercPos     = blocks(30:43:end);
WT1            = blocks(31:43:end);
WT2            = blocks(32:43:end);
WT3            = blocks(33:43:end);
NSamp          = blocks(34:43:end);
A1_2           = blocks(35:43:end);
B0_2           = blocks(36:43:end);
B1_2           = blocks(37:43:end);
% bytes 454-455 are spare
AnaOutScale    = blocks(39:43:end);
CorrThresh     = blocks(40:43:end);
% bytes 460-461 are spare
TiLag2         = blocks(42:43:end);
Checksum       = blocks(43:43:end);

if nRecords > 1
    Sync           = num2cell(Sync);
    Id             = num2cell(Id);
    DeployName     = mat2cell(Comments, ones(1, nRecords), 6);
    clockDeploy    = num2cell(clockDeploy);
    DiagInterval   = num2cell(DiagInterval);
    VelAdjTable    = num2cell(VelAdjTable);
    Comments       = mat2cell(Comments, ones(1, nRecords), 180);
    QualConst      = num2cell(QualConst);
    Checksum       = num2cell(Checksum);
    Size           = num2cell(Size);
    T1             = num2cell(T1);
    T2             = num2cell(T2);
    T3             = num2cell(T3);
    T4             = num2cell(T4);
    T5             = num2cell(T5);
    NPings         = num2cell(NPings);
    AvgInterval    = num2cell(AvgInterval);
    NBeams         = num2cell(NBeams);
    TimCtrlReg     = num2cell(TimCtrlReg);
    PwrCtrlReg     = num2cell(PwrCtrlReg);
    A1_1           = num2cell(A1_1);
    B0_1           = num2cell(B0_1);
    B1_1           = num2cell(B1_1);
    CompassUpdRate = num2cell(CompassUpdRate);
    CoordSystem    = num2cell(CoordSystem);
    NBins          = num2cell(NBins);
    BinLength      = num2cell(BinLength);
    MeasInterval   = num2cell(MeasInterval);
    WrapMode       = num2cell(WrapMode);
    Mode           = mat2cell(Mode, ones(1, nRecords), 8);
    AdjSoundSpeed  = num2cell(AdjSoundSpeed);
    NSampDiag      = num2cell(NSampDiag);
    NBeamsCellDiag = num2cell(NBeamsCellDiag);
    NPingsDiag     = num2cell(NPingsDiag);
    ModeTest       = num2cell(ModeTest);
    AnalnAddr      = num2cell(AnalnAddr);
    SWVersion      = num2cell(SWVersion);
    WMMode         = num2cell(WMMode);
    DynPercPos     = num2cell(DynPercPos);
    WT1            = num2cell(WT1);
    WT2            = num2cell(WT2);
    WT3            = num2cell(WT3);
    NSamp          = num2cell(NSamp);
    A1_2           = num2cell(A1_2);
    B0_2           = num2cell(B0_2);
    B1_2           = num2cell(B1_2);
    AnaOutScale    = num2cell(AnaOutScale);
    CorrThresh     = num2cell(CorrThresh);
    TiLag2         = num2cell(TiLag2);
end

DeployName = strtrim(DeployName);
Comments   = strtrim(Comments);

sect = struct('Sync', Sync, ...
    'Id', Id, ...
    'DeployName', DeployName, ...
    'WrapMode', WrapMode, ...
    'clockDeploy', clockDeploy, ...
    'DiagInterval', DiagInterval, ...
    'VelAdjTable', VelAdjTable, ...
    'Comments', Comments, ...
    'QualConst', QualConst, ...
    'Checksum', Checksum, ...
    'Size', Size, ...
    'T1', T1, ...
    'T2', T2, ...
    'T3', T3, ...
    'T4', T4, ...
    'T5', T5, ...
    'NPings', NPings, ...
    'AvgInterval', AvgInterval, ...
    'NBeams', NBeams, ...
    'TimCtrlReg', TimCtrlReg, ...
    'PwrCtrlReg', PwrCtrlReg, ...
    'A1_1', A1_1, ...
    'B0_1', B0_1, ...
    'B1_1', B1_1, ...
    'CompassUpdRate', CompassUpdRate, ...
    'CoordSystem', CoordSystem, ...
    'NBins', NBins, ...
    'BinLength', BinLength, ...
    'MeasInterval', MeasInterval, ...
    'Mode', Mode, ...
    'AdjSoundSpeed', AdjSoundSpeed, ...
    'NSampDiag', NSampDiag, ...
    'NBeamsCellDiag', NBeamsCellDiag, ...
    'NPingsDiag', NPingsDiag, ...
    'ModeTest', ModeTest, ...
    'AnalnAddr', AnalnAddr, ...
    'SWVersion', SWVersion, ...
    'WMMode', WMMode, ...
    'DynPercPos', DynPercPos, ...
    'WT1', WT1, ...
    'WT2', WT2, ...
    'WT3', WT3, ...
    'NSamp', NSamp, ...
    'A1_2', A1_2, ...
    'B0_2', B0_2, ...
    'B1_2', B1_2, ...
    'AnaOutScale', AnaOutScale, ...
    'CorrThresh', CorrThresh, ...
    'TiLag2', TiLag2);

end

function sect = readAquadoppVelocity(data, cpuEndianness)
%READAQUADOPPVELOCITY Reads an Aquadopp velocity data section.
% Id=0x01, Aquadopp Velocity Data
% SYSTEM INTEGRATOR MANUAL (Dec 2014) pg 34-35

nRecords = size(data, 1);

Sync        = data(:, 1);
Id          = data(:, 2);
Size        = data(:, 3:4); % uint16
Time        = readClockData(data(:, 5:10));

Error       = data(:, 11:12); % int16
block1      = data(:, 13:18); % uint16
% !!! Heading, pitch and roll can be negative => signed integer
block2      = data(:, 19:24); % int16

PressureMSB = data(:, 25); % uint8
% 8 bits status code http://cs.nortek.no/scripts/customer.fcgi?_sf=0&custSessionKey=&customerLang=en&noCookies=true&action=viewKbEntry&id=7
Status      = uint8(data(:, 26));

PressureLSW = data(:, 27:28); % uint16
% !!! temperature and velocity can be negative
block3      = data(:, 29:36); % int16
block4      = data(:, 37:40); % uint8
Checksum    = data(:, 41:42); % uint16

% let's process uint16s in one call
blocks = bytecast(reshape([Size block1 PressureLSW Checksum]', [], 1), 'L', 'uint16', cpuEndianness);
Size        = blocks(1:6:end);
Analn1      = blocks(2:6:end);
Battery     = blocks(3:6:end);
Analn2      = blocks(4:6:end);
PressureLSW = blocks(5:6:end);
Checksum    = blocks(6:6:end);

% let's process int16s in one call
blocks = bytecast(reshape([Error block2 block3]', [], 1), 'L', 'int16', cpuEndianness);
Error       = blocks(1:8:end);
Heading     = blocks(2:8:end);
Pitch       = blocks(3:8:end);
Roll        = blocks(4:8:end);
Temperature = blocks(5:8:end);
Vel1        = blocks(6:8:end);
Vel2        = blocks(7:8:end);
Vel3        = blocks(8:8:end);

% let's process uint8s in one call
blocks = bytecast(reshape([PressureMSB block4]', [], 1), 'L', 'uint8', cpuEndianness);
PressureMSB = blocks(1:5:end);
Amp1        = blocks(2:5:end);
Amp2        = blocks(3:5:end);
Amp3        = blocks(4:5:end);
Fill        = blocks(5:5:end);

if nRecords > 1
    Sync = num2cell(Sync);
    Id = num2cell(Id);
    Size = num2cell(Size);
    Time = num2cell(Time);
    Error = num2cell(Error);
    PressureMSB = num2cell(PressureMSB);
    Status = num2cell(Status);
    PressureLSW = num2cell(PressureLSW);
    Checksum = num2cell(Checksum);
    Analn1 = num2cell(Analn1);
    Battery = num2cell(Battery);
    Analn2 = num2cell(Analn2);
    Heading = num2cell(Heading);
    Pitch = num2cell(Pitch);
    Roll = num2cell(Roll);
    Temperature = num2cell(Temperature);
    Vel1 = num2cell(Vel1);
    Vel2 = num2cell(Vel2);
    Vel3 = num2cell(Vel3);
    Amp1 = num2cell(Amp1);
    Amp2 = num2cell(Amp2);
    Amp3 = num2cell(Amp3);
    Fill = num2cell(Fill);
end

sect = struct('Sync', Sync, ...
    'Id', Id, ...
    'Size', Size, ...
    'Time', Time, ...
    'Error', Error, ...
    'PressureMSB', PressureMSB, ...
    'Status', Status, ...
    'PressureLSW', PressureLSW, ...
    'Checksum', Checksum, ...
    'Analn1', Analn1, ...
    'Battery', Battery, ...
    'Analn2', Analn2, ...
    'Heading', Heading, ...
    'Pitch', Pitch, ...
    'Roll', Roll, ...
    'Temperature', Temperature, ...
    'Vel1', Vel1, ...
    'Vel2', Vel2, ...
    'Vel3', Vel3, ...
    'Amp1', Amp1, ...
    'Amp2', Amp2, ...
    'Amp3', Amp3, ...
    'Fill', Fill);

end

function sect = readAquadoppDiagHeader(data, cpuEndianness)
%READAQUADOPPDIAGHEADER Reads an Aquadopp diagnostics header section.
% Id=0x06, Aquadopp Diagnostics Data Header
% SYSTEM INTEGRATOR MANUAL (Dec 2014) pg 35

nRecords = size(data, 1);

Sync      = data(:, 1);
Id        = data(:, 2);
block1    = data(:, 3:8); % uint16
block3    = data(:, 9:12); % uint8
block2    = data(:, 13:28); % uint16
% bytes 29-34 are spare
Checksum  = data(:, 35:36); % uint16

% let's process uint16s in one call
blocks = bytecast(reshape([block1 block2 Checksum]', [], 1), 'L', 'uint16', cpuEndianness);
Size      = blocks(1:12:end);
Records   = blocks(2:12:end);
Cell      = blocks(3:12:end);
ProcMagn1 = blocks(4:12:end);
ProcMagn2 = blocks(5:12:end);
ProcMagn3 = blocks(6:12:end);
ProcMagn4 = blocks(7:12:end);
Distance1 = blocks(8:12:end);
Distance2 = blocks(9:12:end);
Distance3 = blocks(10:12:end);
Distance4 = blocks(11:12:end);
Checksum  = blocks(12:12:end);

% let's process uint8s in one call
blocks = bytecast(reshape(block3', [], 1), 'L', 'uint8', cpuEndianness);
Noise1    = blocks(1:4:end);
Noise2    = blocks(2:4:end);
Noise3    = blocks(3:4:end);
Noise4    = blocks(4:4:end);

if nRecords > 1
    Sync = num2cell(Sync);
    Id = num2cell(Id);
    Checksum = num2cell(Checksum);
    Size = num2cell(Size);
    Records = num2cell(Records);
    Cell = num2cell(Cell);
    ProcMagn1 = num2cell(ProcMagn1);
    ProcMagn2 = num2cell(ProcMagn2);
    ProcMagn3 = num2cell(ProcMagn3);
    ProcMagn4 = num2cell(ProcMagn4);
    Distance1 = num2cell(Distance1);
    Distance2 = num2cell(Distance2);
    Distance3 = num2cell(Distance3);
    Distance4 = num2cell(Distance4);
    Noise1 = num2cell(Noise1);
    Noise2 = num2cell(Noise2);
    Noise3 = num2cell(Noise3);
    Noise4 = num2cell(Noise4);
end

sect = struct('Sync', Sync, ...
    'Id', Id, ...
    'Checksum', Checksum, ...
    'Size', Size, ...
    'Records', Records, ...
    'Cell', Cell, ...
    'ProcMagn1', ProcMagn1, ...
    'ProcMagn2', ProcMagn2, ...
    'ProcMagn3', ProcMagn3, ...
    'ProcMagn4', ProcMagn4, ...
    'Distance1', Distance1, ...
    'Distance2', Distance2, ...
    'Distance3', Distance3, ...
    'Distance4', Distance4, ...
    'Noise1', Noise1, ...
    'Noise2', Noise2, ...
    'Noise3', Noise3, ...
    'Noise4', Noise4);

end

function sect = readAquadoppDiagnostics(data, cpuEndianness)
%READAQUADOPPDIAGNOSTICS Reads an Aquadopp diagnostics data section.
% Id=0x80, Aquadopp Diagnostics Data
% SYSTEM INTEGRATOR MANUAL (Dec 2014) pg 36
%
% same structure as velocity section
sect = readAquadoppVelocity(data, cpuEndianness);
end

function sect = readVectorVelocityHeader(data, cpuEndianness)
%READVECTORVELOCITYHEADER Reads a Vector velocity data header section.
% Id=0x12, Vector Velocity Data Header
% SYSTEM INTEGRATOR MANUAL (Dec 2014) pg 36

nRecords = size(data, 1);

Sync         = data(:, 1);
Id           = data(:, 2);
Size         = data(:, 3:4); % uint16
Time         = readClockData(data(:, 5:10));
NRecords     = data(:, 11:12); % uint16
block        = data(:, 13:20); % uint8
% bytes 21-40 are spare
Checksum     = data(:, 41:42); % uint16

% let's process uint16s in one call
blocks       = bytecast(reshape([Size NRecords Checksum]', [], 1), 'L', 'uint16', cpuEndianness);
Size         = blocks(1:3:end);
NRecords     = blocks(2:3:end);
Checksum     = blocks(3:3:end);

% let's process uint8s in one call
blocks       = bytecast(reshape(block', [], 1), 'L', 'uint8', cpuEndianness);
Noise1       = blocks(1:8:end);
Noise2       = blocks(2:8:end);
Noise3       = blocks(3:8:end);
% blocks(4:8:end) is spare
Correlation1 = blocks(5:8:end);
Correlation2 = blocks(6:8:end);
Correlation3 = blocks(7:8:end);
% blocks(8:8:end) is spare

if nRecords > 1
    Sync = num2cell(Sync);
    Id = num2cell(Id);
    Size = num2cell(Size);
    Time = num2cell(Time);
    NRecords = num2cell(NRecords);
    Checksum = num2cell(Checksum);
    Size = num2cell(Size);
    Noise1 = num2cell(Noise1);
    Noise2 = num2cell(Noise2);
    Noise3 = num2cell(Noise3);
    Correlation1 = num2cell(Correlation1);
    Correlation2 = num2cell(Correlation2);
    Correlation3 = num2cell(Correlation3);
end

sect = struct('Sync', Sync, ...
    'Id', Id, ...
    'Size', Size, ...
    'Time', Time, ...
    'NRecords', NRecords, ...
    'Checksum', Checksum, ...
    'Size', Size, ...
    'Noise1', Noise1, ...
    'Noise2', Noise2, ...
    'Noise3', Noise3, ...
    'Correlation1', Correlation1, ...
    'Correlation2', Correlation2, ...
    'Correlation3', Correlation3);

end

function sect = readVectorVelocity(data, cpuEndianness)
%READVECTORVELOCITY Reads a vector velocity data section.
% Id=0x10, Vector Velocity Data
% SYSTEM INTEGRATOR MANUAL (Dec 2014) pg 37

nRecords = size(data, 1);

Sync        = data(:, 1);
Id          = data(:, 2);
block1      = data(:, 3:6); % uint8
block2      = data(:, 7:10); % uint16
% !!! velocities can be negative
block3      = data(:, 11:16); % int16
block4      = data(:, 17:22); % uint8
Checksum    = data(:, 23:24); % uint16

block3      = bytecast(reshape(block3', [], 1), 'L', 'int16', cpuEndianness);
VelB1       = block3(1:3:end);
VelB2       = block3(2:3:end);
VelB3       = block3(3:3:end);

% let's process uint16s in one call
blocks      = bytecast(reshape([block2 Checksum]', [], 1), 'L', 'uint16', cpuEndianness);
PressureLSW = blocks(1:3:end);
Analn1      = blocks(2:3:end);
Checksum    = blocks(3:3:end);

% let's process uint8s in one call
blocks      = bytecast(reshape([block1 block4]', [], 1), 'L', 'uint8', cpuEndianness);
Analn2LSB   = blocks(1:10:end);
Count       = blocks(2:10:end);
PressureMSB = blocks(3:10:end);
Analn2MSB   = blocks(4:10:end);
AmpB1       = blocks(5:10:end);
AmpB2       = blocks(6:10:end);
AmpB3       = blocks(7:10:end);
CorrB1      = blocks(8:10:end);
CorrB2      = blocks(9:10:end);
CorrB3      = blocks(10:10:end);

if nRecords > 1
    Sync = num2cell(Sync);
    Id = num2cell(Id);
    Checksum = num2cell(Checksum);
    VelB1 = num2cell(VelB1);
    VelB2 = num2cell(VelB2);
    VelB3 = num2cell(VelB3);
    PressureLSW = num2cell(PressureLSW);
    Analn1 = num2cell(Analn1);
    Checksum = num2cell(Checksum);
    Analn2LSB = num2cell(Analn2LSB);
    Count = num2cell(Count);
    PressureMSB = num2cell(PressureMSB);
    Analn2MSB = num2cell(Analn2MSB);
    AmpB1 = num2cell(AmpB1);
    AmpB2 = num2cell(AmpB2);
    AmpB3 = num2cell(AmpB3);
    CorrB1 = num2cell(CorrB1);
    CorrB2 = num2cell(CorrB2);
    CorrB3 = num2cell(CorrB3); 
end

sect = struct('Sync', Sync, ...
    'Id', Id, ...
    'Checksum', Checksum, ...
    'VelB1', VelB1, ...
    'VelB2', VelB2, ...
    'VelB3', VelB3, ...
    'PressureLSW', PressureLSW, ...
    'Analn1', Analn1, ...
    'Checksum', Checksum, ...
    'Analn2LSB', Analn2LSB, ...
    'Count', Count, ...
    'PressureMSB', PressureMSB, ...
    'Analn2MSB', Analn2MSB, ...
    'AmpB1', AmpB1, ...
    'AmpB2', AmpB2, ...
    'AmpB3', AmpB3, ...
    'CorrB1', CorrB1, ...
    'CorrB2', CorrB2, ...
    'CorrB3', CorrB3);

end

function sect = readVectorSystem(data, cpuEndianness)
%READVECTORSYSTEM Reads a vector system data section.
% Id=0x11, Vector System Data
% SYSTEM INTEGRATOR MANUAL (Dec 2014) pg 37-38

nRecords = size(data, 1);

Sync        = data(:, 1);
Id          = data(:, 2);
Size        = data(:, 3:4); % uint16
Time        = readClockData(data(:, 5:10));
block1      = data(:, 11:14); % uint16

% !!! Heading, pitch, roll and temperature can be negative
block2      = data(:, 15:22); % int16

Error       = bytecast(data(:, 23), 'L', 'int8', cpuEndianness);
% 8 bits status code http://cs.nortek.no/scripts/customer.fcgi?_sf=0&custSessionKey=&customerLang=en&noCookies=true&action=viewKbEntry&id=7
Status      = uint8(data(:, 24));
Analn       = data(:, 25:26); % uint16

Checksum    = data(:, 27:28); % uint16

% let's process uint16s in one call
blocks      = bytecast(reshape([Size block1 Analn Checksum]', [], 1), 'L', 'uint16', cpuEndianness);
Size        = blocks(1:5:end);
Battery     = blocks(2:5:end);
SoundSpeed  = blocks(3:5:end);
Analn       = blocks(4:5:end);
Checksum    = blocks(5:5:end);

blocks      = bytecast(reshape(block2', [], 1), 'L', 'int16', cpuEndianness);
Heading     = blocks(1:4:end);
Pitch       = blocks(2:4:end);
Roll        = blocks(3:4:end);
Temperature = blocks(4:4:end);

if nRecords > 1
    Sync = num2cell(Sync);
    Id = num2cell(Id);
    Size = num2cell(Size);
    Time = num2cell(Time);
    Error = num2cell(Error);
    Status = num2cell(Status);
    Analn = num2cell(Analn);
    Checksum = num2cell(Checksum);
    Size = num2cell(Size);
    Battery = num2cell(Battery);
    SoundSpeed = num2cell(SoundSpeed);
    Heading = num2cell(Heading);
    Pitch = num2cell(Pitch);
    Roll = num2cell(Roll);
    Temperature = num2cell(Temperature);
end

sect = struct('Sync', Sync, ...
    'Id', Id, ...
    'Size', Size, ...
    'Time', Time, ...
    'Error', Error, ...
    'Status', Status, ...
    'Analn', Analn, ...
    'Checksum', Checksum, ...
    'Size', Size, ...
    'Battery', Battery, ...
    'SoundSpeed', SoundSpeed, ...
    'Heading', Heading, ...
    'Pitch', Pitch, ...
    'Roll', Roll, ...
    'Temperature', Temperature);

end

function sect = readAquadoppProfilerVelocity(data, cpuEndianness)
%READAQUADOPPPROFILERVELOCITY Reads an Aquadopp Profiler velocity data
% section.
% Id=0x21, Aquadopp Profiler Velocity Data
% SYSTEM INTEGRATOR MANUAL (Dec 2014) pg 42-43

nRecords = size(data, 1);

Sync        = data(:, 1);
Id          = data(:, 2);
Size        = bytecast(reshape(data(:, 3:4)', [], 1), 'L', 'uint16', cpuEndianness); % uint16

Time        = readClockData(data(:, 5:10));
Error       = data(:, 11:12); % int16
block1      = data(:, 13:18); % uint16
% !!! Heading, pitch and roll can be negative
block2      = data(:, 19:24); % int16

PressureMSB = bytecast(data(:, 25), 'L', 'uint8', cpuEndianness); % uint8
% 8 bits status code http://cs.nortek.no/scripts/customer.fcgi?_sf=0&custSessionKey=&customerLang=en&noCookies=true&action=viewKbEntry&id=7
Status      = uint8(data(:, 26));
PressureLSW = data(:, 27:28); % uint16
Temperature = data(:, 29:30); % int16

% calculate number of cells from structure size
% (* 2 because size is specified in 16 bit words)
nCells = floor(((Size(1)) * 2 - (30+2)) / (3*2 + 3)); % we assume the first value of size is correct and doesn't change!

% offsets for each velocity/amplitude section
vel1Off = 31;
vel2Off = vel1Off + nCells*2;
vel3Off = vel2Off + nCells*2;
amp1Off = vel3Off + nCells*2;
amp2Off = amp1Off + nCells;
amp3Off = amp2Off + nCells;
csOff   = amp3Off + nCells;

% a fill byte is present if the number of cells is odd
if mod(nCells, 2), csOff = csOff + 1; end

Checksum = data(:, csOff:csOff+1); % uint16

% let's process uint16s in one call
blocks = bytecast(reshape([block1 PressureLSW Checksum]', [], 1), 'L', 'uint16', cpuEndianness);
Analn1      = blocks(1:5:end);
Battery     = blocks(2:5:end);
Analn2      = blocks(3:5:end);
PressureLSW = blocks(4:5:end);
Checksum    = blocks(5:5:end);

% !!! velocity can be negative
block4 = data(:, vel1Off:vel3Off+nCells*2-1); % int16
block5 = data(:, amp1Off:amp3Off+nCells-1); % uint8

% let's process uint8s in one call
blocks = bytecast(reshape(block5', [], 1), 'L', 'uint8', cpuEndianness);
blocks = reshape(blocks, nCells, 3, nRecords);
Amp1        = squeeze(blocks(:, 1, :));
Amp2        = squeeze(blocks(:, 2, :));
Amp3        = squeeze(blocks(:, 3, :));

% let's process int16s in one call
blocks = bytecast(reshape([Error block2 Temperature]', [], 1), 'L', 'int16', cpuEndianness);
Error       = blocks(1:5:end);
Heading     = blocks(2:5:end);
Pitch       = blocks(3:5:end);
Roll        = blocks(4:5:end);
Temperature = blocks(5:5:end);

blocks = bytecast(reshape(block4', [], 1), 'L', 'int16', cpuEndianness);
blocks = reshape(blocks, nCells, 3, nRecords);
Vel1        = squeeze(blocks(:, 1, :));
Vel2        = squeeze(blocks(:, 2, :));
Vel3        = squeeze(blocks(:, 3, :));

if nRecords > 1
    Sync        = num2cell(Sync);
    Id          = num2cell(Id);
    Size        = num2cell(Size);
    Time        = num2cell(Time);
    Error       = num2cell(Error);
    PressureMSB = num2cell(PressureMSB);
    Status      = num2cell(Status);
    PressureLSW = num2cell(PressureLSW);
    Temperature = num2cell(Temperature);
    Checksum    = num2cell(Checksum);
    Analn1      = num2cell(Analn1);
    Battery     = num2cell(Battery);
    Analn2      = num2cell(Analn2);
    Amp1        = mat2cell(Amp1, nCells, ones(1, nRecords))';
    Amp2        = mat2cell(Amp2, nCells, ones(1, nRecords))';
    Amp3        = mat2cell(Amp3, nCells, ones(1, nRecords))';
    Heading     = num2cell(Heading);
    Pitch       = num2cell(Pitch);
    Roll        = num2cell(Roll);
    Vel1        = mat2cell(Vel1, nCells, ones(1, nRecords))';
    Vel2        = mat2cell(Vel2, nCells, ones(1, nRecords))';
    Vel3        = mat2cell(Vel3, nCells, ones(1, nRecords))';
end

sect = struct('Sync', Sync, ...
    'Id', Id, ...
    'Size', Size, ...
    'Time', Time, ...
    'Error', Error, ...
    'PressureMSB', PressureMSB, ...
    'Status', Status, ...
    'PressureLSW', PressureLSW, ...
    'Temperature', Temperature, ...
    'Checksum', Checksum, ...
    'Analn1', Analn1, ...
    'Battery', Battery, ...
    'Analn2', Analn2, ...
    'Amp1', Amp1, ...
    'Amp2', Amp2, ...
    'Amp3', Amp3, ...
    'Heading', Heading, ...
    'Pitch', Pitch, ...
    'Roll', Roll, ...
    'Vel1', Vel1, ...
    'Vel2', Vel2, ...
    'Vel3', Vel3);

end

function sect = readHRAquadoppProfile(data, cpuEndianness)
%READHRAQUADOPPPROFILERVELOCITY Reads a HR Aquadopp Profile data section
% (pg 38 of system integrator manual).
% Id=0x2A, High Resolution Aquadopp Profiler Data
% SYSTEM INTEGRATOR MANUAL (Dec 2014) pg 43-45

nRecords = size(data, 1);

Sync         = data(:, 1);
Id           = data(:, 2);
Size         = bytecast(reshape(data(:, 3:4)', [], 1), 'L', 'uint16', cpuEndianness); % uint16
Time         = readClockData(data(:, 5:10));
block1       = data(:, 11:14); % int16
block2       = data(:, 15:18); % uint16
% !!! Heading, pitch and roll can be negative
block3       = data(:, 19:24); % int16
PressureMSB  = data(:, 25); % uint8
Status       = uint8(data(:, 26));
PressureLSW  = data(:, 27:28); % uint16
Temperature  = data(:, 29:30); % int16
block4       = data(:, 31:34); % uint16

Beams        = data(:, 35); % uint8
Cells        = data(:, 36); % uint8
VelLag2      = data(:, 37:42); % uint16
block5       = data(:, 43:48); % uint8

% let's process uint16s in one call
blocks = bytecast(reshape([block2 PressureLSW block4]', [], 1), 'L', 'uint16', cpuEndianness);
clear block2 block4;
Battery      = blocks(1:5:end);
SpeedOfSound = blocks(2:5:end);
PressureLSW  = blocks(3:5:end);
Analn1       = blocks(4:5:end);
Analn2       = blocks(5:5:end);
clear blocks;
blocks = bytecast(reshape(VelLag2', [], 1), 'L', 'uint16', cpuEndianness);
VelLag2      = reshape(blocks, [], nRecords);
clear blocks;

% let's process int16s in one call
blocks = bytecast(reshape([block1 block3 Temperature]', [], 1), 'L', 'int16', cpuEndianness);
clear block1 block3;
Milliseconds = blocks(1:6:end);
Error        = blocks(2:6:end);
Heading      = blocks(3:6:end);
Pitch        = blocks(4:6:end);
Roll         = blocks(5:6:end);
Temperature  = blocks(6:6:end);
clear blocks;

% let's process uint8s in one call
blocks = bytecast(reshape([PressureMSB Beams Cells]', [], 1), 'L', 'uint8', cpuEndianness);
PressureMSB  = blocks(1:3:end);
Beams        = blocks(2:3:end);
Cells        = blocks(3:3:end);
clear blocks;
blocks = bytecast(reshape(block5', [], 1), 'L', 'uint8', cpuEndianness);
clear block5;
blocks = reshape(blocks, [], nRecords);
AmpLag2      = blocks(1:3, :);
CorrLag2     = blocks(4:6, :);
clear blocks;

nBeams = Beams(1); % we assume the first value is correct and doesn't change!
nCells = Cells(1);

% bytes 48-53 are spare
velOff  = 55;
ampOff  = velOff  + nBeams*nCells*2;
corrOff = ampOff  + nBeams*nCells;
csOff   = corrOff + nBeams*nCells;

Checksum = bytecast(reshape(data(:, csOff:csOff+1)', [], 1), 'L', 'uint16', cpuEndianness); % uint16

vel = NaN(3, nCells*nRecords);
amp = NaN(3, nCells*nRecords);
cor = NaN(3, nCells*nRecords);
for k = 1:nBeams
    % velocity data, velocity can be negative, int16
    sVelOff = velOff + (k-1) * (nCells * 2);
    eVelOff = sVelOff + (nCells * 2)-1;
    vel(k, :) = bytecast(reshape(data(:, sVelOff:eVelOff)', [], 1), 'L', 'int16', cpuEndianness); % int16
    
    % amplitude data, uint8
    sAmpOff = ampOff + (k-1) * (nCells);
    eAmpOff = sAmpOff + nCells - 1;
    amp(k, :) = bytecast(reshape(data(:, sAmpOff:eAmpOff)', [], 1), 'L', 'uint8', cpuEndianness); % uint8
    
    % correlation data, uint8
    sCorOff = corrOff + (k-1) * (nCells);
    eCorOff = sCorOff + nCells - 1;
    cor(k, :) = bytecast(reshape(data(:, sCorOff:eCorOff)', [], 1), 'L', 'uint8', cpuEndianness); % uint8
end
clear data;

Vel1 = reshape(vel(1, :), nCells, nRecords);
Vel2 = reshape(vel(2, :), nCells, nRecords);
Vel3 = reshape(vel(3, :), nCells, nRecords);
clear vel;

Amp1 = reshape(amp(1, :), nCells, nRecords);
Amp2 = reshape(amp(2, :), nCells, nRecords);
Amp3 = reshape(amp(3, :), nCells, nRecords);
clear amp;

Corr1 = reshape(cor(1, :), nCells, nRecords);
Corr2 = reshape(cor(2, :), nCells, nRecords);
Corr3 = reshape(cor(3, :), nCells, nRecords);
clear cor;

if nRecords > 1
    Sync = num2cell(Sync);
    Id = num2cell(Id);
    Size = num2cell(Size);
    Time = num2cell(Time);
    PressureMSB = num2cell(PressureMSB);
    Status = num2cell(Status);
    PressureLSW = num2cell(PressureLSW);
    Temperature = num2cell(Temperature);
    Beams = num2cell(Beams);
    Cells = num2cell(Cells);
    VelLag2 = mat2cell(VelLag2, 3, ones(1, nRecords))';
    Battery = num2cell(Battery);
    SpeedOfSound = num2cell(SpeedOfSound);
    Analn1 = num2cell(Analn1);
    Analn2 = num2cell(Analn2);
    Milliseconds = num2cell(Milliseconds);
    Error = num2cell(Error);
    Heading = num2cell(Heading);
    Pitch = num2cell(Pitch);
    Roll = num2cell(Roll);
    AmpLag2 = mat2cell(AmpLag2, 3, ones(1, nRecords))';
    CorrLag2 = mat2cell(CorrLag2, 3, ones(1, nRecords))';
    Checksum = num2cell(Checksum);
    Vel1 = mat2cell(Vel1, nCells, ones(1, nRecords))';
    Vel2 = mat2cell(Vel2, nCells, ones(1, nRecords))';
    Vel3 = mat2cell(Vel3, nCells, ones(1, nRecords))';
    Amp1 = mat2cell(Amp1, nCells, ones(1, nRecords))';
    Amp2 = mat2cell(Amp2, nCells, ones(1, nRecords))';
    Amp3 = mat2cell(Amp3, nCells, ones(1, nRecords))';
    Corr1 = mat2cell(Corr1, nCells, ones(1, nRecords))';
    Corr2 = mat2cell(Corr2, nCells, ones(1, nRecords))';
    Corr3 = mat2cell(Corr3, nCells, ones(1, nRecords))';
end

sect = struct('Sync', Sync, ...
    'Id', Id, ...
    'Size', Size, ...
    'Time', Time, ...
    'PressureMSB', PressureMSB, ...
    'Status', Status, ...
    'PressureLSW', PressureLSW, ...
    'Temperature', Temperature, ...
    'Beams', Beams, ...
    'Cells', Cells, ...
    'VelLag2', VelLag2, ...
    'Battery', Battery, ...
    'SpeedOfSound', SpeedOfSound, ...
    'Analn1', Analn1, ...
    'Analn2', Analn2, ...
    'Milliseconds', Milliseconds, ...
    'Error', Error, ...
    'Heading', Heading, ...
    'Pitch', Pitch, ...
    'Roll', Roll, ...
    'AmpLag2', AmpLag2, ...
    'CorrLag2', CorrLag2, ...
    'Checksum', Checksum, ...
    'Vel1', Vel1, ...
    'Amp1', Amp1, ...
    'Corr1', Corr1, ...
    'Vel2', Vel2, ...
    'Amp2', Amp2, ...
    'Corr2', Corr2, ...
    'Vel3', Vel3, ...
    'Amp3', Amp3, ...
    'Corr3', Corr3);
clear Sync Id Size Time PressureMSB  PressureLSW Temperature Beams Cells;
clear VelLag2 Battery SpeedOfSound Analn1 Analn2 Milliseconds Error;
clear Heading Pitch Roll AmpLag2 CorrLag2 Checksum Vel1 Vel2 Vel3;
clear Amp1 Amp2 Amp3 Corr1 Corr2 Corr3;

end

function sect = readAwacVelocityProfile(data, cpuEndianness)
%READAWACVELOCITYPROFILE Reads an AWAC Velocity Profile data section (pg 39
% of the system integrator manual).
% Id=0x20, AWAC Velocity Profile Data
% SYSTEM INTEGRATOR MANUAL (Dec 2014) pg 46-47

nRecords = size(data, 1);

Sync        = data(:, 1);
Id          = data(:, 2);
Size        = bytecast(reshape(data(:, 3:4)', [], 1), 'L', 'uint16', cpuEndianness); % uint16
Time        = readClockData(data(:, 5:10));
Error       = bytecast(reshape(data(:, 11:12)', [], 1), 'L', 'int16', cpuEndianness); % int16
block       = bytecast(reshape(data(:, 13:18)', [], 1), 'L', 'uint16', cpuEndianness); % uint16
block       = reshape(block, [], nRecords)';
Analn1      = block(:, 1);
Battery     = block(:, 2);
Analn2      = block(:, 3);
% !!! Heading, pitch and roll can be negative
block       = bytecast(reshape(data(:, 19:24)', [], 1), 'L', 'int16', cpuEndianness); % int16
block       = reshape(block, [], nRecords)';
Heading     = block(:, 1);
Pitch       = block(:, 2);
Roll        = block(:, 3);
PressureMSB = bytecast(data(:, 25), 'L', 'uint8', cpuEndianness); % uint8
% 8 bits status code http://cs.nortek.no/scripts/customer.fcgi?_sf=0&custSessionKey=&customerLang=en&noCookies=true&action=viewKbEntry&id=7
Status      = uint8(data(:, 26));
PressureLSW = bytecast(reshape(data(:, 27:28)', [], 1), 'L', 'uint16', cpuEndianness); % uint16
Temperature = bytecast(reshape(data(:, 29:30)', [], 1), 'L', 'int16', cpuEndianness); % int16
% bytes 30-117 are spare

% calculate number of cells from structure size
% (size is in 16 bit words)
nCells = floor(((Size) * 2 - (118 + 2)) / (3*2 + 3));
nCells = nCells(1); % we assume this doesn't change and the first one is correct!

vel1Off = 119;
vel2Off = vel1Off + nCells*2;
vel3Off = vel2Off + nCells*2;
amp1Off = vel3Off + nCells*2;
amp2Off = amp1Off + nCells;
amp3Off = amp2Off + nCells;
csOff   = amp3Off + nCells;

% fill value is included if number of cells is odd
if mod(nCells, 2), csOff = csOff + 1; end

% !!! Velocity can be negative
Vel1 = bytecast(reshape(data(:, vel1Off:vel1Off+nCells*2-1)', [], 1), 'L', 'int16', cpuEndianness); % U comp (East)  % int16
Vel2 = bytecast(reshape(data(:, vel2Off:vel2Off+nCells*2-1)', [], 1), 'L', 'int16', cpuEndianness); % V comp (North) % int16
Vel3 = bytecast(reshape(data(:, vel3Off:vel3Off+nCells*2-1)', [], 1), 'L', 'int16', cpuEndianness); % W comp (up)    % int16
Amp1 = bytecast(reshape(data(:, amp1Off:amp1Off+nCells-1)', [], 1), 'L', 'uint8', cpuEndianness);
Amp2 = bytecast(reshape(data(:, amp2Off:amp2Off+nCells-1)', [], 1), 'L', 'uint8', cpuEndianness);
Amp3 = bytecast(reshape(data(:, amp3Off:amp3Off+nCells-1)', [], 1), 'L', 'uint8', cpuEndianness);

Vel1 = reshape(Vel1, [], nRecords);
Vel2 = reshape(Vel2, [], nRecords);
Vel3 = reshape(Vel3, [], nRecords);
Amp1 = reshape(Amp1, [], nRecords);
Amp2 = reshape(Amp2, [], nRecords);
Amp3 = reshape(Amp3, [], nRecords);

Checksum = bytecast(reshape(data(:, csOff:csOff+1)', [], 1), 'L', 'uint16', cpuEndianness); % uint16

if nRecords > 1
    Sync        = num2cell(Sync);
    Id          = num2cell(Id);
    Size        = num2cell(Size);
    Time        = num2cell(Time);
    Error       = num2cell(Error);
    Analn1      = num2cell(Analn1);
    Battery     = num2cell(Battery);
    Analn2      = num2cell(Analn2);
    Heading     = num2cell(Heading);
    Pitch       = num2cell(Pitch);
    Roll        = num2cell(Roll);
    PressureMSB = num2cell(PressureMSB);
    Status      = num2cell(Status);
    PressureLSW = num2cell(PressureLSW);
    Temperature = num2cell(Temperature);
    Vel1        = mat2cell(Vel1, nCells, ones(1, nRecords))';
    Vel2        = mat2cell(Vel2, nCells, ones(1, nRecords))';
    Vel3        = mat2cell(Vel3, nCells, ones(1, nRecords))';
    Amp1        = mat2cell(Amp1, nCells, ones(1, nRecords))';
    Amp2        = mat2cell(Amp2, nCells, ones(1, nRecords))';
    Amp3        = mat2cell(Amp3, nCells, ones(1, nRecords))';
    Checksum    = num2cell(Checksum);
end

sect = struct('Sync', Sync, ...
    'Id', Id, ...
    'Size', Size, ...
    'Time', Time, ...
    'Error', Error, ...
    'Analn1', Analn1, ...
    'Battery', Battery, ...
    'Analn2', Analn2, ...
    'Heading', Heading, ...
    'Pitch', Pitch, ...
    'Roll', Roll, ...
    'PressureMSB', PressureMSB, ...
    'Status', Status, ...
    'PressureLSW', PressureLSW, ...
    'Temperature', Temperature, ...
    'Vel1', Vel1, ...
    'Vel2', Vel2, ...
    'Vel3', Vel3, ...
    'Amp1', Amp1, ...
    'Amp2', Amp2, ...
    'Amp3', Amp3, ...
    'Checksum', Checksum);

end

function sect = readAwacWaveHeader(data, cpuEndianness)
%READAWACWAVEHEADER Reads an AWAC wave header section.
% Id=0x31, Awac Wave Data Header
% SYSTEM INTEGRATOR MANUAL (Dec 2014) pg 49

nRecords = size(data, 1);

Sync         = data(:, 1);
Id           = data(:, 2);
Size         = bytecast(reshape(data(:, 3:4)', [], 1), 'L', 'uint16', cpuEndianness);
Time         = readClockData(data(:, 5:10));
block        = bytecast(reshape(data(:, 11:18)', [], 1), 'L', 'uint16', cpuEndianness);
NRecords     = block(1:4:end); % number of wave data records to follow
Blanking     = block(2:4:end); % T2 used for wave data measurements (counts)
Battery      = block(3:4:end); % battery voltage (0.1 V)
SoundSpeed   = block(4:4:end); % speed of sound (0.1 m/s)
block        = bytecast(reshape(data(:, 19:24)', [], 1), 'L', 'int16', cpuEndianness);
Heading      = block(1:3:end); % compass heading (0.1 deg)
Pitch        = block(2:3:end); % compass pitch (0.1 deg)
Roll         = block(3:3:end); % compass roll (0.1 deg)
block        = bytecast(reshape(data(:, 25:28)', [], 1), 'L', 'uint16', cpuEndianness);
MinPress     = block(1:2:end); % minimum pressure value of previous profile (dbar)
HMaxPress    = block(2:2:end); % maximum pressure value of previous profile (dbar)
Temperature  = bytecast(reshape(data(:, 29:30)', [], 1), 'L', 'int16', cpuEndianness); % temperature (0.01 deg C)
CellSize     = bytecast(reshape(data(:, 31:32)', [], 1), 'L', 'uint16', cpuEndianness); % cell size in counts of T3
% noise amplitude (counts)
block        = bytecast(reshape(data(:, 33:36)', [], 1), 'L', 'uint8', cpuEndianness);
Noise1       = block(1:4:end);
Noise2       = block(2:4:end);
Noise3       = block(3:4:end);
Noise4       = block(4:4:end);
% processing magnitude
block        = bytecast(reshape(data(:, 37:44)', [], 1), 'L', 'uint16', cpuEndianness);
ProcMagn1    = block(1:4:end);
ProcMagn2    = block(2:4:end);
ProcMagn3    = block(3:4:end);
ProcMagn4    = block(4:4:end);
% C structure now has
% unsigned short hWindRed; // number of samples of AST window past boundary
% unsigned short hASTWindow; // AST window size (# samples)
% short Spare[5]; // spare values
% short hChecksum; // checksum

% bytes 44-57 are spare
Checksum     = bytecast(reshape(data(:, 59:60)', [], 1), 'L', 'uint16', cpuEndianness);

if nRecords > 1
    Sync = num2cell(Sync);
    Id = num2cell(Id);
    Size = num2cell(Size);
    Time = num2cell(Time);
    NRecords = num2cell(NRecords);
    Blanking = num2cell(Blanking);
    Battery = num2cell(Battery);
    SoundSpeed = num2cell(SoundSpeed);
    Heading = num2cell(Heading);
    Pitch = num2cell(Pitch);
    Roll = num2cell(Roll);
    MinPress = num2cell(MinPress);
    HMaxPress = num2cell(HMaxPress);
    Temperature = num2cell(Temperature);
    CellSize = num2cell(CellSize);
    Noise1 = num2cell(Noise1);
    Noise2 = num2cell(Noise2);
    Noise3 = num2cell(Noise3);
    Noise4 = num2cell(Noise4);
    ProcMagn1 = num2cell(ProcMagn1);
    ProcMagn2 = num2cell(ProcMagn2);
    ProcMagn3 = num2cell(ProcMagn3);
    ProcMagn4 = num2cell(ProcMagn4);
    Checksum = num2cell(Checksum);
end

sect = struct('Sync', Sync, ...
    'Id', Id, ...
    'Size', Size, ...
    'Time', Time, ...
    'NRecords', NRecords, ...
    'Blanking', Blanking, ...
    'Battery', Battery, ...
    'SoundSpeed', SoundSpeed, ...
    'Heading', Heading, ...
    'Pitch', Pitch, ...
    'Roll', Roll, ...
    'MinPress', MinPress, ...
    'HMaxPress', HMaxPress, ...
    'Temperature', Temperature, ...
    'CellSize', CellSize, ...
    'Noise1', Noise1, ...
    'Noise2', Noise2, ...
    'Noise3', Noise3, ...
    'Noise4', Noise4, ...
    'ProcMagn1', ProcMagn1, ...
    'ProcMagn2', ProcMagn2, ...
    'ProcMagn3', ProcMagn3, ...
    'ProcMagn4', ProcMagn4, ...
    'Checksum', Checksum);

end

function sect = readAwacWaveData(data, cpuEndianness)
%READAWACWAVEDATA Reads an AWAC Wave data section.
% Id=0x30, Awac Wave Data
% SYSTEM INTEGRATOR MANUAL (Dec 2014) pg 49

nRecords = size(data, 1);

Sync        = data(:, 1);
Id          = data(:, 2);
Size        = bytecast(reshape(data(:, 3:4)', [], 1), 'L', 'uint16', cpuEndianness);
block       = bytecast(reshape(data(:, 5:10)', [], 1), 'L', 'uint16', cpuEndianness);
Pressure    = block(1:3:end); % pressure (0.001 dbar)
Distance    = block(2:3:end); % distance 1 to surface vertical beam (mm)
Analn       = block(3:3:end); % analog input
% !!! velocity can be negative
block       = bytecast(reshape(data(:, 11:18)', [], 1), 'L', 'int16', cpuEndianness);
Vel1        = block(1:4:end); % velocity beam 1 (mm/s) (East for SUV)
Vel2        = block(2:4:end); % velocity beam 2 (mm/s) (North for SUV)
Vel3        = block(3:4:end); % velocity beam 3 (mm/s) (Up for SUV)
Vel4        = block(4:4:end); % distance 2 to surface vertical beam (mm). For non-AST velocity beam 4 (mm/s)
block       = bytecast(reshape(data(:, 19:22)', [], 1), 'L', 'uint8', cpuEndianness);
Amp1        = block(1:4:end); % amplitude beam 1 (mm/s)
Amp2        = block(2:4:end); % amplitude beam 2 (mm/s)
Amp3        = block(3:4:end); % amplitude beam 3 (mm/s)
Amp4ASTQual = block(4:4:end); % AST quality Counts). For non-AST amplitude beam 4 (mm/s)
Checksum    = bytecast(reshape(data(:, 23:24)', [], 1), 'L', 'uint16', cpuEndianness);

if nRecords > 1
    Sync = num2cell(Sync);
    Id = num2cell(Id);
    Size = num2cell(Size);
    Pressure = num2cell(Pressure);
    Distance = num2cell(Distance);
    Analn = num2cell(Analn);
    Vel1 = num2cell(Vel1);
    Vel2 = num2cell(Vel2);
    Vel3 = num2cell(Vel3);
    Vel4 = num2cell(Vel4);
    Amp1 = num2cell(Amp1);
    Amp2 = num2cell(Amp2);
    Amp3 = num2cell(Amp3);
    Amp4ASTQual = num2cell(Amp4ASTQual);
    Checksum = num2cell(Checksum);
end

sect = struct('Sync', Sync, ...
    'Id', Id, ...
    'Size', Size, ...
    'Pressure', Pressure, ...
    'Distance', Distance, ...
    'Analn', Analn, ...
    'Vel1', Vel1, ...
    'Vel2', Vel2, ...
    'Vel3', Vel3, ...
    'Vel4', Vel4, ...
    'Amp1', Amp1, ...
    'Amp2', Amp2, ...
    'Amp3', Amp3, ...
    'Amp4ASTQual', Amp4ASTQual, ...
    'Checksum', Checksum);

end

function sect = readAwacWaveDataSUV(data, cpuEndianness)
%READAWACWAVEDATASUV Reads an AWAC Wave data SUV section.
% Id=0x36, Awac Wave Data for SUV
% SYSTEM INTEGRATOR MANUAL (Dec 2014) pg 49-50

nRecords = size(data, 1);

Sync        = data(:, 1);
Id          = data(:, 2);
block       = bytecast(reshape(data(:, 3:8)', [], 1), 'L', 'uint16', cpuEndianness);
Heading     = block(1:3:end); % heading (0.1deg)
Pressure    = block(2:3:end); % pressure (0.001 dbar)
Distance    = block(3:3:end); % distance 1 to surface vertical beam (mm)
Pitch       = data(:, 9); % pitch (0.1 or 0.2 deg) (+/- 12.7 deg)
Roll        = data(:, 10); % roll (0.1 or 0.2 deg) (+/- 12.7 deg)
% !!! velocity can be negative
block       = bytecast(reshape(data(:, 11:18)', [], 1), 'L', 'int16', cpuEndianness);
Vel1        = block(1:4:end); % velocity beam 1 (mm/s) (East for SUV)
Vel2        = block(2:4:end); % velocity beam 2 (mm/s) (North for SUV)
Vel3        = block(3:4:end); % velocity beam 3 (mm/s) (Up for SUV)
Vel4Distance2 = block(4:4:end); % distance 2 to surface vertical beam (mm). For non-AST velocity beam 4 (mm/s)
block       = bytecast(reshape(data(:, 19:22)', [], 1), 'L', 'uint8', cpuEndianness);
Amp1        = block(1:4:end); % amplitude beam 1 (mm/s)
Amp2        = block(2:4:end); % amplitude beam 2 (mm/s)
Amp3        = block(3:4:end); % amplitude beam 3 (mm/s)
Amp4ASTQual = block(4:4:end); % AST quality Counts. For non-AST amplitude beam 4 (mm/s)
Checksum    = bytecast(reshape(data(:, 23:24)', [], 1), 'L', 'uint16', cpuEndianness);

if nRecords > 1
    Sync = num2cell(Sync);
    Id = num2cell(Id);
    Heading = num2cell(Heading);
    Pressure = num2cell(Pressure);
    Distance = num2cell(Distance);
    Pitch = num2cell(Pitch);
    Roll = num2cell(Roll);
    Vel1 = num2cell(Vel1);
    Vel2 = num2cell(Vel2);
    Vel3 = num2cell(Vel3);
    Vel4Distance2 = num2cell(Vel4Distance2);
    Amp1 = num2cell(Amp1);
    Amp2 = num2cell(Amp2);
    Amp3 = num2cell(Amp3);
    Amp4ASTQual = num2cell(Amp4ASTQual);
    Checksum = num2cell(Checksum);
end

sect = struct('Sync', Sync, ...
    'Id', Id, ...
    'Heading', Heading, ...
    'Pressure', Pressure, ...
    'Distance', Distance, ...
    'Pitch', Pitch, ...
    'Roll', Roll, ...
    'Vel1', Vel1, ...
    'Vel2', Vel2, ...
    'Vel3', Vel3, ...
    'Vel4Distance2', Vel4Distance2, ...
    'Amp1', Amp1, ...
    'Amp2', Amp2, ...
    'Amp3', Amp3, ...
    'Amp4ASTQual', Amp4ASTQual, ...
    'Checksum', Checksum);

end

function sect = readAwacStageData(data, cpuEndianness)
%READAWACSTAGEDATA Reads an AWAC Stage data section.
% Id=0x42, Awac Stage Data
% SYSTEM INTEGRATOR MANUAL (Dec 2014) pg 48

% Note comment in http://www.nortek-as.com/en/knowledge-center/forum/system-integration-and-telemetry/739675601
% "As you've seen the system integrator manual is describing the latest 
% firmware available. The format is the same, but all the fields wasn't 
% populated from the beginning of the product life. I am sorry that when 
% the different fields were populated isn't available.
% The stage data is truly variable in size. The AST window size will vary 
% depending of the seastate captured in previous current measurements. The 
% chosen AST window is then cut into a number of fixed size cells."

nRecords = size(data, 1);

Sync = data(:, 1);
Id   = data(:, 2);
Size = bytecast(reshape(data(:, 3:4)', [], 1), 'L', 'uint16', cpuEndianness);
% 5 uint16 spare (AST distance1 duplicate)

block = bytecast(reshape(data(:, 7:9)', [], 1), 'L', 'uint8', cpuEndianness);
Amp1  = block(1:3:end); % amplitude beam 1 (counts)
Amp2  = block(2:3:end); % amplitude beam 2 (counts)
Amp3  = block(3:3:end); % amplitude beam 3 (counts)
% 10 uint8 spare (AST quality duplicate)

block      = bytecast(reshape(data(:, 11:20)', [], 1), 'L', 'uint16', cpuEndianness);
Pressure   = block(1:5:end); % pressure (0.001 dbar)
AST1       = block(2:5:end); % AST distance 1 (mm)
ASTquality = block(3:5:end); % AST quality (counts)
SoundSpeed = block(4:5:end); % Speed of sound (0.1 m/s)
AST2       = block(5:5:end); % AST distance 2 (mm)
% 21:22 spare

block = bytecast(reshape(data(:, 23:28)', [], 1), 'L', 'int16', cpuEndianness);
Vel1  = block(1:3:end); % velocity beam 1 (mm/s) (East for SUV)
Vel2  = block(2:3:end); % velocity beam 2 (mm/s) (North for SUV)
Vel3  = block(3:3:end); % velocity beam 3 (mm/s) (Up for SUV)
% 29:30 spare (AST distance2 duplicate)
% 31:32 spare

% calculate number of cells from structure size (size is in 16 bit words)
nCells = floor(((Size(1)) * 2 - (32 + 2))); % hopefully Size doesn't change!
ampOff = 33;
csOff  = ampOff + nCells;
% fill value is included if number of cells is odd
if mod(nCells, 2), csOff = csOff + 1; end
Amp      = bytecast(reshape(data(:, ampOff:ampOff+nCells-1)', [], 1),   'L', 'uint8', cpuEndianness);
Amp      = reshape(Amp, [], nRecords);

Checksum = bytecast(reshape(data(:, csOff:csOff+1)', [], 1), 'L', 'uint16', cpuEndianness);

if nRecords > 1
    Sync = num2cell(Sync);
    Id = num2cell(Id);
    Size = num2cell(Size);
    Amp1 = num2cell(Amp1);
    Amp2 = num2cell(Amp2);
    Amp3 = num2cell(Amp3);
    Pressure = num2cell(Pressure);
    AST1 = num2cell(AST1);
    ASTquality = num2cell(ASTquality);
    SoundSpeed = num2cell(SoundSpeed);
    AST2 = num2cell(AST2);
    Vel1 = num2cell(Vel1);
    Vel2 = num2cell(Vel2);
    Vel3 = num2cell(Vel3);
    Amp = mat2cell(Amp, nCells, ones(1, nRecords))';
    Checksum = num2cell(Checksum);
end

sect = struct('Sync', Sync, ...
    'Id', Id, ...
    'Size', Size, ...
    'Amp1', Amp1, ...
    'Amp2', Amp2, ...
    'Amp3', Amp3, ...
    'Pressure', Pressure, ...
    'AST1', AST1, ...
    'ASTquality', ASTquality, ...
    'SoundSpeed', SoundSpeed, ...
    'AST2', AST2, ...
    'Vel1', Vel1, ...
    'Vel2', Vel2, ...
    'Vel3', Vel3, ...
    'Amp', Amp, ...
    'Checksum', Checksum);

end

function sect = readContinental(data, cpuEndianness)
%READCONTINENTAL Reads a Continental Data section.
% Id=0x24, Continental Data
% SYSTEM INTEGRATOR MANUAL (Dec 2014) pg 50
% structure is same as awac velocity profile data
sect = readAwacVelocityProfile(data, cpuEndianness);
end


function sect = readVectrinoVelocityHeader(data, cpuEndianness)
%READVECTRINOVELOCITYHEADER Reads a Vectrino velocity data header section
% (pg 42 of system integrator manual).
% Id=0x50, Vectrino velocity data header
% SYSTEM INTEGRATOR MANUAL (Dec 2014) pg 57-58

nRecords = size(data, 1);

Sync         = data(:, 1);
Id           = data(:, 2);

block1       = data(:, 3:12); % uint16
block2       = data(:, 13:20); % uint8

Temperature  = bytecast(reshape(data(:, 21:22)', [], 1), 'L', 'int16', cpuEndianness);
SoundSpeed   = data(:, 23:24); % uint16

block3       = data(:, 25:40); % uint8

Checksum     = data(:, 41:42); % uint16

block        = bytecast(reshape([block1 SoundSpeed Checksum]', [], 1), 'L', 'uint16', cpuEndianness);
Size         = block(1:7:end);
Distance     = block(2:7:end);
DistQuality  = block(3:7:end);
Lag1         = block(4:7:end);
Lag2         = block(5:7:end);
SoundSpeed   = block(6:7:end);
Checksum     = block(7:7:end);

block        = bytecast(reshape([block2 block3]', [], 1), 'L', 'uint8', cpuEndianness);
Noise1       = block(1:24:end);
Noise2       = block(2:24:end);
Noise3       = block(3:24:end);
Noise4       = block(4:24:end);
Correlation1 = block(5:24:end);
Correlation2 = block(6:24:end);
Correlation3 = block(7:24:end);
Correlation4 = block(8:24:end);
AmpZ01       = block(9:24:end);
AmpZ02       = block(10:24:end);
AmpZ03       = block(11:24:end);
AmpZ04       = block(12:24:end);
AmpX11       = block(13:24:end);
AmpX12       = block(14:24:end);
AmpX13       = block(15:24:end);
AmpX14       = block(16:24:end);
AmpZ0PLag11  = block(17:24:end);
AmpZ0PLag12  = block(18:24:end);
AmpZ0PLag13  = block(19:24:end);
AmpZ0PLag14  = block(20:24:end);
AmpZ0PLag21  = block(21:24:end);
AmpZ0PLag22  = block(22:24:end);
AmpZ0PLag23  = block(23:24:end);
AmpZ0PLag24  = block(24:24:end);

if nRecords > 1
    Sync = num2cell(Sync);
    Id = num2cell(Id);
    Size = num2cell(Size);
    Distance = num2cell(Distance);
    DistQuality = num2cell(DistQuality);
    Lag1 = num2cell(Lag1);
    Lag2 = num2cell(Lag2);
    Noise1 = num2cell(Noise1);
    Noise2 = num2cell(Noise2);
    Noise3 = num2cell(Noise3);
    Noise4 = num2cell(Noise4);
    Correlation1 = num2cell(Correlation1);
    Correlation2 = num2cell(Correlation2);
    Correlation3 = num2cell(Correlation3);
    Correlation4 = num2cell(Correlation4);
    Temperature = num2cell(Temperature);
    SoundSpeed = num2cell(SoundSpeed);
    AmpZ01 = num2cell(AmpZ01);
    AmpZ02 = num2cell(AmpZ02);
    AmpZ03 = num2cell(AmpZ03);
    AmpZ04 = num2cell(AmpZ04);
    AmpX11 = num2cell(AmpX11);
    AmpX12 = num2cell(AmpX12);
    AmpX13 = num2cell(AmpX13);
    AmpX14 = num2cell(AmpX14);
    AmpZ0PLag11 = num2cell(AmpZ0PLag11);
    AmpZ0PLag12 = num2cell(AmpZ0PLag12);
    AmpZ0PLag13 = num2cell(AmpZ0PLag13);
    AmpZ0PLag14 = num2cell(AmpZ0PLag14);
    AmpZ0PLag21 = num2cell(AmpZ0PLag21);
    AmpZ0PLag22 = num2cell(AmpZ0PLag22);
    AmpZ0PLag23 = num2cell(AmpZ0PLag23);
    AmpZ0PLag24 = num2cell(AmpZ0PLag24);
    Checksum = num2cell(Checksum);
end

sect = struct('Sync', Sync, ...
    'Id', Id, ...
    'Size', Size, ...
    'Distance', Distance, ...
    'DistQuality', DistQuality, ...
    'Lag1', Lag1, ...
    'Lag2', Lag2, ...
    'Noise1', Noise1, ...
    'Noise2', Noise2, ...
    'Noise3', Noise3, ...
    'Noise4', Noise4, ...
    'Correlation1', Correlation1, ...
    'Correlation2', Correlation2, ...
    'Correlation3', Correlation3, ...
    'Correlation4', Correlation4, ...
    'Temperature', Temperature, ...
    'SoundSpeed', SoundSpeed, ...
    'AmpZ01', AmpZ01, ...
    'AmpZ02', AmpZ02, ...
    'AmpZ03', AmpZ03, ...
    'AmpZ04', AmpZ04, ...
    'AmpX11', AmpX11, ...
    'AmpX12', AmpX12, ...
    'AmpX13', AmpX13, ...
    'AmpX14', AmpX14, ...
    'AmpZ0PLag11', AmpZ0PLag11, ...
    'AmpZ0PLag12', AmpZ0PLag12, ...
    'AmpZ0PLag13', AmpZ0PLag13, ...
    'AmpZ0PLag14', AmpZ0PLag14, ...
    'AmpZ0PLag21', AmpZ0PLag21, ...
    'AmpZ0PLag22', AmpZ0PLag22, ...
    'AmpZ0PLag23', AmpZ0PLag23, ...
    'AmpZ0PLag24', AmpZ0PLag24, ...
    'Checksum', Checksum);

end

function sect = readVectrinoVelocity(data, cpuEndianness)
%READVECTRINOVELOCITY Reads a Vectrino Velocity data section (pg 43 of
% system integrator manual).
% Id=0x51, Vectrino velocity data Size Name Offset Description
% SYSTEM INTEGRATOR MANUAL (Dec 2014) pg 58

nRecords = size(data, 1);

Sync     = data(:, 1);
Id       = data(:, 2);

% [exvcccbb] status bits, where
% e = error (0 = no error, 1 = error condition)
% x = not used
% v = velocity scaling (0 = mm/s, 1 = 0.1mm/s)
% ccc = #cells -1
% bb = #beams -1
% is 'e' bit0 or bit7?
Status   = uint8(data(:, 3));

Count    = data(:, 4);

block1   = data(:, 5:12); % int16

block2   = data(:, 13:20); % uint8

Checksum = data(:, 21:22); % uint16

block    = bytecast(reshape(block1', [], 1), 'L', 'int16', cpuEndianness);
Vel1     = block(1:4:end);
Vel2     = block(2:4:end);
Vel3     = block(3:4:end);
Vel4     = block(4:4:end);

block    = bytecast(reshape(block2', [], 1), 'L', 'uint8', cpuEndianness);
Amp1     = block(1:8:end);
Amp2     = block(2:8:end);
Amp3     = block(3:8:end);
Amp4     = block(4:8:end);
Corr1    = block(5:8:end);
Corr2    = block(6:8:end);
Corr3    = block(7:8:end);
Corr4    = block(8:8:end);

Checksum = bytecast(reshape(Checksum', [], 1), 'L', 'uint16', cpuEndianness);

if nRecords > 1
    Sync = num2cell(Sync);
    Id = num2cell(Id);
    Status = num2cell(Status);
    Count = num2cell(Count);
    Vel1 = num2cell(Vel1);
    Vel2 = num2cell(Vel2);
    Vel3 = num2cell(Vel3);
    Vel4 = num2cell(Vel4);
    Amp1 = num2cell(Amp1);
    Amp2 = num2cell(Amp2);
    Amp3 = num2cell(Amp3);
    Amp4 = num2cell(Amp4);
    Corr1 = num2cell(Corr1);
    Corr2 = num2cell(Corr2);
    Corr3 = num2cell(Corr3);
    Corr4 = num2cell(Corr4);
    Checksum = num2cell(Checksum);
end

sect = struct('Sync', Sync, ...
    'Id', Id, ...
    'Status', Status, ...
    'Count', Count, ...
    'Vel1', Vel1, ...
    'Vel2', Vel2, ...
    'Vel3', Vel3, ...
    'Vel4', Vel4, ...
    'Amp1', Amp1, ...
    'Amp2', Amp2, ...
    'Amp3', Amp3, ...
    'Amp4', Amp4, ...
    'Corr1', Corr1, ...
    'Corr2', Corr2, ...
    'Corr3', Corr3, ...
    'Corr4', Corr4, ...
    'Checksum', Checksum);

end

function sect = readVectrinoDistance(data, cpuEndianness)
%READVECTRINODISTANCE Reads a Vectrino distance data section.
% Id=0x02, Vectrino distance data
% SYSTEM INTEGRATOR MANUAL (Dec 2014) pg 58-59

nRecords = size(data, 1);

Sync        = data(:, 1);
Id          = data(:, 2);
Size        = data(:, 3:4); % uint16
Temperature = bytecast(reshape(data(:, 5:6)', [], 1), 'L', 'int16', cpuEndianness); % int16
block1      = data(:, 7:16); % uint16
blocks      = bytecast(reshape([Size block1]', [], 1), 'L', 'uint16', cpuEndianness);
Size        = blocks(1:6:end);
SoundSpeed  = blocks(2:6:end);
Distance    = blocks(3:6:end);
DistQuality = blocks(4:6:end);
% bytes 12-13 are spare
Checksum    = blocks(6:6:end);

if nRecords > 1
    Sync = num2cell(Sync);
    Id = num2cell(Id);
    Size = num2cell(Size);
    Temperature = num2cell(Temperature);
    SoundSpeed = num2cell(SoundSpeed);
    Distance = num2cell(Distance);
    DistQuality = num2cell(DistQuality);
    Checksum = num2cell(Checksum);
end

sect = struct('Sync', Sync, ...
    'Id', Id, ...
    'Size', Size, ...
    'Temperature', Temperature, ...
    'SoundSpeed', SoundSpeed, ...
    'Distance', Distance, ...
    'DistQuality', DistQuality, ...
    'Checksum', Checksum);

end

function [sect, len] = readGeneric(data, idx, cpuEndianness)
%READGENERIC Skip past an unknown sector type

Id          = data(idx+1);
Size   = bytecast(data(idx+2:idx+3), 'L', 'uint16', cpuEndianness);
len              = Size * 2;

sect = [];

disp(['Skipping sector type ' num2str(Id) ' at ' num2str(idx) ' size ' num2str(Size)]);

end

function sect = readAwacAST(data, cpuEndianness)
%READAWACAST
% Awac Cleaned Up AST Time Series
% Id=0x65 SYSTEM INTEGRATOR MANUAL (Dec 2014) pg 54-55

nRecords = size(data, 1);

Sync   = data(:, 1);
Id     = data(:, 2);
Size   = bytecast(reshape(data(:, 3:4)', [], 1), 'L', 'uint16', cpuEndianness);
Time   = readClockData(data(:, 5:10));
Samples= bytecast(reshape(data(:, 11:12)', [], 1), 'L', 'uint16', cpuEndianness);
% 13 is Spare

nSamples = Samples(1); % hopefully this doesn't change!

astOff = 25;
% description in System Integrator manual unclear, but this calculation of
% csOff works to produce correct checksum comparison
csOff   = astOff + nSamples*2;
ast = bytecast(reshape(data(:, astOff:csOff-1)', [], 1), 'L', 'uint16', cpuEndianness); % mm

ast = reshape(ast, [], nRecords);

Checksum  = bytecast(reshape(data(:, csOff:csOff+1)', [], 1), 'L', 'uint16', cpuEndianness);

if nRecords > 1
    Sync = num2cell(Sync);
    Id = num2cell(Id);
    Size = num2cell(Size);
    Time = num2cell(Time);
    Samples = num2cell(Samples);
    ast = mat2cell(ast, nSamples, ones(1, nRecords))';
    Checksum = num2cell(Checksum);
end

sect = struct('Sync', Sync, ...
    'Id', Id, ...
    'Size', Size, ...
    'Time', Time, ...
    'Samples', Samples, ...
    'ast', ast, ...
    'Checksum', Checksum);

end

function sect = readAwacProcessedVelocity(data, cpuEndianness)
% Awac Processed Velocity Profile Data
% Id=0x6A SYSTEM INTEGRATOR MANUAL (Dec 2014) pg 55-56

nRecords = size(data, 1);

Sync    = data(:, 1);
Id      = data(:, 2);
Size    = bytecast(reshape(data(:, 3:4)', [], 1), 'L', 'uint16', cpuEndianness);
 
Time    = readClockData(data(:, 5:10));
milliSeconds = bytecast(reshape(data(:, 11:12)', [], 1), 'L', 'uint16', cpuEndianness);
Time    = Time + (milliSeconds/1000/60/60/24);

Beams   = bytecast(data(:, 13), 'L', 'uint8', cpuEndianness);
Cells   = bytecast(data(:, 14), 'L', 'uint8', cpuEndianness);
nCells  = Cells(1); % we assume this doesn't change and the first one is correct!

% velocity
vel1Off = 15;
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

% fill value included if number of cells is odd unconfirmed but was the only way to make this work
if mod(nCells, 2), csOff = csOff + 1; end

% tilt effect corrected velocity
Vel1 = bytecast(reshape(data(:, vel1Off:vel1Off+nCells*2-1)', [], 1), 'L', 'int16', cpuEndianness); % U comp (East)  % int16
Vel2 = bytecast(reshape(data(:, vel2Off:vel2Off+nCells*2-1)', [], 1), 'L', 'int16', cpuEndianness); % V comp (North) % int16
Vel3 = bytecast(reshape(data(:, vel3Off:vel3Off+nCells*2-1)', [], 1), 'L', 'int16', cpuEndianness); % W comp (up)    % int16

Snr1 = bytecast(reshape(data(:, snr1Off:snr1Off+nCells*2-1)', [], 1), 'L', 'uint16', cpuEndianness);
Snr2 = bytecast(reshape(data(:, snr2Off:snr2Off+nCells*2-1)', [], 1), 'L', 'uint16', cpuEndianness);
Snr3 = bytecast(reshape(data(:, snr3Off:snr3Off+nCells*2-1)', [], 1), 'L', 'uint16', cpuEndianness);

Std1 = bytecast(reshape(data(:, std1Off:std1Off+nCells*2-1)', [], 1), 'L', 'uint16', cpuEndianness); % currently not used
Std2 = bytecast(reshape(data(:, std2Off:std2Off+nCells*2-1)', [], 1), 'L', 'uint16', cpuEndianness); % currently not used
Std3 = bytecast(reshape(data(:, std3Off:std3Off+nCells*2-1)', [], 1), 'L', 'uint16', cpuEndianness); % currently not used

Erc1 = bytecast(reshape(data(:, erc1Off:erc1Off+nCells-1)', [], 1),   'L', 'uint8', cpuEndianness); % error codes for each cell in beam 1, values between 0 and 4.
Erc2 = bytecast(reshape(data(:, erc2Off:erc2Off+nCells-1)', [], 1),   'L', 'uint8', cpuEndianness); % error codes for each cell in beam 2, values between 0 and 4.
Erc3 = bytecast(reshape(data(:, erc3Off:erc3Off+nCells-1)', [], 1),   'L', 'uint8', cpuEndianness); % error codes for each cell in beam 3, values between 0 and 4.

speed            = bytecast(reshape(data(:, spdOff:spdOff+nCells*2-1)', [], 1), 'L', 'uint16', cpuEndianness);
direction        = bytecast(reshape(data(:, dirOff:dirOff+nCells*2-1)', [], 1), 'L', 'uint16', cpuEndianness);
verticalDistance = bytecast(reshape(data(:, vdtOff:vdtOff+nCells*2-1)', [], 1), 'L', 'uint16', cpuEndianness);
profileErrorCode = bytecast(reshape(data(:, percOff:percOff+nCells-1)', [], 1), 'L', 'uint8',  cpuEndianness); % error codes for each cell of a velocity profile inferred from the 3 beams. 0=good; otherwise error. See http://www.nortek-as.com/en/knowledge-center/forum/waves/20001875?b_start=0#769595815
qcFlag           = bytecast(reshape(data(:, qcOff:qcOff+nCells-1)',     [], 1), 'L', 'uint8',  cpuEndianness); % QUARTOD QC result. 0=not eval; 1=bad; 2=questionable; 3=good.
Checksum         = bytecast(reshape(data(:, csOff:csOff+1)',            [], 1), 'L', 'uint16', cpuEndianness);

Vel1 = reshape(Vel1, [], nRecords);
Vel2 = reshape(Vel2, [], nRecords);
Vel3 = reshape(Vel3, [], nRecords);

Snr1 = reshape(Snr1, [], nRecords);
Snr2 = reshape(Snr2, [], nRecords);
Snr3 = reshape(Snr3, [], nRecords);

Std1 = reshape(Std1, [], nRecords);
Std2 = reshape(Std2, [], nRecords);
Std3 = reshape(Std3, [], nRecords);

Erc1 = reshape(Erc1, [], nRecords);
Erc2 = reshape(Erc2, [], nRecords);
Erc3 = reshape(Erc3, [], nRecords);

speed               = reshape(speed,            [], nRecords);
direction           = reshape(direction,        [], nRecords);
verticalDistance    = reshape(verticalDistance, [], nRecords);
profileErrorCode    = reshape(profileErrorCode, [], nRecords);
qcFlag              = reshape(qcFlag,           [], nRecords);

% speed(speed == 8936) = NaN; % this needs to be checked with Nortek
% direction(direction == 27108) = NaN;

speed(qcFlag == 1)      = NaN; % this needs to be checked with Nortek
direction(qcFlag == 1)  = NaN;

if nRecords > 1
    Sync = num2cell(Sync);
    Id = num2cell(Id);
    Size = num2cell(Size);
    Time = num2cell(Time);
    Beams = num2cell(Beams);
    Cells = num2cell(Cells);
    Vel1 = mat2cell(Vel1, nCells, ones(1, nRecords))';
    Vel2 = mat2cell(Vel2, nCells, ones(1, nRecords))';
    Vel3 = mat2cell(Vel3, nCells, ones(1, nRecords))';
    Snr1 = mat2cell(Snr1, nCells, ones(1, nRecords))';
    Snr2 = mat2cell(Snr2, nCells, ones(1, nRecords))';
    Snr3 = mat2cell(Snr3, nCells, ones(1, nRecords))';
    Std1 = mat2cell(Std1, nCells, ones(1, nRecords))';
    Std2 = mat2cell(Std2, nCells, ones(1, nRecords))';
    Std3 = mat2cell(Std3, nCells, ones(1, nRecords))';
    Erc1 = mat2cell(Erc1, nCells, ones(1, nRecords))';
    Erc2 = mat2cell(Erc2, nCells, ones(1, nRecords))';
    Erc3 = mat2cell(Erc3, nCells, ones(1, nRecords))';
    speed = mat2cell(speed, nCells, ones(1, nRecords))';
    direction = mat2cell(direction, nCells, ones(1, nRecords))';
    verticalDistance = mat2cell(verticalDistance, nCells, ones(1, nRecords))';
    profileErrorCode = mat2cell(profileErrorCode, nCells, ones(1, nRecords))';
    qcFlag = mat2cell(qcFlag, nCells, ones(1, nRecords))';
    Checksum = num2cell(Checksum);
end

sect = struct('Sync', Sync, ...
    'Id', Id, ...
    'Size', Size, ...
    'Time', Time, ...
    'Beams', Beams, ...
    'Cells', Cells, ...
    'Vel1', Vel1, ...
    'Vel2', Vel2, ...
    'Vel3', Vel3, ...
    'Snr1', Snr1, ...
    'Snr2', Snr2, ...
    'Snr3', Snr3, ...
    'Std1', Std1, ...
    'Std2', Std2, ...
    'Std3', Std3, ...
    'Erc1', Erc1, ...
    'Erc2', Erc2, ...
    'Erc3', Erc3, ...
    'speed', speed, ...
    'direction', direction, ...
    'verticalDistance', verticalDistance, ...
    'profileErrorCode', profileErrorCode, ...
    'qcFlag', qcFlag, ...
    'Checksum', Checksum);

end

function sect = readVectorProbeCheck(data, cpuEndianness)
%READVECTORPROBECHECK Reads an Vector Probe Check section.
% Id=0x07, Vector and Vectrino Probe Check Data
% SYSTEM INTEGRATOR MANUAL (Dec 2014) pg 38
% The structure of the probe check is the same for both Vectrino and Vector. 
% The difference is that a Vector has 3 beams and 300 samples, while the 
% Vectrino has 4 beams and 500 samples

sect = [];

fprintf('%s\n', 'Warning : readVectorProbeCheck not implemented yet.');

end

function sect = readWaveParameterEstimates(data, cpuEndianness)
%READWAVEPARAMETERESTIMATES Reads an AWAC Wave Parameter Estimates section.
% Id=0x60, Wave parameter estimates
% SYSTEM INTEGRATOR MANUAL (Dec 2014) pg 52-53

nRecords = size(data, 1);

Sync   = data(:, 1);
Id     = data(:, 2);
Size   = bytecast(reshape(data(:, 3:4)', [], 1), 'L', 'uint16', cpuEndianness);
Time   = readClockData(data(:,5:10));
% Spectrum basis type
% 0-pressure,
% 1-Velocity,
% 3-AST.
SpectrumType = bytecast(data(:, 11), 'L', 'uint8', cpuEndianness); % spectrum used for calculation
% Processing method
% 1-PUV, [Aquadopp/Vector]
% 2-SUV, [AWAC/AST]
% 3-MLM (Maximum Likelihood Method without Surface Tracking) [AWAC],
% 4-MLMST (Maximum Likelihood Method with Surface Tracking) [AWAC/AST].
ProcMethod = bytecast(data(:, 12), 'L', 'uint8', cpuEndianness); % processing method used in actual calculation
block = bytecast(reshape(data(:, 13:34)', [], 1), 'L', 'uint16', cpuEndianness);
Hm0 =      block(1:11:end); % Spectral significant wave height [mm]
H3 =       block(2:11:end); % AST significant wave height (mean of largest 1/3) [mm]
H10 =      block(3:11:end); % AST wave height(mean of largest 1/10) [mm]
Hmax =     block(4:11:end); % AST max wave height in wave ensemble [mm]
Tm02 =     block(5:11:end); % Mean period spectrum based [0.01 sec]
Tp =       block(6:11:end); % Peak period [0.01 sec]
Tz =       block(7:11:end); % AST mean zero-crossing period [0.01 sec]
DirTp =    block(7:11:end); % Direction at Tp [0.01 deg]
SprTp =    block(9:11:end); % Spreading at Tp [0.01 deg]
DirMean =  block(10:11:end); % Mean wave direction [0.01 deg]
UI =       block(11:11:end); % Unidirectivity index [1/65535]

PressureMean = bytecast(reshape(data(:, 35:38)', [], 1), 'L', 'uint32', cpuEndianness); % Mean pressure during burst [0.001 dbar]
block = bytecast(reshape(data(:, 39:46)', [], 1), 'L', 'uint16', cpuEndianness);
NumNoDet =     block(1:4:end); % Number of AST No detects [#]
NumBadDet =    block(2:4:end); % Number of AST Bad detects [#]
CurSpeedMean = block(3:4:end); % Mean current speed - wave cells [mm/sec]
CurDirMean =   block(4:4:end); % Mean current direction - wave cells [0.01 deg]
block = bytecast(reshape(data(:, 47:58)', [], 1), 'L', 'uint32', cpuEndianness);
Error =        block(1:3:end); % Error Code for bad data
ASTdistMean =  block(2:3:end); % Mean AST distance during burst [mm]
ICEdistMean =  block(3:3:end); % Mean ICE distance during burst [mm]
block = bytecast(reshape(data(:, 59:68)', [], 1), 'L', 'uint16', cpuEndianness);
freqDirAmbLimit =  block(1:5:end); % Low frequency in [0.001 Hz]
T3 =               block(2:5:end); % AST significant wave period (sec)
T10 =              block(3:5:end); % AST 1/10 wave period (sec)
Tmax =             block(4:5:end); % AST max period in wave ensemble (sec)
Hmean =            block(5:5:end); % Mean wave height (mm)
% bytes 69:78 are spare
Checksum = bytecast(reshape(data(:, 79:80)', [], 1), 'L', 'uint16', cpuEndianness);

if nRecords > 1
    Sync = num2cell(Sync);
    Id = num2cell(Id);
    Size = num2cell(Size);
    Time = num2cell(Time);
    SpectrumType = num2cell(SpectrumType);
    ProcMethod = num2cell(ProcMethod);
    Hm0 = num2cell(Hm0);
    H3 = num2cell(H3);
    H10 = num2cell(H10);
    Hmax = num2cell(Hmax);
    Tm02 = num2cell(Tm02);
    Tp = num2cell(Tp);
    Tz = num2cell(Tz);
    DirTp = num2cell(DirTp);
    SprTp = num2cell(SprTp);
    DirMean = num2cell(DirMean);
    UI = num2cell(UI);
    PressureMean = num2cell(PressureMean);
    NumNoDet = num2cell(NumNoDet);
    NumBadDet = num2cell(NumBadDet);
    CurSpeedMean = num2cell(CurSpeedMean);
    CurDirMean = num2cell(CurDirMean);
    Error = num2cell(Error);
    ASTdistMean = num2cell(ASTdistMean);
    ICEdistMean = num2cell(ICEdistMean);
    freqDirAmbLimit = num2cell(freqDirAmbLimit);
    T3 = num2cell(T3);
    T10 = num2cell(T10);
    Tmax = num2cell(Tmax);
    Hmean = num2cell(Hmean);
    Checksum = num2cell(Checksum);
end

sect = struct('Sync', Sync, ...
    'Id', Id, ...
    'Size', Size, ...
    'Time', Time, ...
    'SpectrumType', SpectrumType, ...
    'ProcMethod', ProcMethod, ...
    'Hm0', Hm0, ...
    'H3', H3, ...
    'H10', H10, ...
    'Hmax', Hmax, ...
    'Tm02', Tm02, ...
    'Tp', Tp, ...
    'Tz', Tz, ...
    'DirTp', DirTp, ...
    'SprTp', SprTp, ...
    'DirMean', DirMean, ...
    'UI', UI, ...
    'PressureMean', PressureMean, ...
    'NumNoDet', NumNoDet, ...
    'NumBadDet', NumBadDet, ...
    'CurSpeedMean', CurSpeedMean, ...
    'CurDirMean', CurDirMean, ...
    'Error', Error, ...
    'ASTdistMean', ASTdistMean, ...
    'ICEdistMean', ICEdistMean, ...
    'freqDirAmbLimit', freqDirAmbLimit, ...
    'T3', T3, ...
    'T10', T10, ...
    'Tmax', Tmax, ...
    'Hmean', Hmean, ...
    'Checksum', Checksum);

end

function sect = readWaveBandEstimates(data, cpuEndianness)
%READWAVEBANDESTIMATES Reads an AWAC Wave Band Estimates section.
% Id=0x61, Wave band estimates
% SYSTEM INTEGRATOR MANUAL (Dec 2014) pg 53

nRecords = size(data, 1);

Sync   = data(:, 1);
Id     = data(:, 2);
Size   = bytecast(reshape(data(:, 3:4)', [], 1), 'L', 'uint16', cpuEndianness);
Time   = readClockData(data(:, 5:10));

% Spectrum basis type
% 0-pressure,
% 1-Velocity,
% 3-AST.
SpectrumType = data(:, 11); % spectrum used for calculation

% Processing method
% 1-PUV, [Aquadopp/Vector]
% 2-SUV, [AWAC/AST]
% 3-MLM (Maximum Likelihood Method without Surface Tracking) [AWAC],
% 4-MLMST (Maximum Likelihood Method with Surface Tracking) [AWAC/AST].
ProcMethod     = data(:, 12); % processing method used in actual calculation

block          = bytecast(reshape(data(:, 13:28)', [], 1), 'L', 'uint16', cpuEndianness);
LowFrequency   = block(1:8:end); % low frequency in [0.001 Hz]
HighFrequency  = block(2:8:end); % high frequency in [0.001 Hz]
Hm0            = block(3:8:end); % Spectral significant wave height [mm]
Tm02           = block(4:8:end); % Mean period spectrum based [0.01 sec]
Tp             = block(5:8:end); % Peak period [0.01 sec]
DirTp          = block(6:8:end); % Direction at Tp [0.01 deg]
DirMean        = block(7:8:end); % Mean wave direction [0.01 deg]
SprTp          = block(8:8:end); % Spreading at Tp [0.01 deg]

Error    = bytecast(reshape(data(:, 29:32)', [], 1), 'L', 'uint32', cpuEndianness); % Error Code for bad data
% 33:46 Spares
Checksum = bytecast(reshape(data(:, 47:48)', [], 1), 'L', 'uint16', cpuEndianness);

if nRecords > 1
    Sync = num2cell(Sync);
    Id = num2cell(Id);
    Size = num2cell(Size);
    Time = num2cell(Time);
    SpectrumType = num2cell(SpectrumType);
    ProcMethod = num2cell(ProcMethod);
    LowFrequency = num2cell(LowFrequency);
    HighFrequency = num2cell(HighFrequency);
    Hm0 = num2cell(Hm0);
    Tm02 = num2cell(Tm02);
    Tp = num2cell(Tp);
    DirTp = num2cell(DirTp);
    DirMean = num2cell(DirMean);
    SprTp = num2cell(SprTp);
    Error = num2cell(Error);
    Checksum = num2cell(Checksum);
end

sect = struct('Sync', Sync, ...
    'Id', Id, ...
    'Size', Size, ...
    'Time', Time, ...
    'SpectrumType', SpectrumType, ...
    'ProcMethod', ProcMethod, ...
    'LowFrequency', LowFrequency, ...
    'HighFrequency', HighFrequency, ...
    'Hm0', Hm0, ...
    'Tm02', Tm02, ...
    'Tp', Tp, ...
    'DirTp', DirTp, ...
    'DirMean', DirMean, ...
    'SprTp', SprTp, ...
    'Error', Error, ...
    'Checksum', Checksum);

end

function sect = readWaveEnergySpectrum(data, cpuEndianness)
%READWAVEENERGYSPECTRUM Reads an AWAC Wave Energy Spectrum section.
% Id=0x62, Wave energy spectrum
% SYSTEM INTEGRATOR MANUAL (Dec 2014) pg 53-54

nRecords = size(data, 1);

Sync   = data(:, 1);
Id     = data(:, 2);
Size   = bytecast(reshape(data(:, 3:4)', [], 1), 'L', 'uint16', cpuEndianness);
Time   = readClockData(data(: ,5:10));

% Spectrum basis type
% 0-pressure,
% 1-Velocity,
% 3-AST.
SpectrumType  = data(:, 11); % spectrum used for calculation
% 12 is Spare

block         = bytecast(reshape(data(:, 13:20)', [], 1), 'L', 'uint16', cpuEndianness);
NumSpectrum   = block(1:4:end); % number of spectral bins 
LowFrequency  = block(2:4:end); % low frequency in [0.001 Hz]
HighFrequency = block(3:4:end); % high frequency in [0.001 Hz]
StepFrequency = block(4:4:end); % frequency step in [0.001 Hz]
% 21:38 are Spares

% AST energy spectrum multiplier [cm^2/Hz]
EnergyMultiplier = bytecast(reshape(data(:, 39:42)', [], 1), 'L', 'uint32', cpuEndianness);

nSpectrum = NumSpectrum(1); % hopefully this doesn't change!
eOff = 43;
csOff = eOff + nSpectrum*2;
% AST Spectra [0 - 1/65535] 
Energy = bytecast(reshape(data(:, eOff:csOff-1)', [], 1), 'L', 'uint16', cpuEndianness);

Energy = reshape(Energy, [], nRecords);

Checksum = bytecast(reshape(data(:, csOff:csOff+1)', [], 1), 'L', 'uint16', cpuEndianness);

if nRecords > 1
    Sync = num2cell(Sync);
    Id = num2cell(Id);
    Size = num2cell(Size);
    Time = num2cell(Time);
    SpectrumType = num2cell(SpectrumType);
    NumSpectrum = num2cell(NumSpectrum);
    LowFrequency = num2cell(LowFrequency);
    HighFrequency = num2cell(HighFrequency);
    StepFrequency = num2cell(StepFrequency);
    EnergyMultiplier = num2cell(EnergyMultiplier);
    Energy = mat2cell(Energy, nSpectrum, ones(1, nRecords))';
    Checksum = num2cell(Checksum);
end

sect = struct('Sync', Sync, ...
    'Id', Id, ...
    'Size', Size, ...
    'Time', Time, ...
    'SpectrumType', SpectrumType, ...
    'NumSpectrum', NumSpectrum, ...
    'LowFrequency', LowFrequency, ...
    'HighFrequency', HighFrequency, ...
    'StepFrequency', StepFrequency, ...
    'EnergyMultiplier', EnergyMultiplier, ...
    'Energy', Energy, ...
    'Checksum', Checksum);

end

function sect = readWaveFourierCoefficentSpectrum(data, cpuEndianness)
%READWAVEFOURIERCOEFFICIENTSSPECTRUM Reads an AWAC Wave Fourier Coefficient Spectrum section.
% Id=0x63, Wave fourier coefficient spectrum
% SYSTEM INTEGRATOR MANUAL (Dec 2014) pg 54

nRecords = size(data, 1);

Sync   = data(:, 1);
Id     = data(:, 2);
Size   = bytecast(reshape(data(:, 3:4)', [], 1), 'L', 'uint16', cpuEndianness);
Time   = readClockData(data(: ,5:10));

% 11 is cSpare

% Processing method
% 1-PUV, [Aquadopp/Vector]
% 2-SUV, [AWAC/AST]
% 3-MLM (Maximum Likelihood Method without Surface Tracking) [AWAC],
% 4-MLMST (Maximum Likelihood Method with Surface Tracking) [AWAC/AST].
ProcMethod    = data(:, 12); % processing method used in actual calculation

block         = bytecast(reshape(data(:, 13:20)', [], 1), 'L', 'uint16', cpuEndianness);
NumSpectrum   = block(1:4:end); % number of spectral bins 
LowFrequency  = block(2:4:end); % low frequency in [0.001 Hz]
HighFrequency = block(3:4:end); % high frequency in [0.001 Hz]
StepFrequency = block(4:4:end); % frequency step in [0.001 Hz]
% 21:30 are 5 x uint16 spares

nSpectrum = NumSpectrum(1); % hopefully this doesn't change!
a1Off = 31;
b1Off = a1Off + nSpectrum*2;
a2Off = b1Off + nSpectrum*2;
b2Off = a2Off + nSpectrum*2;
csOff = b2Off + nSpectrum*2;

% fourier coefficients n [+/- 1/32767]
A1 = bytecast(reshape(data(:, a1Off:b1Off-1)', [], 1), 'L', 'int16', cpuEndianness);
B1 = bytecast(reshape(data(:, b1Off:a2Off-1)', [], 1), 'L', 'int16', cpuEndianness);
A2 = bytecast(reshape(data(:, a2Off:b2Off-1)', [], 1), 'L', 'int16', cpuEndianness);
B2 = bytecast(reshape(data(:, b2Off:csOff-1)', [], 1), 'L', 'int16', cpuEndianness);

A1 = reshape(A1, [], nRecords);
B1 = reshape(B1, [], nRecords);
A2 = reshape(A2, [], nRecords);
B2 = reshape(B2, [], nRecords);

Checksum = bytecast(reshape(data(:, csOff:csOff+1)', [], 1), 'L', 'uint16', cpuEndianness);

if nRecords > 1
    Sync = num2cell(Sync);
    Id = num2cell(Id);
    Size = num2cell(Size);
    Time = num2cell(Time);
    ProcMethod = num2cell(ProcMethod);
    NumSpectrum = num2cell(NumSpectrum);
    LowFrequency = num2cell(LowFrequency);
    HighFrequency = num2cell(HighFrequency);
    StepFrequency = num2cell(StepFrequency);
    A1 = mat2cell(A1, nSpectrum, ones(1, nRecords))';
    B1 = mat2cell(B1, nSpectrum, ones(1, nRecords))';
    A2 = mat2cell(A2, nSpectrum, ones(1, nRecords))';
    B2 = mat2cell(B2, nSpectrum, ones(1, nRecords))';
    Checksum = num2cell(Checksum);
end

sect = struct('Sync', Sync, ...
    'Id', Id, ...
    'Size', Size, ...
    'Time', Time, ...
    'ProcMethod', ProcMethod, ...
    'NumSpectrum', NumSpectrum, ...
    'LowFrequency', LowFrequency, ...
    'HighFrequency', HighFrequency, ...
    'StepFrequency', StepFrequency, ...
    'A1', A1, ...
    'B1', B1, ...
    'A2', A2, ...
    'B2', B2, ...
    'Checksum', Checksum);

end

function cs = genChecksum(data)
%GENCHECKSUM Generates a checksum over the given data range. See page 52 of
%the System integrator manual.
%
nRecords = size(data, 1);

% start checksum value is 0xb58c (== 46476)
cs = 46476 * ones(nRecords, 1);

% the checksum routine relies upon uint16 overflow, but matlab's
% 'saturation' of out-of-bounds values makes this impossible.
% so i'm doing normal addition, then modding the result by 65536,
% which will give the same result
data = double(data);

dataO = data(:, 1:2:end-1);
dataE = data(:, 2:2:end);

cs = cs + sum(dataO, 2) + sum(dataE, 2)*256;

cs = mod(cs, 65536 * ones(nRecords, 1));

end
