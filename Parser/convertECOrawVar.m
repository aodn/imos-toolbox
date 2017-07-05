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
% Copyright (c) 2016, Australian Ocean Data Network (AODN) and Integrated 
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
%     * Neither the name of the AODN/IMOS nor the names of its contributors 
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