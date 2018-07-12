function testReadWQMraw()
%TESTREADWQMRAW exercises the function readWQMraw. This function parses 
% WetLabs WQM generated files.
%
% Author:       Guillaume Galibert <guillaume.galibert@utas.edu.au>
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

% we check that the instrument serial number is properly picked-up by the
% parser
testFilesInstruments = {...
    'WQM0045_016_v1.21_example.RAW',     '45'; ...
    'WQM0047_003_v1.20_example.RAW',     '47'; ...
    'WQM0048_004_v1.62_example.RAW',     '48'; ...
    'WQM0049_000_v1.19_example.RAW',     '49'; ...
    'WQM0052_014_fw1.21_example.Raw',    '52'; ...
    'WQM0054_003_v1.62_example.RAW',     '54'; ...
    'WQM0063_002_fw1.26_example.Raw',    '63'; ...
    'WQM0063_1711_fw1.59_example.Raw',   '63'; ...
    'WQM0064_003_fw1.59_example.Raw',    '64'; ...
    'WQM0067_002_fw1.59_example.Raw',    '67'; ...
    'WQM0140_002_fw1.26_example.Raw',    '140'; ...
    'WQM0142_026_fw1.23_example.Raw',    '142'; ...
    'WQM0144_015_fw1.20c_example.Raw',   '144'};

for i=1:length(testFilesInstruments)
    try
        clear sample_data;
        sample_data = readWQMraw(fullfile('test', 'readWQMraw', testFilesInstruments{i, 1}), 'timeSeries');
        assert(strcmp(sample_data.meta.instrument_serial_no, testFilesInstruments{i, 2}), ...
            ['Failed to parse ' testFilesInstruments{i, 1}]);
    catch ex
        errorString = getErrorString(ex);
        fprintf('%s\n',   ['Error says : ' errorString]);
        error(['Failed to parse ' testFilesInstruments{i, 1}]);
    end
end
end