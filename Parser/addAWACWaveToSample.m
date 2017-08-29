function sample_data = addAWACWaveToSample(sample_data, waveData, filename)
%ADDAWACWAVETOSAMPLE Adds AWAC wave parameters found in a .wap file to the
%existing sample_data created while reading the .wpr file.
%
% This function performs a mapping between the AWAC wave parameters and the
% IMOS parameters in order to add them to the sample_data structure.
%
% Inputs:
%   sample_data - Struct containing sample data.
%   waveData    - struct containing data read in from the wave data text files.
%   filename    - The name of a raw AWAC binary file (.wpr).
%
% Outputs:
%   sample_data - Struct containing sample data, this will be a cell array of two structs.
%
% Author:       Guillaume Galibert <guillaume.galibert@utas.edu.au>
%

%
% Copyright (c) 2016, Australian Ocean Data Network (AODN) and Integrated 
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
%     * Neither the name of the AODN/IMOS nor the names of its contributors 
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
narginchk(3, 3);

if ~isstruct(sample_data),  error('sample_data must be a struct'); end
if ~isstruct(waveData),     error('waveData must be a struct'); end
if ~ischar(filename),       error('filename must be a string'); end

% turn sample data into a cell array
temp{1} = sample_data;
sample_data = temp;
clear temp;

% copy wave data into a sample_data struct; start with a copy of the 
% first sample_data struct, as all the metadata is the same
sample_data{2} = sample_data{1};

[filePath, fileRadName, ~] = fileparts(filename);
filename = fullfile(filePath, [fileRadName '.wap']);

sample_data{2}.toolbox_input_file               = filename;
sample_data{2}.meta.head                        = [];
sample_data{2}.meta.hardware                    = [];
sample_data{2}.meta.user                        = [];
sample_data{2}.meta.instrument_sample_interval  = median(diff(waveData.Time*24*3600));

avgInterval = [];
if isfield(waveData, 'summary')
    iMatch = ~cellfun(@isempty, regexp(waveData.summary, 'Wave - Number of samples              [0-9]'));
    if any(iMatch)
        nSamples = textscan(waveData.summary{iMatch}, 'Wave - Number of samples              %f');
        
        iMatch = ~cellfun(@isempty, regexp(waveData.summary, 'Wave - Sampling rate                  [0-9\.] Hz'));
        if any(iMatch)
            samplingRate = textscan(waveData.summary{iMatch}, 'Wave - Sampling rate                  %f Hz');
            avgInterval = nSamples{1}/samplingRate{1};
        end
    end
end
sample_data{2}.meta.instrument_average_interval = avgInterval;
if isempty(avgInterval), avgInterval = '?'; end

magExt = '_MAG';
magBiasComment = '';
magDec = 0;
if waveData.isMagBias
    magExt = '';
    magBiasComment = waveData.magBiasComment;
    magDec = waveData.magDec;
end

% add dimensions with their data mapped
dims = {
    'TIME',             waveData.Time,            ['Time stamp corresponds to the start of the measurement which lasts ' num2str(avgInterval) ' seconds.']; ...
    'FREQUENCY_1',      waveData.pwrFrequency,    ''; ...
    'FREQUENCY_2',      waveData.dirFrequency,    ''; ...
    ['DIR' magExt],     waveData.Direction,       magBiasComment
    };

nDims = size(dims, 1);
sample_data{2}.dimensions = cell(nDims, 1);
for i=1:nDims
    sample_data{2}.dimensions{i}.name         = dims{i, 1};
    sample_data{2}.dimensions{i}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(dims{i, 1}, 'type')));
    sample_data{2}.dimensions{i}.data         = sample_data{2}.dimensions{i}.typeCastFunc(dims{i, 2});
    sample_data{2}.dimensions{i}.comment      = dims{i, 3};
end
clear dims;

% add information about the middle of the measurement period
sample_data{2}.dimensions{1}.seconds_to_middle_of_measurement = sample_data{2}.meta.instrument_average_interval/2;

% add variables with their dimensions and data mapped
if isfield(waveData, 'SpectraType')
    vars = {
        'TIMESERIES',         [],      1; ...
        'LATITUDE',           [],      NaN; ...
        'LONGITUDE',          [],      NaN; ...
        'NOMINAL_DEPTH',      [],      NaN; ...
        'VDEN',               [1 2],   waveData.pwrSpectrum; ...
        ['SSWD' magExt],      [1 3],   waveData.dirSpectrum; ...
        'WSSH',               1,       waveData.SignificantHeight; ...      % Significant height (Hm0) (m). This is the classic estimate sometimes referred to as Hs. It is calculated from the energy spectrum, Hmo = 4sqrt(sum(M0)).
        'WHTH',               1,       waveData.MeanOneThirdHeight; ...     % Mean 1/3 height (H3) (m). This is the mean of the 1/3 largest waves in a record. It is a time series based estimate. Typically this value is 5% larger than Hmo, yet variations can be greater or smaller. Note: AST only.
        'WHTE',               1,       waveData.MeanOneTenthHeight; ...     % Mean 1/10 height (H10) (m). This is the mean of the 1/10 largest waves in a record. It is a time series based estimate when AST is available. When AST is not available, then this estimate may simply be presented as a linear extrapolation of Hmo, whereby H10 = 1.27Hm0. Note: AST only.
        'WMXH',               1,       waveData.MaximumHeight; ...          % Maximum height (Hmax) (m). This is the largest wave in a record. It is a time series based estimate when AST is available. When AST is not available, then this estimate may simply be presented as a linear extrapolation of Hmo, whereby Hmax = 1.67Hm0. Note: AST only.
        'WMSH',               1,       waveData.MeanHeight; ...             % Mean height (Hmean) (m). This is the mean value of all waves in a record. It is a time series based estimate when AST is available. When AST is not available, then this estimate is marked as an invalid value and not displayed.
        'WPSM',               1,       waveData.MeanPeriod; ...             % Mean period (Tm02) (s). This is the average period for all the waves in the burst and it is calculated from the energy spectrum according to the first and second moment of the energy spectrum: Tm02 = sqrt(M0/M02) The value is reported in seconds.
        'WPMH',               1,       waveData.MeanZeroCrossingPeriod; ... % Mean zerocrossing period (Tz) (s). This is the mean period calculated from the zero-crossing technique. It is calculated as the mean of all the periods in the wave burst. The value is reported in seconds.
        'WPTH',               1,       waveData.MeanOneThirdPeriod; ...     % Mean 1/3 Period (T3) (s). This is the mean period associated with the 1/3 largest waves (H3) in a record, where the period is calculated from the zero-crossing technique. The value is reported in seconds.
        'WPTE',               1,       waveData.MeanOneTenthPeriod; ...     % Mean 1/10 Period (T10) (s). This is the mean period associated with the 1/10 largest waves (H10) in a record, where the period is calculated from the zero-crossing technique. The value is reported in seconds.
        'WMPP',               1,       waveData.MaximumPeriod; ...          % Maximum Period (Tmax) (s). This is the mean period associated with the largest wave (Hmax) in a record, where the period is calculated from the zero-crossing technique. The value is reported in seconds.
        'WPPE',               1,       waveData.PeakPeriod; ...             % Peak period (Tp) (s). This is the period of the waves corresponding to the peak frequency for the wave spectrum. The value is reported in seconds.
        ['WPDI' magExt],      1,       waveData.PeakDirection; ...          % Peak direction (DirTp) (deg). This is the direction of the wave corresponding to the peak period. The direction is reported as “from” and is reported in degrees.
        ['SSDS' magExt],      1,       waveData.DirectionalSpread; ...      % Directional spread (SprTp) (deg). The directional spread is a measure of the directional variance. The estimate is calculated for the peak frequency. The value is reported in degrees.
        ['VDIR' magExt],      1,       waveData.MeanDirection; ...          % Mean direction (Mdir) (deg). This value is a weighted average of all the directions in the wave spectrum. It is weighted according to the energy at each frequency. The direction is reported as “from” and is reported in degrees.
        'TEMP',               1,       waveData.Temperature; ...
        'PRES_REL',           1,       waveData.MeanPressure; ...           % Mean Pressure (dbar).
        'VOLT',               1,       waveData.Battery; ...
        ['HEADING' magExt],   1,       waveData.Heading; ...
        'PITCH',              1,       waveData.Pitch; ...
        'ROLL',               1,       waveData.Roll; ...
        ['SSWV' magExt],      [1 3 4], waveData.fullSpectrum; ...
        'SPCT',               1,       waveData.SpectraType                 % Spectrum type (0-Pressure, 1-Velocity, 3-AST).
        };
else
    vars = {
        'TIMESERIES',         [],      1; ...
        'LATITUDE',           [],      NaN; ...
        'LONGITUDE',          [],      NaN; ...
        'NOMINAL_DEPTH',      [],      NaN; ...
        'VDEN',               [1 2],   waveData.pwrSpectrum; ...
        ['SSWD' magExt],      [1 3],   waveData.dirSpectrum; ...
        'WSSH',               1,       waveData.SignificantHeight; ...      % Significant height (Hm0) (m). This is the classic estimate sometimes referred to as Hs. It is calculated from the energy spectrum, Hmo = 4sqrt(sum(M0)).
        'WPMH',               1,       waveData.MeanZeroCrossingPeriod; ... % Mean zerocrossing period (Tz) (s). This is the mean period calculated from the zero-crossing technique. It is calculated as the mean of all the periods in the wave burst. The value is reported in seconds.
        'WPPE',               1,       waveData.PeakPeriod; ...             % Peak period (Tp) (s). This is the period of the waves corresponding to the peak frequency for the wave spectrum. The value is reported in seconds.
        ['WPDI' magExt],      1,       waveData.PeakDirection; ...          % Peak direction (DirTp) (deg). This is the direction of the wave corresponding to the peak period. The direction is reported as “from” and is reported in degrees.
        ['SSDS' magExt],      1,       waveData.DirectionalSpread; ...      % Directional spread (SprTp) (deg). The directional spread is a measure of the directional variance. The estimate is calculated for the peak frequency. The value is reported in degrees.
        ['VDIR' magExt],      1,       waveData.MeanDirection; ...          % Mean direction (Mdir) (deg). This value is a weighted average of all the directions in the wave spectrum. It is weighted according to the energy at each frequency. The direction is reported as “from” and is reported in degrees.
        'TEMP',               1,       waveData.Temperature; ...
        'PRES_REL',           1,       waveData.MeanPressure; ...           % Mean Pressure (dbar).
        'VOLT',               1,       waveData.Battery; ...
        ['HEADING' magExt],   1,       waveData.Heading; ...
        'PITCH',              1,       waveData.Pitch; ...
        'ROLL',               1,       waveData.Roll; ...
        ['SSWV' magExt],      [1 3 4], waveData.fullSpectrum
        };
end
clear waveData;

nVars = size(vars, 1);
sample_data{2}.variables = cell(nVars, 1);
for i=1:nVars
    sample_data{2}.variables{i}.name         = vars{i, 1};
    sample_data{2}.variables{i}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(vars{i, 1}, 'type')));
    sample_data{2}.variables{i}.dimensions   = vars{i, 2};
    if ~isempty(vars{i, 2}) % we don't want this for scalar variables
        if any(strcmpi(vars{i, 1}, {'VDEN', 'SSWD_MAG', 'WSSH', 'WHTH', 'WHTE', ...
                'WMXH', 'WMSH', 'WPSM', 'WPMH', 'WPTH', 'WPTE', 'WMPP', 'WPPE', ...
                'WPDI_MAG', 'SSDS_MAG', 'VDIR_MAG', 'SSWV_MAG'}))
            sample_data{2}.variables{i}.coordinates = 'TIME LATITUDE LONGITUDE'; % data at the surface, can be inferred from standard/long names
        else
            sample_data{2}.variables{i}.coordinates = 'TIME LATITUDE LONGITUDE NOMINAL_DEPTH';
        end
    end
    sample_data{2}.variables{i}.data         = sample_data{2}.variables{i}.typeCastFunc(vars{i, 3});

    if any(strcmpi(vars{i, 1}, {'SSWD', 'WPDI', 'SSDS', 'VDIR', 'HEADING', 'SSWV'}))
        sample_data.variables{i}.compass_correction_applied = magDec;
        sample_data.variables{i}.comment = magBiasComment;
    end
end
clear vars;

end

