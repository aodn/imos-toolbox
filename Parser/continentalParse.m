 function sample_data = continentalParse( filename, tMode )
%CONTINENTALPARSE Parses ADCP data from a raw Nortek Continental binary
% (.cpr) file.
%
% Parses a raw binary file from a Nortek Continental ADCP.
%
% Inputs:
%   filename    - Cell array containing the name of the raw continental file 
%                 to parse.
%   tMode       - Toolbox data type mode ('profile' or 'timeSeries').
% 
% Outputs:
%   sample_data - Struct containing sample data.
%
% Author: 		Paul McCarthy <paul.mccarthy@csiro.au>
% Contributor: 	Guillaume Galibert <guillaume.galibert@utas.edu.au>
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
narginchk(1,2);

if ~iscellstr(filename), error('filename must be a cell array of strings'); end

% only one file supported
filename = filename{1};

% read in all of the structures in the raw file
structures = readParadoppBinary(filename);

% first three sections are header, head and user configuration
hardware = structures.Id5;
head     = structures.Id4;
user     = structures.Id0;

% the rest of the sections are continental data (which have 
% the same structure as awac velocity profile data sections).

nsamples = length(structures.Id36.Sync);
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
% calculate distance values from metadata. Conversion of the BinLength 
% and T2 (blanking distance) values from counts to meaningful values 
% is a little strange. The relationship between frequency and the 
% 'factor', as i've termed it, is approximately:
%
% factor = 47.8 / frequency
%
% However this is not exactly correct for all frequencies, so i'm 
% just using a lookup table as recommended in this forum post:
% 
% http://www.nortek-as.com/en/knowledge-center/forum/hr-profilers/736804717
%
% Calculation of blanking distance always uses the constant value 0.0229
% (except for HR profilers - also explained in the forum post).
%
freq       = head.Frequency; % this is in KHz
blankDist  = user.T2;        % counts
cellSize   = user.BinLength; % counts
factor     = 0;              % used for conversion

switch freq
  case 190, factor = 0.2221;
  case 470, factor = 0.0945;
end

cellSize  = (cellSize / 256) * factor * cos(25 * pi / 180);
blankDist = blankDist        * 0.0229 * cos(25 * pi / 180) - cellSize;

% generate distance values
distance(:) = (blankDist):  ...
           (cellSize): ...
           (blankDist + (ncells-1) * cellSize);

% Note this is actually the distance between the ADCP's transducers and the
% middle of each cell along the beams axis (no tilt correction applied)
% See http://www.nortek-bv.nl/en/knowledge-center/forum/current-profilers-and-current-meters/579860330
distance = distance + cellSize;

% retrieve sample data
time            = structures.Id36.Time';
analn1          = structures.Id36.Analn1';
battery         = structures.Id36.Battery';
analn2          = structures.Id36.Analn2';
heading         = structures.Id36.Heading';
pitch           = structures.Id36.Pitch';
roll            = structures.Id36.Roll';
status          = structures.Id36.Status';
pressure        = structures.Id36.PressureMSB'*65536 + structures.Id36.PressureLSW';
temperature     = structures.Id36.Temperature';
velocity1       = structures.Id36.Vel1';
velocity2       = structures.Id36.Vel2';
velocity3       = structures.Id36.Vel3';
backscatter1    = structures.Id36.Amp1';
backscatter2    = structures.Id36.Amp2';
backscatter3    = structures.Id36.Amp3';

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
sample_data.meta.instrument_model           = 'Continental';
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
    dims(end-1, :) = {'HEIGHT_ABOVE_SENSOR', height, 'Data has been vertically bin-mapped using Nortek Storm software ''Remove tilt effects'' procedure. Cells have consistant heights above sensor in time.'};
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
