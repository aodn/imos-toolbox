function sample_data = awacParse( filename, tMode )
%AWACPARSE Parses ADCP data from a raw Nortek AWAC binary (.wpr) file. If
% processed wave data files (.whd and .wap) are present, these are also 
% parsed.
%
% Parses a raw binary file from a Nortek AWAC ADCP. If processed wave data
% files (.whd and .wap) are present, these are also parsed, to provide wave
% data. Wave data is not read from the raw binary files, as the raw binary
% only contains raw wave data. The Nortek software performs a significant
% amount of processing on this raw wave data to provide standared wave
% metrics such as significant wave height, period, etc.
%
% If wave data is present, it is returned as a separate sample_data struct, 
% due to the fact that the timestamps for wave data are significantly 
% different from the profile and sensor data.
%
% Inputs:
%   filename    - Cell array containing the name of the raw AWAC file 
%                 to parse.
%   tMode       - Toolbox data type mode.
% 
% Outputs:
%   sample_data - Struct containing sample data; If wave data is present, 
%                 this will be a cell array of two structs.
%
% Author: 		Paul McCarthy <paul.mccarthy@csiro.au>
% Contributor: 	Guillaume Galibert <guillaume.galibert@utas.edu.au>
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
narginchk(1, 2);

if ~iscellstr(filename), error('filename must be a cell array of strings'); end

% only one file supported
filename = filename{1};

% read in all of the structures in the raw file
structures = readParadoppBinary(filename);

% first three sections are header, head and user configuration
hardware = structures.Id5;
head     = structures.Id4;
user     = structures.Id0;

% the rest of the sections are awac data
nsamples = length(structures.Id32);
ncells   = user.NBins;

% preallocate memory for all sample data
time         = nan(nsamples, 1);
distance     = nan(ncells,   1);
analn1       = nan(nsamples, 1);
battery      = nan(nsamples, 1);
analn2       = nan(nsamples, 1);
heading      = nan(nsamples, 1);
pitch        = nan(nsamples, 1);
roll         = nan(nsamples, 1);
status       = zeros(nsamples, 8, 'uint8');
pressure     = nan(nsamples, 1);
temperature  = nan(nsamples, 1);
velocity1    = nan(nsamples, ncells);
velocity2    = nan(nsamples, ncells);
velocity3    = nan(nsamples, ncells);
backscatter1 = nan(nsamples, ncells);
backscatter2 = nan(nsamples, ncells);
backscatter3 = nan(nsamples, ncells);

velocityProcessed = false;
if isfield(structures, 'Id106')
    % velocity has been processed
    velocityProcessed = true;
    nsamplesProc = length(structures.Id106.Sync);
    timeProc         = nan(nsamplesProc, 1);
    velocity1Proc    = nan(nsamples, ncells);
    velocity2Proc    = nan(nsamples, ncells);
    velocity3Proc    = nan(nsamples, ncells);
    sig2noise1       = nan(nsamples, ncells);
    sig2noise2       = nan(nsamples, ncells);
    sig2noise3       = nan(nsamples, ncells);
    stdDev1          = nan(nsamples, ncells);
    stdDev2          = nan(nsamples, ncells);
    stdDev3          = nan(nsamples, ncells);
    errorCode1       = nan(nsamples, ncells);
    errorCode2       = nan(nsamples, ncells);
    errorCode3       = nan(nsamples, ncells);
    speed            = nan(nsamples, ncells);
    direction        = nan(nsamples, ncells);
    verticalDist     = nan(nsamples, ncells);
    profileErrorCode = nan(nsamples, ncells);
    qcFlag           = nan(nsamples, ncells);
end

%
% calculate distance values from metadata. See continentalParse.m 
% inline comments for a brief discussion of this process
%
% http://www.nortek-as.com/en/knowledge-center/forum/hr-profilers/736804717
%
freq       = head.Frequency; % this is in KHz
blankDist  = user.T2;        % counts
cellSize   = user.BinLength; % counts
factor     = 0;              % used in conversion

switch freq
  case 600,  factor = 0.0797;
  case 1000, factor = 0.0478;
end

cellSize  = (cellSize / 256) * factor * cos(25 * pi / 180);
blankDist = blankDist        * 0.0229 * cos(25 * pi / 180) - cellSize;

distance(:) = (blankDist):  ...
           (cellSize): ...
           (blankDist + (ncells-1) * cellSize);
       
% Note this is actually the distance between the ADCP's transducers and the
% middle of each cell
% See http://www.nortek-bv.nl/en/knowledge-center/forum/current-profilers-and-current-meters/579860330
distance = distance + cellSize;

% retrieve sample data
time            = structures.Id32.Time';
analn1          = structures.Id32.Analn1';
battery         = structures.Id32.Battery';
analn2          = structures.Id32.Analn2';
heading         = structures.Id32.Heading';
pitch           = structures.Id32.Pitch';
roll            = structures.Id32.Roll';
status          = structures.Id32.Status';
pressure        = structures.Id32.PressureMSB'*65536 + structures.Id32.PressureLSW';
temperature     = structures.Id32.Temperature';
velocity1       = structures.Id32.Vel1';
velocity2       = structures.Id32.Vel2';
velocity3       = structures.Id32.Vel3';
backscatter1    = structures.Id32.Amp1';
backscatter2    = structures.Id32.Amp2';
backscatter3    = structures.Id32.Amp3';

if velocityProcessed
    % velocity has been processed
    timeProc = structures.Id106.Time';
    iCommonTime = ismember(time, timeProc); % timeProc can be shorter than time
    
    velocity1Proc(iCommonTime, :)    = structures.Id106.Vel1'; % tilt effect corrected velocity
    velocity2Proc(iCommonTime, :)    = structures.Id106.Vel2';
    velocity3Proc(iCommonTime, :)    = structures.Id106.Vel3';
    sig2noise1(iCommonTime, :)       = structures.Id106.Snr1';
    sig2noise2(iCommonTime, :)       = structures.Id106.Snr2';
    sig2noise3(iCommonTime, :)       = structures.Id106.Snr3';
    stdDev1(iCommonTime, :)          = structures.Id106.Std1'; % currently not used
    stdDev2(iCommonTime, :)          = structures.Id106.Std2';
    stdDev3(iCommonTime, :)          = structures.Id106.Std3';
    errorCode1(iCommonTime, :)       = structures.Id106.Erc1'; % error codes for each cell in one beam, values between 0 and 4.
    errorCode2(iCommonTime, :)       = structures.Id106.Erc2';
    errorCode3(iCommonTime, :)       = structures.Id106.Erc3';
    speed(iCommonTime, :)            = structures.Id106.speed';
    direction(iCommonTime, :)        = structures.Id106.direction';
    verticalDist(iCommonTime, :)     = structures.Id106.verticalDistance'; % ? no idea what this is, always same values between 6000 and 65534 for each profile.
    profileErrorCode(iCommonTime, :) = structures.Id106.profileErrorCode'; % error codes for each cell of a velocity profile inferred from the 3 beams. 0=good; otherwise error. See http://www.nortek-as.com/en/knowledge-center/forum/waves/20001875?b_start=0#769595815
    qcFlag(iCommonTime, :)           = structures.Id106.qcFlag'; % QUARTOD QC result. 0=not eval; 1=bad; 2=questionable; 3=good.
end
clear structures;

% battery     / 10.0   (0.1 V    -> V)
% heading     / 10.0   (0.1 deg  -> deg)
% pitch       / 10.0   (0.1 deg  -> deg)
% roll        / 10.0   (0.1 deg  -> deg)
% pressure    / 1000.0 (mm       -> m)   assuming equivalence to dbar
% temperature / 100.0  (0.01 deg -> deg)
% velocities  / 1000.0 (mm/s     -> m/s) assuming earth coordinates
battery      = battery      / 10.0;
heading      = heading      / 10.0;
pitch        = pitch        / 10.0;
roll         = roll         / 10.0;
pressure     = pressure     / 1000.0;
temperature  = temperature  / 100.0;
velocity1    = velocity1    / 1000.0;
velocity2    = velocity2    / 1000.0;
velocity3    = velocity3    / 1000.0;

if velocityProcessed
    % velocity has been processed
    % velocities  / 1000.0 (mm/s     -> m/s) assuming earth coordinates
    % 20*log10(sig2noise)  (counts   -> dB)
    % direction   / 100.0  (0.01 deg  -> deg)
    velocity1     = velocity1Proc / 1000.0; % we update the velocity
    velocity2     = velocity2Proc / 1000.0;
    velocity3     = velocity3Proc / 1000.0;
    sig2noise1(sig2noise1==0) = NaN;
    sig2noise2(sig2noise2==0) = NaN;
    sig2noise3(sig2noise3==0) = NaN;
    sig2noise1    = 20*log10(sig2noise1);
    sig2noise2    = 20*log10(sig2noise2);
    sig2noise3    = 20*log10(sig2noise3);
    stdDev1       = stdDev1 / 1000.0; % same unit as velocity I suppose
    stdDev2       = stdDev2 / 1000.0;
    stdDev3       = stdDev3 / 1000.0;
    speed         = speed / 1000.0; % same unit as velocity I suppose
    direction     = direction / 100.0;
    verticalDist  = verticalDist / 1000.0; % since verticalDist is uint16, max value gives 65m but distance along beams can go up to 170m...???
end

sample_data = struct;
    
sample_data.toolbox_input_file              = filename;
sample_data.meta.featureType                = ''; % strictly this dataset cannot be described as timeSeriesProfile since it also includes timeSeries data like TEMP
sample_data.meta.head                       = head;
sample_data.meta.hardware                   = hardware;
sample_data.meta.user                       = user;
sample_data.meta.binSize                    = cellSize;
sample_data.meta.instrument_make            = 'Nortek';
sample_data.meta.instrument_model           = 'AWAC';
sample_data.meta.instrument_serial_no       = hardware.SerialNo;
sample_data.meta.instrument_sample_interval = median(diff(time*24*3600));
sample_data.meta.instrument_average_interval= user.AvgInterval;
sample_data.meta.instrument_firmware        = hardware.FWversion;
sample_data.meta.beam_angle                 = 25;   % http://www.hydro-international.com/files/productsurvey_v_pdfdocument_19.pdf
sample_data.meta.beam_to_xyz_transform      = head.TransformationMatrix;

% add dimensions with their data mapped
adcpOrientations = bin2dec(status(:, end));
adcpOrientation = mode(adcpOrientations); % hopefully the most frequent value reflects the orientation when deployed
height = distance;
if adcpOrientation == 1
    % case of a downward looking ADCP -> negative values
    height = -height;
    distance = -distance;
end
iWellOriented = adcpOrientations == adcpOrientation; % we'll only keep data collected when ADCP is oriented as expected
dims = {
    'TIME',             time(iWellOriented),    ['Time stamp corresponds to the start of the measurement which lasts ' num2str(user.AvgInterval) ' seconds.']; ...
    'DIST_ALONG_BEAMS', distance,               'Nortek instrument data is not vertically bin-mapped (no tilt correction applied). Cells are lying parallel to the beams, at heights above sensor that vary with tilt.'
    };
clear time distance;

if velocityProcessed
    % we re-arrange dimensions like for RDI ADCPs
    dims(end+1, :) = dims(end, :);
    dims(end-1, :) = {'HEIGHT_ABOVE_SENSOR', height(:), 'Data has been vertically bin-mapped using Nortek Storm software ''Remove tilt effects'' procedure. Cells have consistant heights above sensor in time.'};
end
clear height;

nDims = size(dims, 1);
sample_data.dimensions = cell(nDims, 1);
for i=1:nDims
    sample_data.dimensions{i}.name         = dims{i, 1};
    sample_data.dimensions{i}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(dims{i, 1}, 'type')));
    sample_data.dimensions{i}.data         = sample_data.dimensions{i}.typeCastFunc(dims{i, 2});
    sample_data.dimensions{i}.comment      = dims{i, 3};
end
clear dims;

% add information about the middle of the measurement period
sample_data.dimensions{1}.seconds_to_middle_of_measurement = user.AvgInterval/2;

% add variables with their dimensions and data mapped.
% we assume no correction for magnetic declination has been applied
if velocityProcessed
    % velocity has been processed
    iDimVel = nDims-1;
    iDimDiag = nDims;
else
    iDimVel = nDims;
    iDimDiag = nDims;
end
vars = {
    'TIMESERIES',       [],             1; ...
    'LATITUDE',         [],             NaN; ...
    'LONGITUDE',        [],             NaN; ...
    'NOMINAL_DEPTH',    [],             NaN; ...
    'VCUR_MAG',         [1 iDimVel],    velocity2(iWellOriented, :); ... % V
    'UCUR_MAG',         [1 iDimVel],    velocity1(iWellOriented, :); ... % U
    'WCUR',             [1 iDimVel],    velocity3(iWellOriented, :); ...
    'ABSIC1',           [1 iDimDiag],   backscatter1(iWellOriented, :); ...
    'ABSIC2',           [1 iDimDiag],   backscatter2(iWellOriented, :); ...
    'ABSIC3',           [1 iDimDiag],   backscatter3(iWellOriented, :); ...
    'TEMP',             1,              temperature(iWellOriented); ...
    'PRES_REL',         1,              pressure(iWellOriented); ...
    'VOLT',             1,              battery(iWellOriented); ...
    'PITCH',            1,              pitch(iWellOriented); ...
    'ROLL',             1,              roll(iWellOriented); ...
    'HEADING_MAG',      1,              heading(iWellOriented)
    };
clear analn1 analn2 time distance velocity1 velocity2 velocity3 ...
    backscatter1 backscatter2 backscatter3 ...
    temperature pressure battery pitch roll heading status;

if velocityProcessed
    % velocity has been processed
    vars = [vars; {
        'SNR1',                [1 iDimDiag], sig2noise1(iWellOriented, :); ...
        'SNR2',                [1 iDimDiag], sig2noise2(iWellOriented, :); ...
        'SNR3',                [1 iDimDiag], sig2noise3(iWellOriented, :); ...
%         'STDB1',               [1 iDimDiag], stdDev1(iWellOriented, :); ... % currently not used
%         'STDB2',               [1 iDimDiag], stdDev2(iWellOriented, :); ...
%         'STDB3',               [1 iDimDiag], stdDev3(iWellOriented, :); ...
        'NORTEK_ERR1',         [1 iDimDiag], errorCode1(iWellOriented, :); ...
        'NORTEK_ERR2',         [1 iDimDiag], errorCode2(iWellOriented, :); ...
        'NORTEK_ERR3',         [1 iDimDiag], errorCode3(iWellOriented, :); ...
        'CSPD',                [1 iDimVel],  speed(iWellOriented, :); ...
        'CDIR_MAG',            [1 iDimVel],  direction(iWellOriented, :); ...
%         'VERT_DIST',           [1 iDimVel],  verticalDist(iWellOriented, :); ... % don't know what this is
        'NORTEK_PROFILE_ERR',  [1 iDimVel],  profileErrorCode(iWellOriented, :); ...
        'NORTEK_QC',           [1 iDimVel],  qcFlag(iWellOriented, :)
        }];
    clear sig2noise1 sig2noise2 sig2noise3 stdDev1 stdDev2 stdDev3 ...
        errorCode1 errorCode2 errorCode3 speed direction verticalDist ...
        profileErrorCode qcFlag;
end

nVars = size(vars, 1);
sample_data.variables = cell(nVars, 1);
for i=1:nVars
    sample_data.variables{i}.name         = vars{i, 1};
    sample_data.variables{i}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(vars{i, 1}, 'type')));
    sample_data.variables{i}.dimensions   = vars{i, 2};
    if ~isempty(vars{i, 2}) % we don't want this for scalar variables
        if length(sample_data.variables{i}.dimensions) == 2
            sample_data.variables{i}.coordinates = ['TIME LATITUDE LONGITUDE ' sample_data.dimensions{sample_data.variables{i}.dimensions(2)}.name];
        else
            sample_data.variables{i}.coordinates = 'TIME LATITUDE LONGITUDE NOMINAL_DEPTH';
        end
    end
    sample_data.variables{i}.data         = sample_data.variables{i}.typeCastFunc(vars{i, 3});
end
clear vars;

%
% if wave data files are present, read them in
%
waveData = readAWACWaveAscii(filename);

% no wave data, no problem
if isempty(waveData), return; end

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

% we assume no correction for magnetic declination has been applied

% add dimensions with their data mapped
dims = {
    'TIME',                   waveData.Time,            ['Time stamp corresponds to the start of the measurement which lasts ' num2str(avgInterval) ' seconds.']; ...
    'FREQUENCY_1',            waveData.pwrFrequency,    ''; ...
    'FREQUENCY_2',            waveData.dirFrequency,    ''; ...
    'DIR_MAG',                waveData.Direction,       ''
    };

nDims = size(dims, 1);
sample_data{2}.dimensions = cell(nDims, 1);
for i=1:nDims
    sample_data{2}.dimensions{i}.name         = dims{i, 1};
    sample_data{2}.dimensions{i}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(dims{i, 1}, 'type')));
    sample_data{2}.dimensions{i}.data         = sample_data{2}.dimensions{i}.typeCastFunc(dims{i, 2});
end
clear dims;

% add information about the middle of the measurement period
sample_data{2}.dimensions{1}.seconds_to_middle_of_measurement = sample_data{2}.meta.instrument_average_interval/2;

% add variables with their dimensions and data mapped
vars = {
    'TIMESERIES',   [],      1; ...
    'LATITUDE',     [],      NaN; ...
    'LONGITUDE',    [],      NaN; ...
    'NOMINAL_DEPTH',[],      NaN; ...
    'VDEN',         [1 2],   waveData.pwrSpectrum; ... % sea_surface_wave_variance_spectral_density
    'SSWD_MAG',     [1 3],   waveData.dirSpectrum; ... % sea_surface_wave_direction_spectral_density
    'WSSH',         1,       waveData.SignificantHeight; ... % sea_surface_wave_spectral_significant_height
    'VAVT',         1,       waveData.MeanZeroCrossingPeriod; ... % sea_surface_wave_zero_upcrossing_period
    'VDIR_MAG',     1,       waveData.MeanDirection; ... % sea_surface_wave_from_direction
    'SSDS_MAG',     1,       waveData.DirectionalSpread; ... % sea_surface_wave_directional_spread
    'TEMP',         1,       waveData.Temperature; ...
    'PRES_REL',     1,       waveData.MeanPressure; ...
    'VOLT',         1,       waveData.Battery; ...
    'HEADING_MAG',  1,       waveData.Heading; ...
    'PITCH',        1,       waveData.Pitch; ...
    'ROLL',         1,       waveData.Roll; ...
    'SSWV_MAG',     [1 3 4], waveData.fullSpectrum; ... % sea_surface_wave_magnetic_directional_variance_spectral_density
    'SPCT',         1,       waveData.SpectraType % awac_spectra_calculation_method
    };
clear waveData;

nVars = size(vars, 1);
sample_data{2}.variables = cell(nVars, 1);
for i=1:nVars
    sample_data{2}.variables{i}.name         = vars{i, 1};
    sample_data{2}.variables{i}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(vars{i, 1}, 'type')));
    sample_data{2}.variables{i}.dimensions   = vars{i, 2};
    if ~isempty(vars{i, 2}) && ~strcmpi(vars{i, 1}, 'SPCT') % we don't want this for scalar variables nor SPCT
        if any(strcmpi(vars{i, 1}, {'VDEN', 'SSWD_MAG', 'WSSH', 'VAVT', 'VDIR_MAG', 'SSDS_MAG', 'SSWV_MAG'}))
            sample_data{2}.variables{i}.coordinates = 'TIME LATITUDE LONGITUDE'; % data at the surface, can be inferred from standard/long names
        else
            sample_data{2}.variables{i}.coordinates = 'TIME LATITUDE LONGITUDE NOMINAL_DEPTH';
        end
    end
    sample_data{2}.variables{i}.data         = sample_data{2}.variables{i}.typeCastFunc(vars{i, 3});
end
clear vars;