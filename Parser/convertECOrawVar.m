function [name, comment, data, calibration] = convertECOrawVar(columnsInfo, sample)
%CONVERTECORAWVAR Processes data from a WetLabs ECO .raw file.
%
% This function is able to convert data retrieved from a .raw WetLabs ECO
% data file. This function is called from the different read???raw functions.
%
% Inputs:
%   columnsInfo - ECO parameters infos.
%   sample      - ECO raw data.
%
% Outputs:
%   name       - IMOS parameter code.
%   comment    - any comment on the parameter.
%   data       - data converted to fit IMOS parameter unit.
%   calibration - coefficients calibration used to convert data.
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
narginchk(2, 2);

name = '';
comment = '';
data = [];
calibration = struct([]);

switch upper(columnsInfo.type)
    case {'N/U', 'DATE', 'TIME'}
        % ignored
        
    case 'IENGR'
        % not identified by IMOS, won't be output in NetCDF
        name = ['ECO3_' columnsInfo.type];
        data = sample;
        
    case 'PAR' %umol/m2/s
        name = 'PAR';
        data = columnsInfo.im*10.^((sample-columnsInfo.a0)/columnsInfo.a1);
        calibration(1).formula = 'value_engineering_units = calibration_im x 10^((counts - calibration_a0) x calibration_a1)';
        calibration(1).im = columnsInfo.im;
        calibration(1).a0 = columnsInfo.a0;
        calibration(1).a1 = columnsInfo.a1;
        
    case 'CHL' %ug/l (470/695nm)
        name = 'CPHL';
        comment = ['Artificial chlorophyll data computed from bio-optical ' ...
            'sensor raw counts measurements. Originally expressed in ' ...
            'ug/l, 1l = 0.001m3 was assumed.'];
        data = (sample - columnsInfo.offset)*columnsInfo.scale;
        calibration(1).formula = 'value_engineering_units = (counts - calibration_dark_count) x calibration_scale_factor';
        calibration(1).dark_count = columnsInfo.offset;
        calibration(1).scale_factor = columnsInfo.scale;
        
    case 'PHYCOERYTHRIN' %ug/l (540/570nm)
        % not identified by IMOS, won't be output in NetCDF
        name = ['ECO3_' columnsInfo.type];
        comment = 'Expressed in ug/l.';
        data = (sample - columnsInfo.offset)*columnsInfo.scale;
        calibration(1).formula = 'value_engineering_units = (counts - calibration_dark_count) x calibration_scale_factor';
        calibration(1).dark_count = columnsInfo.offset;
        calibration(1).scale_factor = columnsInfo.scale;
        
    case 'PHYCOCYANIN' %ug/l (630/680nm)
        % not identified by IMOS, won't be output in NetCDF
        name = ['ECO3_' columnsInfo.type];
        comment = 'Expressed in ug/l.';
        data = (sample - columnsInfo.offset)*columnsInfo.scale;
        calibration(1).formula = 'value_engineering_units = (counts - calibration_dark_count) x calibration_scale_factor';
        calibration(1).dark_count = columnsInfo.offset;
        calibration(1).scale_factor = columnsInfo.scale;
        
    case 'URANINE' %ppb (470/530nm)
        % not identified by IMOS, won't be output in NetCDF
        name = ['ECO3_' columnsInfo.type];
        comment = 'Expressed in ppb.';
        data = (sample - columnsInfo.offset)*columnsInfo.scale;
        calibration(1).formula = 'value_engineering_units = (counts - calibration_dark_count) x calibration_scale_factor';
        calibration(1).dark_count = columnsInfo.offset;
        calibration(1).scale_factor = columnsInfo.scale;
        
    case 'RHODAMINE' %ug/l (540/570nm)
        % not identified by IMOS, won't be output in NetCDF
        name = ['ECO3_' columnsInfo.type];
        comment = 'Expressed in ug/l.';
        data = (sample - columnsInfo.offset)*columnsInfo.scale;
        calibration(1).formula = 'value_engineering_units = (counts - calibration_dark_count) x calibration_scale_factor';
        calibration(1).dark_count = columnsInfo.offset;
        calibration(1).scale_factor = columnsInfo.scale;
        
    case 'CDOM' %ppb
        name = 'CDOM';
        comment = 'Expressed as equivalent mass fraction (ppb) of quinine sulfate dihydrate.';
        data = (sample - columnsInfo.offset)*columnsInfo.scale;
        calibration(1).formula = 'value_engineering_units = (counts - calibration_dark_count) x calibration_scale_factor';
        calibration(1).dark_count = columnsInfo.offset;
        calibration(1).scale_factor = columnsInfo.scale;
        
    case 'NTU'
        name = 'TURB';
        data = (sample - columnsInfo.offset)*columnsInfo.scale;
        calibration(1).formula = 'value_engineering_units = (counts - calibration_dark_count) x calibration_scale_factor';
        calibration(1).dark_count = columnsInfo.offset;
        calibration(1).scale_factor = columnsInfo.scale;
        
    case 'LAMBDA' %m-1 sr-1
        name = ['VSF' num2str(columnsInfo.measWaveLength)];
        data = (sample - columnsInfo.offset)*columnsInfo.scale;
        calibration(1).formula = 'value_engineering_units = (counts - calibration_dark_count) x calibration_scale_factor';
        calibration(1).dark_count = columnsInfo.offset;
        calibration(1).scale_factor = columnsInfo.scale;
        
    otherwise
        % not identified by IMOS, won't be output in NetCDF
        name = ['ECO3_' columnsInfo.type];
        data = sample;
        if isfield(columnsInfo, 'offset')
            data = data - columnsInfo.offset;
            calibration(1).dark_count = columnsInfo.offset;
        end
        if isfield(columnsInfo, 'scale')
            data = data * columnsInfo.scale;
            calibration(1).scale_factor = columnsInfo.scale;
        end
        
end
end