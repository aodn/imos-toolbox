function sample_data = spiritCountToEngPP( sample_data, qcLevel, auto )
%SPIRITCOUNTTOENGPP Converts TURB and CPHL from count to engineering units 
%
% This function uses constant calibration_blank and calibration_scales 
%
% Inputs:
%   sample_data - cell array of data sets, ideally with turbidity and
%                 fluorescence in counts.
%   qcLevel     - string, 'raw' or 'qc'. Some pp not applied when 'raw'.
%   auto        - logical, run pre-processing in batch mode.
%
% Outputs:
%   sample_data - the same data sets, with salinity variables added.
%
% Contributor:  Guillaume Galibert <guillaume.galibert@utas.edu.au>
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
narginchk(2, 3);

if ~iscell(sample_data), error('sample_data must be a cell array'); end
if isempty(sample_data), return;                                    end

% no modification of data is performed on the raw FV00 dataset except
% local time to UTC conversion
if strcmpi(qcLevel, 'raw'), return; end

% auto logical in input to enable running under batch processing
if nargin<3, auto=false; end

calibFile = ['Preprocessing' filesep 'spiritCountToEngPP.txt'];
cphlBlank = str2double(readProperty('cphlBlank', calibFile));
cphlScale = str2double(readProperty('cphlScale', calibFile));
turbBlank = str2double(readProperty('turbBlank', calibFile));
turbScale = str2double(readProperty('turbScale', calibFile));

for k = 1:length(sample_data)
    [~, fileName, ext] = fileparts(sample_data{k}.toolbox_input_file);
    
    flu2Idx       = getVar(sample_data{k}.variables, 'FLU2');
    turbcIdx      = getVar(sample_data{k}.variables, 'TURBC');
    
    FLU2 = sample_data{k}.variables{flu2Idx};
    TURBC = sample_data{k}.variables{turbcIdx};
    
    CPHL = FLU2;
    TURB = TURBC;
    
    calibration_formula = 'value_engineering_units = (counts - calibration_blank) x calibration_scale';
    
    % convert fluorescence counts to chlorophyll a in ug/l
    CPHL.calibration_blank = cphlBlank;
    CPHL.calibration_scale = cphlScale;
    CPHL.data = (FLU2.data - CPHL.calibration_blank) * CPHL.calibration_scale;
    CPHL.comment = ['spiritCountToEngPP.m: artificial chlorophyll data derived from WetLabs ECO-FLNTU bio-optical ' ...
        'sensor raw counts measurements using calibration_formula. Originally expressed in ' ...
        'ug/l, 1l = 0.001m3 was assumed.'];
    
    
    if any(CPHL.data < 0)
        minCountValue = min(FLU2.data);
        disp(['Warning: spiritCountToEngPP.m computed negative values for CPHL in ' fileName ext '! Minimum count value found is ' num2str(minCountValue)]);
    end
    
    % convert turbidity count to NTU
    TURB.calibration_blank = turbBlank;
    TURB.calibration_scale = turbScale;
    TURB.data = (TURBC.data - TURB.calibration_blank) * TURB.calibration_scale;
    TURB.comment = ['spiritCountToEngPP.m: turbidity in NTU derived from WetLabs ECO-FLNTU bio-optical ' ...
        'sensor raw counts measurements using calibration_formula.'];
    
    if any(TURB.data < 0)
        minCountValue = min(TURBC.data);
        disp(['Warning: spiritCountToEngPP.m computed negative values for TURB in ' fileName ext '! Minimum count value found is ' num2str(minCountValue)]);
    end
    
    % add CPHL data as new variable in data set
    sample_data{k} = addVar(...
        sample_data{k}, ...
        'CPHL', ...
        CPHL.data, ...
        CPHL.dimensions, ...
        CPHL.comment, ...
        CPHL.coordinates);
    
    cphlIdx      = getVar(sample_data{k}.variables, 'CPHL');
    
    sample_data{k}.variables{cphlIdx}.calibration_formula = calibration_formula;
    sample_data{k}.variables{cphlIdx}.calibration_blank = CPHL.calibration_blank;
    sample_data{k}.variables{cphlIdx}.calibration_scale = CPHL.calibration_scale;
    
    % add TURB data as new variable in data set
    sample_data{k} = addVar(...
        sample_data{k}, ...
        'TURB', ...
        TURB.data, ...
        TURB.dimensions, ...
        TURB.comment, ...
        TURB.coordinates);
    
    turbIdx      = getVar(sample_data{k}.variables, 'TURB');
    
    sample_data{k}.variables{turbIdx}.calibration_formula = calibration_formula;
    sample_data{k}.variables{turbIdx}.calibration_blank = TURB.calibration_blank;
    sample_data{k}.variables{turbIdx}.calibration_scale = TURB.calibration_scale;
    
    % remove FLU2 and TURBC from FV01
    sample_data{k}.variables([flu2Idx turbcIdx]) = [];
    
    % update history
    history = sample_data{k}.history;
    if isempty(history)
        sample_data{k}.history = sprintf('%s - %s', datestr(now_utc, readProperty('exportNetCDF.dateFormat')), [TURB.comment ' ' CPHL.comment]);
    else
        sample_data{k}.history = sprintf('%s\n%s - %s', history, datestr(now_utc, readProperty('exportNetCDF.dateFormat')), [TURB.comment ' ' CPHL.comment]);
    end
end
