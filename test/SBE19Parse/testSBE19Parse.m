function testSBE19Parse()
%TESTSBE19PARSE exercises the function SBE19Parse. This function parses 
% Sea-Bird DataProcessor generated files.
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

% we check that the instrument model description is properly picked-up by
% the regexp in parseInstrumentHeader function from SBE19Parse
testFilesInstruments = {...
    'SBE19plus_example.cnv',    'SBE19plus'; ...
    'SBE9_example.cnv',         'SBE9'; ...
    'SBE16plus_example1.cnv',   'SBE16plus'; ...
    'SBE16plus_example2.cnv',   'SBE16plus'; ...
    'SBE25plus_example.cnv',    'SBE25plus'; ...
    'SBE37_example.cnv',        'SBE37SM-RS232'; ...
    'SBE39plus_example.cnv',    'SBE39plus'};

for i=1:length(testFilesInstruments)
    clear sample_data;
    sample_data = SBE19Parse({fullfile('test', 'SBE19Parse', testFilesInstruments{i, 1})}, 'timeSeries');
    assert(strcmp(sample_data.meta.instrument_model, testFilesInstruments{i, 2}), ...
        ['Failed to parse ' testFilesInstruments{i, 1}]);
end
end