function sample_data = aquadoppProfilerParse( filename, tMode )
%AQUADOPPPROFILERPARSE Parses ADCP data from a raw Nortek Aquadopp Profiler 
% binary (.prf) file.
%
% Does not yet support HR Aquadopp profilers.
%
% Inputs:
%   filename    - Cell array containing the name of the raw aquadopp profiler 
%                 file to parse.
%   tMode       - Toolbox data type mode.
% 
% Outputs:
%   sample_data - Struct containing sample data.
%
% Author: 		Paul McCarthy <paul.mccarthy@csiro.au>
% Contributor: 	Guillaume Galibert <guillaume.galibert@utas.edu.au>
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

% the rest of the sections are aquadopp profiler velocity data 
if isfield(structures, 'Id42')
    % this is a HR profiler velocity data
    profilerType = 'Id42';
	if ~strfind(hardware.instrumentType,'HR')
        fprintf('%s\n', ['Warning : ' filename ' HR PROFILER instrumentType does not match Id42 sector type data']);
	end
else
    % this is a plain profiler velocity data
    profilerType = 'Id33';
	if strfind(hardware.instrumentType,'HR')
        fprintf('%s\n', ['Warning : ' filename ' AQUADOPP PROFILER instrumentType does not match Id33 sector type data']);
	end
	
end

% still to be implemented
value = bin2dec(num2str(bitget(user.TimCtrlReg, 7:-1:6)));
switch value
    case 0
        user.TimCtrlReg_PowerLevel_ = 'HIGH';
    case 1
        user.TimCtrlReg_PowerLevel_ = 'HIGH-';
    case 2
        user.TimCtrlReg_PowerLevel_ = 'LOW+';
    case 3
        user.TimCtrlReg_PowerLevel_ = 'LOW';
end

velocityProcessed = false;
if isfield(structures, 'Id106')
    % velocity has been processed
    velocityProcessed = true;
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
ncells     = user.NBins;
factor     = 0;              % used for conversion

switch freq
  case 400,  factor = 0.1195;
  case 600,  factor = 0.0797;
  case 1000, factor = 0.0478;
  case 2000, factor = 0.0239;
end

cellSize   = (cellSize / 256) * factor * cos(25 * pi / 180);
blankDist  = blankDist        * 0.0229 * cos(25 * pi / 180) - cellSize;

% generate distance values
distance = (blankDist:  ...
           cellSize: ...
           blankDist + (ncells-1) * cellSize)';

% 
velocityScaling = 1;
if bitget(user(1).Mode, 5) == 1
    velocityScaling = 0.1;
end
if strfind(hardware(1).instrumentType, 'HR_PROFILER')
	sampleRate = double(512 / user(1).T5);
end

% Note this is actually the distance between the ADCP's transducers and the
% middle of each cell
% See http://www.nortek-bv.nl/en/knowledge-center/forum/current-profilers-and-current-meters/579860330
distance = distance + cellSize;
       
% retrieve sample data
time            = [structures.(profilerType)(:).Time]';
analn1          = [structures.(profilerType)(:).Analn1]';
battery         = [structures.(profilerType)(:).Battery]';
analn2          = [structures.(profilerType)(:).Analn2]';
heading         = [structures.(profilerType)(:).Heading]';
pitch           = [structures.(profilerType)(:).Pitch]';
roll            = [structures.(profilerType)(:).Roll]';
status          = [structures.(profilerType)(:).Status]';
pressure        = [structures.(profilerType)(:).PressureMSB]'*65536 + [structures.(profilerType)(:).PressureLSW]';
temperature     = [structures.(profilerType)(:).Temperature]';
velocity1       = [structures.(profilerType)(:).Vel1]';
velocity2       = [structures.(profilerType)(:).Vel2]';
velocity3       = [structures.(profilerType)(:).Vel3]';
backscatter1    = [structures.(profilerType)(:).Amp1]';
backscatter2    = [structures.(profilerType)(:).Amp2]';
backscatter3    = [structures.(profilerType)(:).Amp3]';

if velocityProcessed
    % velocity has been processed
    timeProc = [structures.Id106(:).Time]';
    iCommonTime = ismember(time, timeProc); % timeProc can be shorter than time
    
    velocity1Proc(iCommonTime, :)    = [structures.Id106(:).Vel1]'; % tilt effect corrected velocity
    velocity2Proc(iCommonTime, :)    = [structures.Id106(:).Vel2]';
    velocity3Proc(iCommonTime, :)    = [structures.Id106(:).Vel3]';
    sig2noise1(iCommonTime, :)       = [structures.Id106(:).Snr1]';
    sig2noise2(iCommonTime, :)       = [structures.Id106(:).Snr2]';
    sig2noise3(iCommonTime, :)       = [structures.Id106(:).Snr3]';
    stdDev1(iCommonTime, :)          = [structures.Id106(:).Std1]'; % currently not used
    stdDev2(iCommonTime, :)          = [structures.Id106(:).Std2]';
    stdDev3(iCommonTime, :)          = [structures.Id106(:).Std3]';
    errorCode1(iCommonTime, :)       = [structures.Id106(:).Erc1]'; % error codes for each cell in one beam, values between 0 and 4.
    errorCode2(iCommonTime, :)       = [structures.Id106(:).Erc2]';
    errorCode3(iCommonTime, :)       = [structures.Id106(:).Erc3]';
    speed(iCommonTime, :)            = [structures.Id106(:).speed]';
    direction(iCommonTime, :)        = [structures.Id106(:).direction]';
    verticalDist(iCommonTime, :)     = [structures.Id106(:).verticalDistance]'; % ? no idea what this is, always same values between 6000 and 65534 for each profile.
    profileErrorCode(iCommonTime, :) = [structures.Id106(:).profileErrorCode]'; % error codes for each cell of a velocity profile inferred from the 3 beams. 0=good; otherwise error. See http://www.nortek-as.com/en/knowledge-center/forum/waves/20001875?b_start=0#769595815
    qcFlag(iCommonTime, :)           = [structures.Id106(:).qcFlag]'; % QUARTOD QC result. 0=not eval; 1=bad; 2=questionable; 3=good.
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
velocity1    = velocity1 * velocityScaling / 1000.0;
velocity2    = velocity2 * velocityScaling / 1000.0;
velocity3    = velocity3 * velocityScaling / 1000.0;

if velocityProcessed
    % velocity has been processed
    % velocities  / 1000.0 (mm/s     -> m/s) assuming earth coordinates
    % 20*log10(sig2noise)  (counts   -> dB)
    % direction   / 100.0  (0.01 deg  -> deg)
    velocity1     = velocity1Proc * velocityScaling / 1000.0; % we update the velocity
    velocity2     = velocity2Proc * velocityScaling / 1000.0;
    velocity3     = velocity3Proc * velocityScaling / 1000.0;
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

if strfind(hardware.instrumentType, 'HR')
    instrument_model = 'HR Aquadopp Profiler';
else
    instrument_model = 'Aquadopp Profiler';
end

sample_data = struct;

sample_data.toolbox_input_file              = filename;
sample_data.meta.featureType                = ''; % strictly this dataset cannot be described as timeSeriesProfile since it also includes timeSeries data like TEMP
sample_data.meta.head                       = head;
sample_data.meta.hardware                   = hardware;
sample_data.meta.user                       = user;
sample_data.meta.binSize                    = cellSize;
sample_data.meta.instrument_make            = 'Nortek';
sample_data.meta.instrument_model           = instrument_model;
sample_data.meta.instrument_serial_no       = hardware.SerialNo;
sample_data.meta.instrument_firmware        = hardware.FWversion;
sample_data.meta.instrument_sample_interval = median(diff(time*24*3600));
sample_data.meta.instrument_average_interval= user.AvgInterval;
sample_data.meta.beam_angle                 = 25;   % http://www.hydro-international.com/files/productsurvey_v_pdfdocument_19.pdf
sample_data.meta.beam_to_xyz_transform      = head.TransformationMatrix;

% add dimensions with their data mapped
adcpOrientations = single(bitget(status, 1, 'uint8'));
adcpOrientation = mode(adcpOrientations); % hopefully the most frequent value reflects the orientation when deployed
height = distance;
if adcpOrientation == 1
    % case of a downward looking ADCP -> negative values
    height = -height;
    distance = -distance;
end
iBadOriented = adcpOrientations ~= adcpOrientation; % we'll only keep velocity data collected when ADCP is oriented as expected
velocity2(iBadOriented, :) = NaN;
velocity1(iBadOriented, :) = NaN;
velocity3(iBadOriented, :) = NaN;
backscatter1(iBadOriented, :) = NaN;
backscatter2(iBadOriented, :) = NaN;
backscatter3(iBadOriented, :) = NaN;
if velocityProcessed
    sig2noise1(iBadOriented, :) = NaN;
    sig2noise2(iBadOriented, :) = NaN;
    sig2noise3(iBadOriented, :) = NaN;
    stdDev1(iBadOriented, :) = NaN;
    stdDev2(iBadOriented, :) = NaN;
    stdDev3(iBadOriented, :) = NaN;
    errorCode1(iBadOriented, :) = NaN;
    errorCode2(iBadOriented, :) = NaN;
    errorCode3(iBadOriented, :) = NaN;
    speed(iBadOriented, :) = NaN;
    direction(iBadOriented, :) = NaN;
    verticalDist(iBadOriented, :) = NaN;
    profileErrorCode(iBadOriented, :) = NaN;
    qcFlag(iBadOriented, :) = NaN;
end
dims = {
    'TIME',             time,    ['Time stamp corresponds to the start of the measurement which lasts ' num2str(user.AvgInterval) ' seconds.']; ...
    'DIST_ALONG_BEAMS', distance, 'Nortek instrument data is not vertically bin-mapped (no tilt correction applied). Cells are lying parallel to the beams, at heights above sensor that vary with tilt.'
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
    'TIMESERIES',       [],             1;...
    'LATITUDE',         [],             NaN; ...
    'LONGITUDE',        [],             NaN; ...
    'NOMINAL_DEPTH',    [],             NaN; ...
    'VCUR_MAG',         [1 iDimVel],    velocity2; ... % V
    'UCUR_MAG',         [1 iDimVel],    velocity1; ... % U
    'WCUR',             [1 iDimVel],    velocity3; ...
    'ABSIC1',           [1 iDimDiag],   backscatter1; ...
    'ABSIC2',           [1 iDimDiag],   backscatter2; ...
    'ABSIC3',           [1 iDimDiag],   backscatter3; ...
    'TEMP',             1,              temperature; ...
    'PRES_REL',         1,              pressure; ...
    'VOLT',             1,              battery; ...
    'PITCH',            1,              pitch; ...
    'ROLL',             1,              roll; ...
    'HEADING_MAG',      1,              heading
    };
clear analn1 analn2 time distance velocity1 velocity2 velocity3 ...
    backscatter1 backscatter2 backscatter3 ...
    temperature pressure battery pitch roll heading status;

if velocityProcessed
    % velocity has been processed
    vars = [vars; {
        'SNR1',                [1 iDimDiag], sig2noise1; ...
        'SNR2',                [1 iDimDiag], sig2noise2; ...
        'SNR3',                [1 iDimDiag], sig2noise3; ...
%         'STDB1',               [1 iDimDiag], stdDev1; ... % currently not used
%         'STDB2',               [1 iDimDiag], stdDev2; ...
%         'STDB3',               [1 iDimDiag], stdDev3; ...
        'NORTEK_ERR1',         [1 iDimDiag], errorCode1; ...
        'NORTEK_ERR2',         [1 iDimDiag], errorCode2; ...
        'NORTEK_ERR3',         [1 iDimDiag], errorCode3; ...
        'CSPD',                [1 iDimVel],  speed; ...
        'CDIR_MAG',            [1 iDimVel],  direction; ...
%         'VERT_DIST',           [1 iDimVel],  verticalDist; ... % don't know what this is
        'NORTEK_PROFILE_ERR',  [1 iDimVel],  profileErrorCode; ...
        'NORTEK_QC',           [1 iDimVel],  qcFlag
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
