function sample_data = vectorParse( filename, mode )
%AQUADOPPVELOCITYPARSE Parses ADCP data from a raw Nortek Vector 
% binary (.vec) file.
%
% Inputs:
%   filename    - Cell array containing the name of the raw aquadopp velocity 
%                 file to parse.
%   mode        - Toolbox data type mode.
% 
% Outputs:
%   sample_data - Struct containing sample data.
%
% Contributor: 	Guillaume Galibert <guillaume.galibert@utas.edu.au>
%               Simon Spagnol <s.spagnol@aims.gov.au>
%
% Based on aquadoppVelocityParse.m

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

if user.CoordSystem ~= 0
    error('Can only handle ENU coordinate system');
end

user.sampleRate = 512 / user.AvgInterval;
isBurstSampling = user.B1_2 > 0;
if isBurstSampling
	samplesPerBurst_ = user.B1_2;
	burstInterval_ = user.MeasInterval;
else
	measurementInterval_ = 'continuous';
end

% self.lag1 = struct.unpack( 'H', spareWords3[ 16:18 ] )[ 0 ]
% self.lag2 = struct.unpack( 'H', spareWords3[ 18:20 ] )[ 0 ]
% if instrumentType is 'Vector':
% 				self.lag1 = self.lag1 / 480000.
% 				self.lag2 = self.lag2 / 480000.

velocityScaling = 1;
if bitget(user(1).Mode, 5) == 1
    velocityScaling = 0.1;
end

%
% calculate distance values from metadata. See continentalParse.m 
% inline comments for a brief discussion of this process
%
% http://www.nortek-as.com/en/knowledge-center/forum/hr-profilers/736804717
%
freq       = head.Frequency; % this is in KHz
cellStart  = user.T2;        % counts
cellLength = user.BinLength; % counts
ncells     = user.NBins;
factor     = 0;              % used for conversion

switch freq
  case 2000, factor = 0.0239;
end

cellLength = (cellLength / 256) * factor * cos(25 * pi / 180);
cellStart  =  cellStart         * 0.0229 * cos(25 * pi / 180) - cellLength;

% generate distance values
distance = (cellStart:  ...
           cellLength: ...
           cellStart + (ncells-1) * cellLength)';

% Note this is actually the distance between the ADCP's transducers and the
% middle of each cell
% See http://www.nortek-bv.nl/en/knowledge-center/forum/current-profilers-and-current-meters/579860330
% in the case of a current meter, this is a horizontal distance from the
% transducer.
distance = distance + cellLength;

%% create velocity data structure
% retrieve sample data
ensemblecount = [structures.Id16(:).Count]';
analn1        = [structures.Id16(:).Analn1]';
analn2LSB     = [structures.Id16(:).Analn2LSB]';
analn2MSB     = [structures.Id16(:).Analn2MSB]';
pressure      = [structures.Id16(:).PressureMSB]'*65536 + [structures.Id16(:).PressureLSW]';
velocity1     = [structures.Id16(:).VelB1]';
velocity2     = [structures.Id16(:).VelB2]';
velocity3     = [structures.Id16(:).VelB3]';
backscatter1  = [structures.Id16(:).AmpB1]';
backscatter2  = [structures.Id16(:).AmpB2]';
backscatter3  = [structures.Id16(:).AmpB3]';
correlation1  = [structures.Id16(:).CorrB1]';
correlation2  = [structures.Id16(:).CorrB2]';
correlation3  = [structures.Id16(:).CorrB3]';

% http://www.nortek-as.com/en/knowledge-center/forum/velocimeters/30181049#63704243
% How do you figure out the time to assign to Vector velocity samples?
% When you convert Vector data to ASCII, time is output in the .SEN files 
% (which record data at 1 Hz), but not in the .DAT files (which record 
% "rapid" sensors, including velocity). Here is how to figure out the 
% velocity time.
% 1) When the Vector starts a burst of data, it requires one second to wake 
% up. As it wakes up, it collects data from the first second without 
% transmitting sound. This result is output in the .VHD file, and you can 
% use it to find the Vector's acoustic noise level.
% 2) The first sample in the .SEN file corresponds to the second second of 
% the burst. During the second second, no velocity data is collected.
% 3) The first velocity data corresponds to the beginning of the second .SEN sample.
% Here is an example to illustrate:
%   If you tell the Vector to start at 12:00:00, the first velocity sample 
%   begins at 12:00:02.0. So, if you are sampling at 16 Hz, the first 
%       velocity sample is complete at 12:00:02.0625. If you are sampling 
%       at 2 Hz, then the first velocity sample is complete at 12:00:02.50. 
%       Since the Vector is pinging continuously during each sample, the 
%       best time for the sample would be the midpoint of the measurement. 
%       So the time for the first 2 Hz sample would be 12:00:02.25, and the 
%       time for the first 16 Hz sample would be 12:00.02.0312.
% The same works for continuous sampling, where you treat the entire 
% measurement as consisting on only one burst.
% and
% http://www.nortek-as.com/en/knowledge-center/forum/velocimeters/158319581
% T = T_timestamp[VVDH] + delay + (1 / (2 * (sampling_rate) )
% delay=2
% Example timing for 2Hz
% 12.00.00 .vhd
% 12.00.01 .sen
% 12.00.02.25 midpoint first  velocity measurement period
% 12.00.02.75 midpoint second velocity measurement period

% vector velocity data header time, dec 18, hex 0x12
Id18Time  = [structures.Id18(:).Time]';
dId18Time = diff(Id18Time)*(24*60*60);

% Possibility of last burst being strange due to stop logging process
iBadBurst = [false; abs(dId18Time - user.MeasInterval) > 1];

% vector system data time (sensors), dec 17, hex 0x11
Id17Time  = [structures.Id17(:).Time]';
dId17Time = diff(Id17Time)*(24*60*60);

timeBurstStart = Id18Time + (2 + 1/(2*user.sampleRate))/(24*60*60);

% create time array for Id16 based on ensemble counter
Id16Count = [structures.Id16(:).Count]';
nSamplePerBurst = max(Id16Count) + 1;
iBurstStart = find(Id16Count == 0);
iBurstNumber = floor(iBurstStart/nSamplePerBurst) + 1;
burstNumber = reshape(repmat(iBurstNumber, [1, nSamplePerBurst])', [], 1);
Id16Time = arrayfun(@(x) timeBurstStart(burstNumber(x)) + (Id16Count(x)/user.sampleRate)/(24*60*60), 1:numel(burstNumber));
Id16Time = Id16Time(:);

% pressure    / 1000.0 (mm       -> m)   assuming equivalence to dbar
% velocities  / 1000.0 (mm/s     -> m/s) assuming earth coordinates
pressure = pressure / 1000.0;
velocity1 = velocity1 * velocityScaling / 1000.0;
velocity2 = velocity2 * velocityScaling / 1000.0;
velocity3 = velocity3 * velocityScaling / 1000.0;

% create sample_data struct
sample_data{1} = struct;
    
sample_data{1}.toolbox_input_file                 = filename;
sample_data{1}.meta.head                          = head;
sample_data{1}.meta.hardware                      = hardware;
sample_data{1}.meta.user                          = user;
sample_data{1}.meta.binSize                       = cellLength;
sample_data{1}.meta.instrument_make               = 'Nortek';
sample_data{1}.meta.instrument_model              = 'Vector Velocity';
% SerialNo can have non-asci characters
sample_data{1}.meta.instrument_serial_no          = hardware.SerialNo;
sample_data{1}.meta.instrument_firmware           = hardware.FWversion;

sample_data{1}.meta.instrument_sample_interval    = 1/user.sampleRate;
if isBurstSampling
    sample_data{1}.meta.instrument_burst_interval = user.MeasInterval;
    sample_data{1}.meta.instrument_burst_duration = user.B1_2/user.sampleRate;
end

% sample_data{1}.meta.beam_angle                    = 45;   % http://wiki.neptunecanada.ca/download/attachments/18022846/Nortek+Aquadopp+Current+Meter+User+Manual+-+Rev+C.pdf
sample_data{1}.meta.featureType                   = mode;

% add dimensions with their data mapped
dims = {'TIME', Id16Time, ''};

nDims = size(dims, 1);
sample_data{1}.dimensions = cell(nDims, 1);
for i=1:nDims
    sample_data{1}.dimensions{i}.name         = dims{i, 1};
    sample_data{1}.dimensions{i}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(dims{i, 1}, 'type')));
    sample_data{1}.dimensions{i}.data         = sample_data{1}.dimensions{i}.typeCastFunc(dims{i, 2});
    sample_data{1}.dimensions{i}.comment      = dims{i, 3};
end
clear dims;

% add information about the middle of the measurement period
%sample_data{1}.dimensions{1}.seconds_to_middle_of_measurement = user.AvgInterval/2;

% add variables with their dimensions and data mapped.
% we assume no correction for magnetic declination has been applied
vars = {
    'TIMESERIES',       [], 1;...
    'LATITUDE',         [], NaN; ...
    'LONGITUDE',        [], NaN; ...
    'NOMINAL_DEPTH',    [], NaN; ...
    'VCUR_MAG',         1,  velocity2; ... % V
    'UCUR_MAG',         1,  velocity1; ... % U
    'WCUR',             1,  velocity3; ...
    'PRES_REL',         1,  pressure; ...
    'ABSIC1',           1,  backscatter1; ...
    'ABSIC2',           1,  backscatter2; ...
    'ABSIC3',           1,  backscatter3; ...
    'CMAG1',            1,  correlation1; ...
    'CMAG2',            1,  correlation2; ...
    'CMAG3',            1,  correlation3; ...
    };
%clear pressure velocity1 velocity2 velocity3 ...
%    correlation1 correlation2 correlation3 ...
%    backscatter1 backscatter2 backscatter3;

nVars = size(vars, 1);
sample_data{1}.variables = cell(nVars, 1);
for i=1:nVars
    sample_data{1}.variables{i}.name         = vars{i, 1};
    sample_data{1}.variables{i}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(vars{i, 1}, 'type')));
    sample_data{1}.variables{i}.dimensions   = vars{i, 2};
    if ~isempty(vars{i, 2}) % we don't want this for scalar variables
        sample_data{1}.variables{i}.coordinates = 'TIME LATITUDE LONGITUDE NOMINAL_DEPTH';
    end
    sample_data{1}.variables{i}.data         = sample_data{1}.variables{i}.typeCastFunc(vars{i, 3});
end
clear vars;

%% create sensor data structure
iGoodId17 = Id17Time < max(Id16Time);
iGoodId17 = iGoodId17(:);

time        = Id17Time(iGoodId17);
battery     = [structures.Id17(iGoodId17).Battery]';
heading     = [structures.Id17(iGoodId17).Heading]';
pitch       = [structures.Id17(iGoodId17).Pitch]';
roll        = [structures.Id17(iGoodId17).Roll]';
temperature = [structures.Id17(iGoodId17).Temperature]';

% battery     / 10.0   (0.1 V    -> V)
% heading     / 10.0   (0.1 deg  -> deg)
% pitch       / 10.0   (0.1 deg  -> deg)
% roll        / 10.0   (0.1 deg  -> deg)
% temperature / 100.0  (0.01 deg -> deg)
battery      = battery      / 10.0;
heading      = heading      / 10.0;
pitch        = pitch        / 10.0;
roll         = roll         / 10.0;
temperature  = temperature  / 100.0;

sample_data{2} = sample_data{1};
sample_data{2}.meta.instrument_model              = 'Vector System';
sample_data{2}.meta.instrument_sample_interval    = 1;
if isBurstSampling
    sample_data{1}.meta.instrument_burst_interval = user.MeasInterval;
    sample_data{1}.meta.instrument_burst_duration = user.B1_2/user.sampleRate;
end

dims = {'TIME', time, ''};
nDims = size(dims, 1);
sample_data{2}.dimensions = cell(nDims, 1);
for i=1:nDims
    sample_data{2}.dimensions{i}.name         = dims{i, 1};
    sample_data{2}.dimensions{i}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(dims{i, 1}, 'type')));
    sample_data{2}.dimensions{i}.data         = sample_data{2}.dimensions{i}.typeCastFunc(dims{i, 2});
end
clear dims;

vars = {
    'TIMESERIES',       [],             1; ...
    'LATITUDE',         [],             NaN; ...
    'LONGITUDE',        [],             NaN; ...
    'NOMINAL_DEPTH',    [],             NaN; ...
    'TEMP',             1,              temperature; ...
    'VOLT',             1,              battery; ...
    'PITCH',            1,              pitch; ...
    'ROLL',             1,              roll; ...
    'HEADING_MAG',      1,              heading
    };
%clear temperature battery pitch roll heading;

nVars = size(vars, 1);
sample_data{2}.variables = cell(nVars, 1);
for i=1:nVars
    sample_data{2}.variables{i}.name         = vars{i, 1};
    sample_data{2}.variables{i}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(vars{i, 1}, 'type')));
    sample_data{2}.variables{i}.dimensions   = vars{i, 2};
    if ~isempty(vars{i, 2}) % we don't want this for scalar variables
        sample_data{2}.variables{i}.coordinates = 'TIME LATITUDE LONGITUDE NOMINAL_DEPTH';
    end
    sample_data{2}.variables{i}.data         = sample_data{2}.variables{i}.typeCastFunc(vars{i, 3});
end
clear vars;

end
