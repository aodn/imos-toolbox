 function sample_data = awacParse( filename )
%AWACPARSE Parses ADCP data from a raw Nortek AWAC binary (.wpr) file. 
%
% Parses a raw binary file from a Nortek AWAC ADCP.
%
% Inputs:
%   filename    - Cell array containing the name of the raw AWAC file 
%                 to parse.
% 
% Outputs:
%   sample_data - Struct containing sample data.
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
time        = zeros(nsamples, 1);
depth       = zeros(ncells,   1);
analn1      = zeros(nsamples, 1);
battery     = zeros(nsamples, 1);
analn2      = zeros(nsamples, 1);
heading     = zeros(nsamples, 1);
pitch       = zeros(nsamples, 1);
roll        = zeros(nsamples, 1);
pressure    = zeros(nsamples, 1);
temperature = zeros(nsamples, 1);
velocity1   = zeros(nsamples, ncells);
velocity2   = zeros(nsamples, ncells);
velocity3   = zeros(nsamples, ncells);
amplitude1  = zeros(nsamples, ncells);
amplitude2  = zeros(nsamples, ncells);
amplitude3  = zeros(nsamples, ncells);

%
% calculate depth values from metadata. See continentalParse.m 
% inline comments for a brief discussion of this process
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

depth(:) = (cellStart):  ...
           (cellLength): ...
           (cellStart + (ncells-1) * cellLength);

for k = 1:nsamples
  
  st = structures{k+3};
  
  time(k)         = st.Time;
  analn1(k)       = st.Analn1;
  battery(k)      = st.Battery;
  analn2(k)       = st.Analn2;
  heading(k)      = st.Heading;
  pitch(k)        = st.Pitch;
  roll(k)         = st.Roll;
  pressure(k)     = st.PressureMSB*65536 + st.PressureLSW;
  temperature(k)  = st.Temperature;
  velocity1(k,:)  = st.Vel1;
  velocity2(k,:)  = st.Vel2;
  velocity3(k,:)  = st.Vel3;
  amplitude1(k,:) = st.Amp1;
  amplitude2(k,:) = st.Amp2;
  amplitude3(k,:) = st.Amp3;
end

% battery     / 10.0   (0.1 V   -> V)
% heading     / 10.0   (0.1 deg -> deg)
% pitch       / 10.0   (0.1 deg -> deg)
% roll        / 10.0   (0.1 deg -> deg)
% pressure    / 1000.0 (mm      -> m)   assuming equivalence to dbar
% temperature / 10.0   (0.1 deg -> deg)
% velocities  / 1000.0 (mm/s    -> m/s) assuming earth coordinates
battery     = battery     / 10.0;
heading     = heading     / 10.0;
pitch       = pitch       / 10.0;
roll        = roll        / 10.0;
pressure    = pressure    / 1000.0;
temperature = temperature / 10.0;
velocity1   = velocity1   / 1000.0;
velocity2   = velocity2   / 1000.0;
velocity3   = velocity3   / 1000.0;

sample_data = struct;

sample_data.meta.head     = head;
sample_data.meta.hardware = hardware;
sample_data.meta.user     = user;
sample_data.meta.instrument_make          = 'Nortek';
sample_data.meta.instrument_model         = 'AWAC';
sample_data.meta.instrument_serial_number = hardware.SerialNo;
sample_data.meta.instrument_firmware      = hardware.FWversion;

sample_data.dimensions{1}.name = 'TIME';
sample_data.dimensions{2}.name = 'DEPTH';
sample_data.variables {1}.name = 'VCUR';
sample_data.variables {2}.name = 'UCUR';
sample_data.variables {3}.name = 'ZCUR';
sample_data.variables {4}.name = 'TEMP';
sample_data.variables {5}.name = 'PRES';
sample_data.variables {6}.name = 'VOLT';
sample_data.variables {7}.name = 'PITCH';
sample_data.variables {8}.name = 'ROLL';
sample_data.variables {9}.name = 'HEADING';

sample_data.variables {1}.dimensions = [1 2];
sample_data.variables {2}.dimensions = [1 2];
sample_data.variables {3}.dimensions = [1 2];
sample_data.variables {4}.dimensions = [1];
sample_data.variables {5}.dimensions = [1];
sample_data.variables {6}.dimensions = [1];
sample_data.variables {7}.dimensions = [1];
sample_data.variables {8}.dimensions = [1];
sample_data.variables {9}.dimensions = [1];

sample_data.dimensions{1}.data = time;
sample_data.dimensions{2}.data = depth;
sample_data.variables {1}.data = velocity1;
sample_data.variables {2}.data = velocity2;
sample_data.variables {3}.data = velocity3;
sample_data.variables {4}.data = temperature;
sample_data.variables {5}.data = pressure;
sample_data.variables {6}.data = battery;
sample_data.variables {7}.data = pitch;
sample_data.variables {8}.data = roll;
sample_data.variables {9}.data = heading;
