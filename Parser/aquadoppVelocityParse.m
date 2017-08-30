function sample_data = aquadoppVelocityParse( filename, mode )
%AQUADOPPVELOCITYPARSE Parses ADCP data from a raw Nortek Aquadopp Velocity 
% binary (.aqd) file.
%
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

% the rest of the sections are aquadopp velocity data, diagnostic header
% and diagnostic data. We will only keep the velocity data (Id == 1) .

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
       
% retrieve sample data
time         = [structures.Id1(:).Time]';
analn1       = [structures.Id1(:).Analn1]';
battery      = [structures.Id1(:).Battery]';
analn2       = [structures.Id1(:).Analn2]';
heading      = [structures.Id1(:).Heading]';
pitch        = [structures.Id1(:).Pitch]';
roll         = [structures.Id1(:).Roll]';
pressure     = [structures.Id1(:).PressureMSB]'*65536 + [structures.Id1(:).PressureLSW]';
temperature  = [structures.Id1(:).Temperature]';
velocity1    = [structures.Id1(:).Vel1]';
velocity2    = [structures.Id1(:).Vel2]';
velocity3    = [structures.Id1(:).Vel3]';
backscatter1 = [structures.Id1(:).Amp1]';
backscatter2 = [structures.Id1(:).Amp2]';
backscatter3 = [structures.Id1(:).Amp3]';
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

sample_data = struct;
    
sample_data.toolbox_input_file              = filename;
sample_data.meta.head                       = head;
sample_data.meta.hardware                   = hardware;
sample_data.meta.user                       = user;
sample_data.meta.binSize                    = cellLength;
sample_data.meta.instrument_make            = 'Nortek';
sample_data.meta.instrument_model           = 'Aquadopp Current Meter';
sample_data.meta.instrument_serial_no       = hardware.SerialNo;
sample_data.meta.instrument_firmware        = hardware.FWversion;
sample_data.meta.instrument_sample_interval = median(diff(time*24*3600));
sample_data.meta.instrument_average_interval= user.AvgInterval;
sample_data.meta.beam_angle                 = 45;   % http://wiki.neptunecanada.ca/download/attachments/18022846/Nortek+Aquadopp+Current+Meter+User+Manual+-+Rev+C.pdf
sample_data.meta.featureType                = mode;

% add dimensions with their data mapped
dims = {
    'TIME', time, ['Time stamp corresponds to the start of the measurement which lasts ' num2str(user.AvgInterval) ' seconds.'] 
    };
clear time;

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
vars = {
    'TIMESERIES',       [], 1;...
    'LATITUDE',         [], NaN; ...
    'LONGITUDE',        [], NaN; ...
    'NOMINAL_DEPTH',    [], NaN; ...
    'VCUR_MAG',         1,  velocity2; ... % V
    'UCUR_MAG',         1,  velocity1; ... % U
    'WCUR',             1,  velocity3; ...
    'ABSIC1',           1,  backscatter1; ...
    'ABSIC2',           1,  backscatter2; ...
    'ABSIC3',           1,  backscatter3; ...
    'TEMP',             1,  temperature; ...
    'PRES_REL',         1,  pressure; ...
    'VOLT',             1,  battery; ...
    'PITCH',            1,  pitch; ...
    'ROLL',             1,  roll; ...
    'HEADING_MAG',      1,  heading
    };
clear analn1 analn2 time distance velocity1 velocity2 velocity3 ...
    backscatter1 backscatter2 backscatter3 ...
    temperature pressure battery pitch roll heading;

nVars = size(vars, 1);
sample_data.variables = cell(nVars, 1);
for i=1:nVars
    sample_data.variables{i}.name         = vars{i, 1};
    sample_data.variables{i}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(vars{i, 1}, 'type')));
    sample_data.variables{i}.dimensions   = vars{i, 2};
    if ~isempty(vars{i, 2}) % we don't want this for scalar variables
        sample_data.variables{i}.coordinates = 'TIME LATITUDE LONGITUDE NOMINAL_DEPTH';
    end
    sample_data.variables{i}.data         = sample_data.variables{i}.typeCastFunc(vars{i, 3});
end
clear vars;
