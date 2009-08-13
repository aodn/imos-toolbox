function waveData = readAWACWaveAscii( filename )
%READAWACWAVEASCII Reads AWAC wave data from processed wave text files 
% (.whd, .wap).
%
% This function takes the name of a raw AWAC binary file (.wpr), and from
% that name locates the wave header and processed wave data files (.whd,
% .wap). It is assumed that these files are located in the same directory
% as the raw binary file.
%
% This function currently assumes a number of things:
%
%   - That both the .whd and .wap files exist in the same directory as the
%     input file.
%   - That both the .whd and .wap files have the same number of rows.
%   - That the timestamps for corresponding rows in the .whd and .wap files
%     are identical.
%   - That the .whd and .wap files adhere to the column layouts listed
%     below.
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
%    1   Month                            (1-12)
%    2   Day                              (1-31)
%    3   Year
%    4   Hour                             (0-23)
%    5   Minute                           (0-59)
%    6   Second                           (0-59)
%    7   Significant height (Hs)          (m)
%    8   Mean zerocrossing period (Tm02)  (s)
%    9   Peak period (Tp)                 (s)
%   10   Peak direction (DirTp)           (deg)
%   11   Directional spread (Spr1)        (deg)
%   12   Mean direction (Mdir)            (deg)
%   13   Mean Pressure                    (m)
%   14   Unidirectivity index
%   15   Error Code
%
% A future enhancement to this function would be to work from the header 
% files (.hdr/.whr) which defines the column layout.
%
% Inputs:
%   filename - The name of a raw AWAC binary file (.wpr).
%
% Outputs:
%   waveData - struct containing data read in from the wave data text files.
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
error(nargchk(1,1,nargin));

if ~ischar(filename), error('filename must be a string'); end

% transform the filename into wave header and processed wave data filenames
[path name ext] = fileparts(filename);

headerFile = fullfile(path, [name '.whd']);
waveFile   = fullfile(path, [name '.wap']);

% will throw error if the files do not exist
header = importdata(headerFile);
wave   = importdata(waveFile);

waveData = struct;

% copy data over to struct
waveData.Time = datenum(...
  header(:,3), header(:,1), header(:,2), ...
  header(:,4), header(:,5), header(:,6)  ...
);

waveData.Battery     = header(:,10);
waveData.Heading     = header(:,12);
waveData.Pitch       = header(:,13);
waveData.Roll        = header(:,14);
waveData.MinPressure = header(:,15);
waveData.MaxPressure = header(:,16);
waveData.Temperature = header(:,17);

waveData.SignificantHeight      = wave(:,7);
waveData.MeanZeroCrossingPeriod = wave(:,8);
waveData.PeakPeriod             = wave(:,9);
waveData.PeakDirection          = wave(:,10);
waveData.DirectionalSpread      = wave(:,11);
waveData.MeanDirection          = wave(:,12);
waveData.MeanPressure           = wave(:,13);
waveData.UnidirectivityIndex    = wave(:,14);
