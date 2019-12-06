classdef testRepeatedTimesJFE < matlab.unittest.TestCase
    %
    % Test JFE infinity with high-frequency sampling.
    % The instrument software do not output microseconds
    % resulting in repeated time entries that need to be
    % corrected.
    %
    % author: hugo.oliveira@utas.edu.au
    %

    % Copyright (C) 2019, Australian Ocean Data Network (AODN) and Integrated
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
    %
    % You should have received a copy of the GNU General Public License
    % along with this program.
    % If not, see <https://www.gnu.org/licenses/gpl-3.0.en.html>.
    %
    properties (TestParameter)
        mode = {'timeSeries'}; %, 'profile'};
        jfe_param = load_param();
    end

    methods (Test)

        function testNonRepeatedTimes(~, jfe_param,mode)
            data = infinitySDLoggerParse({jfe_param}, mode);
            istime = @(x) strcmpi(x.name, 'TIME');
            timeind = cellfun(istime, data.dimensions);
            time = data.dimensions{timeind};
            tinfo = timeSamplingInfo(time.data);
            valid_sampling = all([tinfo.unique_sampling, tinfo.monotonic_sampling, tinfo.progressive_sampling]);
            valid_interval = data.meta.instrument_sample_interval/min(tinfo.sampling_steps) > 0;
            assert(valid_sampling);
            assert(valid_interval);
        end

    end

end

function [param] = load_param()
    root_folder = toolboxRootPath();
    folder = fullfile(root_folder, 'data/testfiles/JFE/v000');
    files = FilesInFolder(folder);
    param = files2namestruct(files);
end
