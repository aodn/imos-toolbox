classdef testOxygenPP < matlab.unittest.TestCase

    % Test Pre-processing Oxygen function
    %
    % refactored version of testOxygenPP.m
    % by hugo.oliveira@utas.edu.au
    %
    % Author:       Peter Jansen <peter.jansen@csiro.au>
    % Contributor:  Guillaume Galibert <guillaume.galibert@utas.edu.au>
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
        mode = {'timeSeries'};
    end

    methods (Test)

        function testOxygenSolubilityFromTempSalt(~, mode)
            file = [toolboxRootPath 'data/testfiles/Sea_Bird_Scientific/SBE/16plus/v000/SBE16plus_oxygen1.cnv'];
            sample_data{1} = SBE19Parse({file}, mode);
            sample_data{1} = fill_geoinfo(sample_data{1});
            sample_data = oxygenPP(sample_data, 'qc');
            sample_data = sample_data{1};

            oxsolSurfSBE = get_data(sample_data, 'OXSOL_SURFACE');
            dox2SBE = get_data(sample_data, 'DOX2');
            doxsSBE = get_data(sample_data, 'DOXS');

            assert(any(abs(oxsolSurfSBE - [262.05291; 271.6910; 247.8694; 250.209]) <= 1e-2), 'Failed: Oxygen Solubility from SBE TEMP and PSAL Check');

            assert(any(abs(dox2SBE - [244.745; 596.267; 244.8609; 244.8362]) <= 1e-2), 'Failed: DOX2 from SBE DOX Check');

            assert(any(abs(doxsSBE / 100 - [0.93395; 2.1946267; 0.9878625; 0.9785269]) <= 1e-4), 'Failed: DOXS from SBE DOX Check');
        end

        function testDOX2fromDOX1_SBE(~, mode)
            file = [toolboxRootPath 'data/testfiles/Sea_Bird_Scientific/SBE/16plus/v000/SBE16plus_oxygen2.cnv'];
            sample_data{1} = SBE19Parse({file}, mode);
            sample_data{1} = fill_geoinfo(sample_data{1});
            sample_data = oxygenPP(sample_data, 'qc');
            sample_data = sample_data{1};

            dox2SBE = get_data(sample_data, 'DOX2');
            assert(any(abs(dox2SBE - 244.7239) <= 1e-2), 'Failed: DOX2 from SBE DOX1 Check');
        end

        function testDOX2fromDOXS_SBE(~, mode)
            file = [toolboxRootPath 'data/testfiles/Sea_Bird_Scientific/SBE/16plus/v000/SBE16plus_oxygen3.cnv'];
            sample_data{1} = SBE19Parse({file}, mode);
            sample_data{1} = fill_geoinfo(sample_data{1});
            sample_data = oxygenPP(sample_data, 'qc');
            sample_data = sample_data{1};

            dox2SBE = get_data(sample_data, 'DOX2');
            assert(any(abs(dox2SBE - 235.6999) <= 1e-2), 'Failed: DOX2 from SBE DOXS Check');
        end

    end

end

function [sample_data] = fill_geoinfo(sample_data)
% just fill some info required
% by oxygenPP
sample_data.geospatial_lat_min = -46;
sample_data.geospatial_lat_max = -46;
sample_data.geospatial_lon_min = 142;
sample_data.geospatial_lon_max = 142;
end

function [data] = get_data(sample_data, vname)
% just bypass
varid = getVar(sample_data.variables, vname);
data = sample_data.variables{varid}.data;
end

