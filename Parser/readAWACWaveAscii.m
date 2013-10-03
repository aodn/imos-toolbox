function waveData = readAWACWaveAscii( filename )
%READAWACWAVEASCII Reads AWAC wave data from processed wave text files 
% (.whd, .wap, .was, .wdr, .wds).
%
% This function takes the name of a raw AWAC binary file (.wpr), and from
% that name locates the wave header and processed wave data files (.whd,
% .wap), and power and directional spectra files (.was, .wdr, .wds). Those 
% files can be obtained using QuickWave or Storm Nortek softwares. It is 
% assumed that these files are located in the same directory as the raw 
% binary file.
%
% This function currently assumes a number of things:
%
%   - That the .whd, .wap, .was, .wdr and .wds files exist in the same 
%     directory as the input file.
%   - That the .wds file contains 90 rows per frequency.
%   - That the files adhere to the column layouts listed below.
%
% Assumed column layout for wave header data file (.whd):
% 
%    1   Month                            (1-12)
%    2   Day                              (1-31)
%    3   Year
%    4   Hour                             (0-23)
%    5   Minute                           (0-59)
%    6   Second                           (0-59)
%    7   Burst counter
%    8   No of wave data records
%    9   Cell position                    (m)
%   10   Battery voltage                  (V)
%   11   Soundspeed                       (m/s)
%   12   Heading                          (degrees)
%   13   Pitch                            (degrees)
%   14   Roll                             (degrees)
%   15   Minimum pressure                 (dbar)
%   16   Maximum pressure                 (dbar)
%   17   Temperature                      (degrees C)
%   18   CellSize                         (m)
%   19   Noise amplitude beam 1           (counts)
%   20   Noise amplitude beam 2           (counts)
%   21   Noise amplitude beam 3           (counts)
%   22   Noise amplitude beam 4           (counts)
%   23   AST window start                 (m)
%
% Assumed column layout for processed wave data file (.wap):
%
%      1   Month                            (1-12)
%      2   Day                              (1-31)
%      3   Year
%      4   Hour                             (0-23)
%      5   Minute                           (0-59)
%      6   Second                           (0-59)
%      7   Spectrum type                    (0-Pressure, 1-Velocity, 3-AST)
%      8   Significant height (Hm0)         (m)
%      9   Mean 1/3 height (H3)             (m)
%     10   Mean 1/10 height (H10)           (m)
%     11   Maximum height (Hmax)            (m)
%     12   Mean Height (Hmean)              (m)
%     13   Mean  period (Tm02)              (s)
%     14   Peak period (Tp)                 (s)
%     15   Mean zerocrossing period (Tz)    (s)
%     16   Mean 1/3 Period (T3)             (s)
%     17   Mean 1/10 Period (T10)           (s)
%     18   Maximum Period (Tmax)            (s)
%     19   Peak direction (DirTp)           (deg)
%     20   Directional spread (SprTp)       (deg)
%     21   Mean direction (Mdir)            (deg)
%     22   Unidirectivity index
%     23   Mean Pressure                    (dbar)
%     24   Mean AST distance                (m)
%     25   Mean AST distance (Ice)          (m)
%     26   No Detects
%     27   Bad Detects
%     28   Number of Zero-Crossings
%     29   Current speed (wave cell)        (m/s)
%     30   Current direction (wave cell)    (degrees)
%     31   Error Code
%
% Assumed file layout for power spectra data file (.was):
%
%       Frequency Vector                 (Hz)
%   1   Power Spectrum                   (m^2/Hz)
%   2   Power Spectrum                   (m^2/Hz)
%   .
%   n   Power Spectrum                   (m^2/Hz)
%
% Assumed file layout for power spectra data file (.wdr):
%
%       Frequency Vector                 (Hz)
%   1   Directional Spectrum             (Deg)
%   2   Directional Spectrum             (Deg)
%   .
%   n   Directional Spectrum             (Deg)
%
% Assumed file layout for full spectra data file (.wds):
%
%  Each row is one frequency 0.02:0.01:[0.49 or 0.99] Hz 
%  Each column is dicretized by 4 degrees 0:4:356 degrees
%   Burst 1  [# frequencies rows ]x[90 columns]     (Normalized-Energy/deg)
%   Burst 2  [# frequencies rows ]x[90 columns]     (Normalized-Energy/deg)
%         .
%   Burst n  [# frequencies rows ]x[90 columns]     (Normalized-Energy/deg)
%
%
% A future enhancement to this function would be to work from the header 
% files (.hdr/.whr) which defines the file layout for all files.
%
% Inputs:
%   filename - The name of a raw AWAC binary file (.wpr).
%
% Outputs:
%   waveData - struct containing data read in from the wave data text files.
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
%
error(nargchk(1, 1, nargin));

if ~ischar(filename), error('filename must be a string'); end

waveData = [];

% transform the filename into processed wave data filenames
[path, name] = fileparts(filename);

headerFile     = fullfile(path, [name '.whd']);
waveFile       = fullfile(path, [name '.wap']);
dirFreqFile    = fullfile(path, [name '.wdr']);
pwrFreqFile    = fullfile(path, [name '.was']);
pwrFreqDirFile = fullfile(path, [name '.wds']);

% test the files exist
if ~exist(headerFile, 'file') || ~exist(waveFile, 'file') || ...
        ~exist(dirFreqFile, 'file') || ~exist(pwrFreqFile, 'file') || ...
        ~exist(pwrFreqDirFile, 'file')
    fprintf('%s\n', ['Info : To read wave data related to ' name ...
        ', .whd, .wap, .wdr, .was, .wds are necessary ' ...
        '(use QuickWave or Storm Nortek softwares).']);
    return;
end

try
    header     = importdata(headerFile);
    wave       = importdata(waveFile);
    dirFreq    = importdata(dirFreqFile);
    pwrFreq    = importdata(pwrFreqFile);
    pwrFreqDir = importdata(pwrFreqDirFile);
    
    % Transform local missing value (-9.00) to NaN
    wave(wave == -9.00) = NaN;
    dirFreq(dirFreq == -9.00) = NaN;
    pwrFreq(pwrFreq == -9.000000) = NaN;
    pwrFreqDir(pwrFreqDir == -9.000000) = NaN;
    
    % let's have a look at the different time given in each file
    headerTime = datenum(...
        header(:,3), header(:,1), header(:,2), ...
        header(:,4), header(:,5), header(:,6)  ...
        );
    
    waveTime = datenum(...
        wave(:,3), wave(:,1), wave(:,2), ...
        wave(:,4), wave(:,5), wave(:,6)  ...
        );
    
    totalTime = unique([headerTime; waveTime]);
    iHeader = ismember(totalTime, headerTime);
    iWave = ismember(totalTime, waveTime);
    clear headerTime waveTime;
    
    waveData = struct;
    
    % copy data over to struct
    waveData.Time = totalTime;
    nTime = length(totalTime);
    clear totalTime
    
    waveData.Battery     = nan(nTime, 1);
    waveData.Heading     = nan(nTime, 1);
    waveData.Pitch       = nan(nTime, 1);
    waveData.Roll        = nan(nTime, 1);
    waveData.MinPressure = nan(nTime, 1);
    waveData.MaxPressure = nan(nTime, 1);
    waveData.Temperature = nan(nTime, 1);
    
    waveData.Battery(iHeader)     = header(:,10);
    waveData.Heading(iHeader)     = header(:,12);
    waveData.Pitch(iHeader)       = header(:,13);
    waveData.Roll(iHeader)        = header(:,14);
    waveData.MinPressure(iHeader) = header(:,15);
    waveData.MaxPressure(iHeader) = header(:,16);
    waveData.Temperature(iHeader) = header(:,17);
    clear header iHeader;
    
    waveData.SpectraType            = nan(nTime, 1);
    waveData.SignificantHeight      = nan(nTime, 1);
    waveData.MeanZeroCrossingPeriod = nan(nTime, 1);
    waveData.PeakPeriod             = nan(nTime, 1);
    waveData.PeakDirection          = nan(nTime, 1);
    waveData.DirectionalSpread      = nan(nTime, 1);
    waveData.MeanDirection          = nan(nTime, 1);
    waveData.MeanPressure           = nan(nTime, 1);
    waveData.UnidirectivityIndex    = nan(nTime, 1);
    
    waveData.SpectraType(iWave)            = wave(:,7);
    waveData.SignificantHeight(iWave)      = wave(:,8);
    waveData.PeakPeriod(iWave)             = wave(:,14);
    waveData.MeanZeroCrossingPeriod(iWave) = wave(:,15);
    waveData.PeakDirection(iWave)          = wave(:,19);
    waveData.DirectionalSpread(iWave)      = wave(:,20);
    waveData.MeanDirection(iWave)          = wave(:,21);
    waveData.UnidirectivityIndex(iWave)    = wave(:,22);
    waveData.MeanPressure(iWave)           = wave(:,23);
    clear wave;
    
    % let's have a look at the different frequency given in each file
    waveData.pwrFrequency = pwrFreq(1,:)';
    waveData.dirFrequency = dirFreq(1,:)';
    
    nPwrFreq = length(waveData.pwrFrequency);
    nDirFreq = length(waveData.dirFrequency);
    
    waveData.dirSpectrum = nan(nTime, nDirFreq);
    waveData.pwrSpectrum = nan(nTime, nPwrFreq);
    
    waveData.dirSpectrum(iWave, :) = dirFreq(2:end,:);
    clear dirFreq
    waveData.pwrSpectrum(iWave, :) = pwrFreq(2:end,:);
    clear pwrFreq iWave
    
    waveData.Direction = pwrFreqDir(1,:)';
    nDir = length(waveData.Direction);
    
    waveData.fullSpectrum = nan(nTime, nDirFreq, nDir);
    
    % we should have nTime samples so :
    nFreqFullSpectrum = length(pwrFreqDir(2:end,:)) / nTime;
    
    % rearrange full power spectrum matrix so dimensions
    % are ordered: time, frequency, direction
    start = 2;
    for i=1:nTime
        waveData.fullSpectrum(i, :, :) = pwrFreqDir(start:start+nFreqFullSpectrum-1,:);
        start = start+nFreqFullSpectrum;
    end
    clear pwrFreqDir
catch e
    fprintf('%s\n', ['Warning : Wave data related to ' name ...
        ' hasn''t been read successfully.']);
    errorString = getErrorString(e);
    fprintf('%s\n',   ['Error says : ' errorString]);
end

end