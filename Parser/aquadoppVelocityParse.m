function sample_data = aquadoppVelocityParse( filename, mode )
%AQUADOPPVELOCITYPARSE Parses ADCP data from a raw Nortek Aquadopp Velocity 
% binary (.aqd) file.
%
%
% Inputs:
%   filename    - Cell array containing the name of the raw aquadopp velocity 
%                 file to parse.
%   mode        - Toolbox data type mode ('profile' or 'timeSeries').
% 
% Outputs:
%   sample_data - Struct containing sample data.
%
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

% the rest of the sections are aquadopp velocity data, diagnostic header
% and diagnostic data. We will only keep the velocity data (Id == 1) .
nsamples = length(structures.Id1);
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
factor     = 0;              % used for conversion

switch freq
  case 2000, factor = 0.0239;
end

cellLength = (cellLength / 256) * factor * cos(25 * pi / 180);
cellStart  =  cellStart         * 0.0229 * cos(25 * pi / 180) - cellLength;

% generate distance values
distance(:) = (cellStart):  ...
           (cellLength): ...
           (cellStart + (ncells-1) * cellLength);

% Note this is actually the distance between the ADCP's transducers and the
% middle of each cell
% See http://www.nortek-bv.nl/en/knowledge-center/forum/current-profilers-and-current-meters/579860330
% in the case of a current meter, this is a horizontal distance from the
% transducer.
distance = distance + cellLength;
       
% retrieve sample data
time         = structures.Id1.Time';
analn1       = structures.Id1.Analn1';
battery      = structures.Id1.Battery';
analn2       = structures.Id1.Analn2';
heading      = structures.Id1.Heading';
pitch        = structures.Id1.Pitch';
roll         = structures.Id1.Roll';
pressure     = structures.Id1.PressureMSB'*65536 + structures.Id1.PressureLSW';
temperature  = structures.Id1.Temperature';
velocity1    = structures.Id1.Vel1';
velocity2    = structures.Id1.Vel2';
velocity3    = structures.Id1.Vel3';
backscatter1 = structures.Id1.Amp1';
backscatter2 = structures.Id1.Amp2';
backscatter3 = structures.Id1.Amp3';
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
sample_data.meta.beam_angle                 = 45;   % http://wiki.neptunecanada.ca/download/attachments/18022846/Nortek+Aquadopp+Current+Meter+User+Manual+-+Rev+C.pdf
sample_data.meta.featureType                = mode;

% add dimensions with their data mapped
dims = {
    'TIME',                   time
    };
clear time;

nDims = size(dims, 1);
sample_data.dimensions = cell(nDims, 1);
for i=1:nDims
    sample_data.dimensions{i}.name         = dims{i, 1};
    sample_data.dimensions{i}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(dims{i, 1}, 'type')));
    sample_data.dimensions{i}.data         = sample_data.dimensions{i}.typeCastFunc(dims{i, 2});
end
clear dims;

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
