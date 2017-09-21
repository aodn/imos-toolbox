function testOxygenPP()
%TESTOXYGENPP exercises the function oxygenPP. This function is a 
% pre-processing routine that adds oxygen parameters to the dataset.
%
% Author:       Peter Jansen <peter.jansen@csiro.au>
% Contributor:  Guillaume Galibert <guillaume.galibert@utas.edu.au>
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
clear sample_data;

testDir = fullfile('test', 'oxygenPP');

% Test 1: Oxygen Solubility from TEMP and PSAL
sample_data{1} = SBE19Parse({fullfile(testDir, 'SBE16plus_example1.cnv')}, 'timeSeries');

sample_data{1}.geospatial_lat_min = -46;
sample_data{1}.geospatial_lat_max = -46;
sample_data{1}.geospatial_lon_min = 142;
sample_data{1}.geospatial_lon_max = 142;

sample_data = oxygenPP(sample_data, 'qc');

oxsolSurfSBE = sample_data{1}.variables{getVar(sample_data{1}.variables, 'OXSOL_SURFACE')}.data;
dox2SBE      = sample_data{1}.variables{getVar(sample_data{1}.variables, 'DOX2')}.data;
doxsSBE      = sample_data{1}.variables{getVar(sample_data{1}.variables, 'DOXS')}.data;

assert(any(abs(oxsolSurfSBE - [262.05291; 271.6910;  247.8694;  250.209])   <= 1e-2), 'Failed: Oxygen Solubility from SBE TEMP and PSAL Check');

% Test 2: DOX2 from DOX
assert(any(abs(dox2SBE      - [244.745;   596.267;   244.8609;  244.8362])  <= 1e-2), 'Failed: DOX2 from SBE DOX Check');

% Test 3: DOXS from DOX
assert(any(abs(doxsSBE/100  - [0.93395;   2.1946267; 0.9878625; 0.9785269]) <= 1e-4), 'Failed: DOXS from SBE DOX Check');

% test 4: DOX2 from DOX1
clear sample_data;
sample_data{1} = SBE19Parse({fullfile(testDir, 'SBE16plus_example2.cnv')}, 'timeSeries');

sample_data{1}.geospatial_lat_min = -46;
sample_data{1}.geospatial_lat_max = -46;
sample_data{1}.geospatial_lon_min = 142;
sample_data{1}.geospatial_lon_max = 142;

sample_data = oxygenPP(sample_data, 'qc');

dox2SBE = sample_data{1}.variables{getVar(sample_data{1}.variables, 'DOX2')}.data;

assert(any(abs(dox2SBE - 244.7239) <= 1e-2), 'Failed: DOX2 from SBE DOX1 Check');

% test 5: DOX2 from DOXS
clear sample_data;
sample_data{1} = SBE19Parse({fullfile(testDir, 'SBE16plus_example3.cnv')}, 'timeSeries');

sample_data{1}.geospatial_lat_min = -46;
sample_data{1}.geospatial_lat_max = -46;
sample_data{1}.geospatial_lon_min = 142;
sample_data{1}.geospatial_lon_max = 142;

sample_data = oxygenPP(sample_data, 'qc');

dox2SBE = sample_data{1}.variables{getVar(sample_data{1}.variables, 'DOX2')}.data;

assert(any(abs(dox2SBE - 235.6999) <= 1e-2), 'Failed: DOX2 from SBE DOXS Check');
end