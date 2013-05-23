function sample_data = awacParse( filename, mode )
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
%   mode        - Toolbox data type mode ('profile' or 'timeSeries').
% 
% Outputs:
%   sample_data - Struct containing sample data; If wave data is present, 
%                 this will be a cell array of two structs.
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
error(nargchk(1,2,nargin));

if ~iscellstr(filename), error('filename must be a cell array of strings'); end

% only one file supported
filename = filename{1};

% read in all of the structures in the raw file
structures = readParadoppBinary(filename);

% first three sections are header, head and user configuration
hardware = structures{1};
head     = structures{2};
user     = structures{3};

% the rest of the sections are awac data

nsamples = length(structures) - 3;
ncells   = user.NBins;

% preallocate memory for all sample data
time         = zeros(nsamples, 1);
distance     = zeros(ncells,   1);
analn1       = zeros(nsamples, 1);
battery      = zeros(nsamples, 1);
analn2       = zeros(nsamples, 1);
heading      = zeros(nsamples, 1);
pitch        = zeros(nsamples, 1);
roll         = zeros(nsamples, 1);
pressure     = zeros(nsamples, 1);
temperature  = zeros(nsamples, 1);
velocity1    = zeros(nsamples, ncells);
velocity2    = zeros(nsamples, ncells);
velocity3    = zeros(nsamples, ncells);
backscatter1 = zeros(nsamples, ncells);
backscatter2 = zeros(nsamples, ncells);
backscatter3 = zeros(nsamples, ncells);

%
% calculate distance values from metadata. See continentalParse.m 
% inline comments for a brief discussion of this process
%
% http://www.nortek-as.com/en/knowledge-center/forum/hr-profilers/736804717
%
freq       = head.Frequency; % this is in KHz
cellStart  = user.T2;        % counts
cellLength = user.BinLength; % counts
factor     = 0;              % used in conversion

switch freq
  case 600,  factor = 0.0797;
  case 1000, factor = 0.0478;
end

cellLength = (cellLength / 256) * factor * cos(25 * pi / 180);
cellStart  =  cellStart         * 0.0229 * cos(25 * pi / 180) - cellLength;

distance(:) = (cellStart):  ...
           (cellLength): ...
           (cellStart + (ncells-1) * cellLength);
       
% Note this is actually the distance between the ADCP's transducers and the
% middle of each cell
% See http://www.nortek-bv.nl/en/knowledge-center/forum/current-profilers-and-current-meters/579860330
distance = distance + cellLength;

for k = 1:nsamples
  time(k)           = structures{3 + k}.Time;
  analn1(k)         = structures{3 + k}.Analn1;
  battery(k)        = structures{3 + k}.Battery;
  analn2(k)         = structures{3 + k}.Analn2;
  heading(k)        = structures{3 + k}.Heading;
  pitch(k)          = structures{3 + k}.Pitch;
  roll(k)           = structures{3 + k}.Roll;
  pressure(k)       = structures{3 + k}.PressureMSB*65536 + ...
                        structures{3 + k}.PressureLSW;
  temperature(k)    = structures{3 + k}.Temperature;
  velocity1(k,:)    = structures{3 + k}.Vel1;
  velocity2(k,:)    = structures{3 + k}.Vel2;
  velocity3(k,:)    = structures{3 + k}.Vel3;
  backscatter1(k,:) = structures{3 + k}.Amp1;
  backscatter2(k,:) = structures{3 + k}.Amp2;
  backscatter3(k,:) = structures{3 + k}.Amp3;
end
clear structures;

% battery     / 10.0   (0.1 V    -> V)
% heading     / 10.0   (0.1 deg  -> deg)
% pitch       / 10.0   (0.1 deg  -> deg)
% roll        / 10.0   (0.1 deg  -> deg)
% pressure    / 1000.0 (mm       -> m)   assuming equivalence to dbar
% temperature / 100.0  (0.01 deg -> deg)
% velocities  / 1000.0 (mm/s     -> m/s) assuming earth coordinates
% backscatter * 0.45   (counts   -> dB)  see http://www.nortek-as.com/lib/technical-notes/seditments
battery      = battery      / 10.0;
heading      = heading      / 10.0;
pitch        = pitch        / 10.0;
roll         = roll         / 10.0;
pressure     = pressure     / 1000.0;
temperature  = temperature  / 100.0;
velocity1    = velocity1    / 1000.0;
velocity2    = velocity2    / 1000.0;
velocity3    = velocity3    / 1000.0;
backscatter1 = backscatter1 * 0.45;
backscatter2 = backscatter2 * 0.45;
backscatter3 = backscatter3 * 0.45;

sample_data = struct;
    
sample_data.toolbox_input_file              = filename;
sample_data.meta.head                       = head;
sample_data.meta.hardware                   = hardware;
sample_data.meta.user                       = user;
sample_data.meta.binSize                    = cellLength;
sample_data.meta.instrument_make            = 'Nortek';
sample_data.meta.instrument_model           = 'AWAC';
sample_data.meta.instrument_serial_no       = hardware.SerialNo;
sample_data.meta.instrument_sample_interval = median(diff(time*24*3600));
sample_data.meta.instrument_firmware        = hardware.FWversion;
sample_data.meta.beam_angle                 = 25;   % http://www.hydro-international.com/files/productsurvey_v_pdfdocument_19.pdf

sample_data.dimensions{1} .name = 'TIME';
sample_data.dimensions{2} .name = 'HEIGHT_ABOVE_SENSOR';
sample_data.dimensions{3} .name = 'LATITUDE';
sample_data.dimensions{4} .name = 'LONGITUDE';

sample_data.dimensions{1}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data.dimensions{1}.name, 'type')));
sample_data.dimensions{2}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data.dimensions{2}.name, 'type')));
sample_data.dimensions{3}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data.dimensions{3}.name, 'type')));
sample_data.dimensions{4}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data.dimensions{4}.name, 'type')));

sample_data.variables {1} .name = 'VCUR';
sample_data.variables {2} .name = 'UCUR';
sample_data.variables {3} .name = 'WCUR';
sample_data.variables {4} .name = 'ABSI1';
sample_data.variables {5} .name = 'ABSI2';
sample_data.variables {6} .name = 'ABSI3';
sample_data.variables {7} .name = 'TEMP';
sample_data.variables {8} .name = 'PRES_REL';
sample_data.variables {9} .name = 'VOLT';
sample_data.variables {10}.name = 'PITCH';
sample_data.variables {11}.name = 'ROLL';
sample_data.variables {12}.name = 'HEADING';

sample_data.variables{1}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{1}.name, 'type')));
sample_data.variables{2}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{2}.name, 'type')));
sample_data.variables{3}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{3}.name, 'type')));
sample_data.variables{4}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{4}.name, 'type')));
sample_data.variables{5}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{5}.name, 'type')));
sample_data.variables{6}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{6}.name, 'type')));
sample_data.variables{7}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{7}.name, 'type')));
sample_data.variables{8}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{8}.name, 'type')));
sample_data.variables{9}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{9}.name, 'type')));
sample_data.variables{10}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{10}.name, 'type')));
sample_data.variables{11}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{11}.name, 'type')));
sample_data.variables{12}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{12}.name, 'type')));

sample_data.variables {1} .dimensions = [1 2 3 4];
sample_data.variables {2} .dimensions = [1 2 3 4];
sample_data.variables {3} .dimensions = [1 2 3 4];
sample_data.variables {4} .dimensions = [1 2 3 4];
sample_data.variables {5} .dimensions = [1 2 3 4];
sample_data.variables {6} .dimensions = [1 2 3 4];
sample_data.variables {7} .dimensions = [1 3 4];
sample_data.variables {8} .dimensions = [1 3 4];
sample_data.variables {9} .dimensions = [1 3 4];
sample_data.variables {10}.dimensions = [1 3 4];
sample_data.variables {11}.dimensions = [1 3 4];
sample_data.variables {12}.dimensions = [1 3 4];

sample_data.dimensions{1} .data = sample_data.dimensions{1}.typeCastFunc(time);
sample_data.dimensions{2} .data = sample_data.dimensions{2}.typeCastFunc(distance);
sample_data.dimensions{3} .data = sample_data.dimensions{3}.typeCastFunc(NaN);
sample_data.dimensions{4} .data = sample_data.dimensions{4}.typeCastFunc(NaN);

sample_data.variables {1} .data = sample_data.variables{1}.typeCastFunc(velocity2); % V
sample_data.variables {2} .data = sample_data.variables{2}.typeCastFunc(velocity1); % U
sample_data.variables {3} .data = sample_data.variables{3}.typeCastFunc(velocity3);
sample_data.variables {4} .data = sample_data.variables{4}.typeCastFunc(backscatter1);
sample_data.variables {5} .data = sample_data.variables{5}.typeCastFunc(backscatter2);
sample_data.variables {6} .data = sample_data.variables{6}.typeCastFunc(backscatter3);
sample_data.variables {7} .data = sample_data.variables{7}.typeCastFunc(temperature);
sample_data.variables {8} .data = sample_data.variables{8}.typeCastFunc(pressure);
sample_data.variables {9} .data = sample_data.variables{9}.typeCastFunc(battery);
sample_data.variables {10}.data = sample_data.variables{10}.typeCastFunc(pitch);
sample_data.variables {11}.data = sample_data.variables{11}.typeCastFunc(roll);
sample_data.variables {12}.data = sample_data.variables{12}.typeCastFunc(heading);
clear analn1 analn2 time distance velocity1 velocity2 velocity3 ...
    backscatter1 backscatter2 backscatter3 ...
    temperature pressure battery pitch roll heading;

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

[path, filename, ~] = fileparts(filename);
filename = fullfile(path, [filename '.wap']);

sample_data{2}.toolbox_input_file              = filename;
sample_data{2}.meta.head                       = [];
sample_data{2}.meta.hardware                   = [];
sample_data{2}.meta.user                       = [];
sample_data{2}.meta.instrument_sample_interval = median(diff(waveData.Time*24*3600));

sample_data{2}.dimensions = {};
sample_data{2}.variables  = {};

sample_data{2}.dimensions{1 }.name = 'TIME';
sample_data{2}.dimensions{2 }.name = 'LATITUDE';
sample_data{2}.dimensions{3 }.name = 'LONGITUDE';
sample_data{2}.dimensions{4 }.name = 'FREQUENCY_1';
sample_data{2}.dimensions{5 }.name = 'FREQUENCY_2';
sample_data{2}.dimensions{6 }.name = 'DIR';

sample_data{2}.dimensions{1}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data{2}.dimensions{1}.name, 'type')));
sample_data{2}.dimensions{2}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data{2}.dimensions{2}.name, 'type')));
sample_data{2}.dimensions{3}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data{2}.dimensions{3}.name, 'type')));
sample_data{2}.dimensions{4}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data{2}.dimensions{4}.name, 'type')));
sample_data{2}.dimensions{5}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data{2}.dimensions{5}.name, 'type')));
sample_data{2}.dimensions{6}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data{2}.dimensions{6}.name, 'type')));

sample_data{2}.variables {1 }.name = 'VDEN';
sample_data{2}.variables {2 }.name = 'SSWD';
sample_data{2}.variables {3 }.name = 'VAVH';
sample_data{2}.variables {4 }.name = 'VAVT';
sample_data{2}.variables {5 }.name = 'VDIR';
sample_data{2}.variables {6 }.name = 'SSDS';
sample_data{2}.variables {7 }.name = 'TEMP';
sample_data{2}.variables {8 }.name = 'PRES_REL';
sample_data{2}.variables {9 }.name = 'VOLT';
sample_data{2}.variables {10}.name = 'HEADING';
sample_data{2}.variables {11}.name = 'PITCH';
sample_data{2}.variables {12}.name = 'ROLL';
sample_data{2}.variables {13}.name = 'SSWV';

sample_data{2}.variables{1}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data{2}.variables{1}.name, 'type')));
sample_data{2}.variables{2}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data{2}.variables{2}.name, 'type')));
sample_data{2}.variables{3}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data{2}.variables{3}.name, 'type')));
sample_data{2}.variables{4}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data{2}.variables{4}.name, 'type')));
sample_data{2}.variables{5}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data{2}.variables{5}.name, 'type')));
sample_data{2}.variables{6}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data{2}.variables{6}.name, 'type')));
sample_data{2}.variables{7}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data{2}.variables{7}.name, 'type')));
sample_data{2}.variables{8}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data{2}.variables{8}.name, 'type')));
sample_data{2}.variables{9}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data{2}.variables{9}.name, 'type')));
sample_data{2}.variables{10}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data{2}.variables{10}.name, 'type')));
sample_data{2}.variables{11}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data{2}.variables{11}.name, 'type')));
sample_data{2}.variables{12}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data{2}.variables{12}.name, 'type')));
sample_data{2}.variables{13}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data{2}.variables{13}.name, 'type')));

sample_data{2}.variables{1 }.dimensions = [1 2 3 4];
sample_data{2}.variables{2 }.dimensions = [1 2 3 5];
sample_data{2}.variables{3 }.dimensions = [1 2 3];
sample_data{2}.variables{4 }.dimensions = [1 2 3];
sample_data{2}.variables{5 }.dimensions = [1 2 3];
sample_data{2}.variables{6 }.dimensions = [1 2 3];
sample_data{2}.variables{7 }.dimensions = [1 2 3];
sample_data{2}.variables{8 }.dimensions = [1 2 3];
sample_data{2}.variables{9 }.dimensions = [1 2 3];
sample_data{2}.variables{10}.dimensions = [1 2 3];
sample_data{2}.variables{11}.dimensions = [1 2 3];
sample_data{2}.variables{12}.dimensions = [1 2 3];
sample_data{2}.variables{13}.dimensions = [1 2 3 5 6];

sample_data{2}.dimensions{1 }.data = sample_data{2}.dimensions{1}.typeCastFunc(waveData.Time);
sample_data{2}.dimensions{2 }.data = sample_data{2}.dimensions{2}.typeCastFunc(NaN);
sample_data{2}.dimensions{3 }.data = sample_data{2}.dimensions{3}.typeCastFunc(NaN);
sample_data{2}.dimensions{4 }.data = sample_data{2}.dimensions{4}.typeCastFunc(waveData.pwrFrequency);
sample_data{2}.dimensions{5 }.data = sample_data{2}.dimensions{5}.typeCastFunc(waveData.dirFrequency);
sample_data{2}.dimensions{6 }.data = sample_data{2}.dimensions{6}.typeCastFunc(waveData.Direction);

sample_data{2}.variables {1 }.data = sample_data{2}.variables{1}.typeCastFunc(waveData.pwrSpectrum);
sample_data{2}.variables {2 }.data = sample_data{2}.variables{2}.typeCastFunc(waveData.dirSpectrum);
sample_data{2}.variables {3 }.data = sample_data{2}.variables{3}.typeCastFunc(waveData.SignificantHeight);
sample_data{2}.variables {4 }.data = sample_data{2}.variables{4}.typeCastFunc(waveData.MeanZeroCrossingPeriod);
sample_data{2}.variables {5 }.data = sample_data{2}.variables{5}.typeCastFunc(waveData.MeanDirection);
sample_data{2}.variables {6 }.data = sample_data{2}.variables{6}.typeCastFunc(waveData.DirectionalSpread);
sample_data{2}.variables {7 }.data = sample_data{2}.variables{7}.typeCastFunc(waveData.Temperature);
sample_data{2}.variables {8 }.data = sample_data{2}.variables{8}.typeCastFunc(waveData.MeanPressure);
sample_data{2}.variables {9 }.data = sample_data{2}.variables{9}.typeCastFunc(waveData.Battery);
sample_data{2}.variables {10}.data = sample_data{2}.variables{10}.typeCastFunc(waveData.Heading);
sample_data{2}.variables {11}.data = sample_data{2}.variables{11}.typeCastFunc(waveData.Pitch);
sample_data{2}.variables {12}.data = sample_data{2}.variables{12}.typeCastFunc(waveData.Roll);
sample_data{2}.variables {13}.data = sample_data{2}.variables{13}.typeCastFunc(waveData.fullSpectrum);
clear waveData;
