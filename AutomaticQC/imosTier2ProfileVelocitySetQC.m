function [sample_data, varChecked, paramsLog] = imosTier2ProfileVelocitySetQC( sample_data, auto )
%IMOSTIER2PROFILEVELOCITYSETQC Quality control procedure for velocity of profiler ADCP instrument data.
%
% if less than 50% of the bins in the water column (echo intensity test
% gives where the surface/bottom starts) in a profile have passed all of
% the previous tests then the entire profile fails.
%
% Inputs:
%   sample_data - struct containing the entire data set and dimension data.
%   auto - logical, run QC in batch mode
%
% Outputs:
%   sample_data - same as input, with QC flags added for variable/dimension
%                 data.
%   varChecked  - cell array of variables' name which have been checked
%   paramsLog   - string containing details about params' procedure to include in QC log
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
narginchk(1, 2);
if ~isstruct(sample_data), error('sample_data must be a struct'); end

% auto logical in input to enable running under batch processing
if nargin<2, auto=false; end

varChecked = {};
paramsLog  = [];

% get all necessary dimensions and variables id in sample_data struct
idUcur = 0;
idVcur = 0;
idWcur = 0;
idCspd = 0;
idCdir = 0;
lenVar = length(sample_data.variables);
for i=1:lenVar
    paramName = sample_data.variables{i}.name;
    
    if strncmpi(paramName, 'UCUR', 4),  idUcur = i; end
    if strncmpi(paramName, 'VCUR', 4),  idVcur = i; end
    if strcmpi(paramName, 'WCUR'),      idWcur = i; end
    if strcmpi(paramName, 'CSPD'),      idCspd = i; end
    if strncmpi(paramName, 'CDIR', 4),  idCdir = i; end
end

% check if the data is compatible with the QC algorithm
idMandatory = idUcur & idVcur & idWcur;
if ~idMandatory, return; end

qcSet           = str2double(readProperty('toolbox.qc_set'));
badFlag         = imosQCFlag('bad',             qcSet, 'flag');
goodFlag        = imosQCFlag('good',            qcSet, 'flag');
probGoodFlag    = imosQCFlag('probablyGood',    qcSet, 'flag');
rawFlag         = imosQCFlag('raw',             qcSet, 'flag');

% same flags are given to any variable
sizeCur = size(sample_data.variables{idUcur}.flags);
flags = ones(sizeCur, 'int8')*rawFlag;

% Run QC
% if less than 50% of the bins in the water column (echo intensity test) in 
% a profile have passed all of the previous velocity tests then the entire profile fails.
[sd_echo, ~, ~] = imosEchoIntensityVelocitySetQC( sample_data, auto );
iWaterColumn = (sd_echo.variables{idUcur}.flags ~= badFlag);
clear sd_echo;

[sd_hori, ~, ~] = imosHorizontalVelocitySetQC( sample_data, auto );
iHori = sd_hori.variables{idUcur}.flags ~= badFlag;
clear sd_hori;

[~, f_vert, ~]  = imosVerticalVelocityQC( sample_data, sample_data.variables{idWcur}.data, idWcur, 'variables', auto );
iVert = f_vert ~= badFlag;
clear f_vert;

[sd_errv, ~, ~] = imosErrorVelocitySetQC( sample_data, auto );
iErrv = sd_errv.variables{idUcur}.flags ~= badFlag;
clear sd_errv;

[sd_perg, ~, ~] = imosPercentGoodVelocitySetQC( sample_data, auto );
iPerg = sd_perg.variables{idUcur}.flags ~= badFlag;
clear sd_perg;

[sd_cmag, ~, ~] = imosCorrMagVelocitySetQC( sample_data, auto );
iCmag = sd_cmag.variables{idUcur}.flags ~= badFlag;
clear sd_cmag;

% iGood = (hFlags == goodFlag) | (hFlags == probGoodFlag) & (vFlags == goodFlag) | (vFlags == probGoodFlag);
iGood =  iHori & iVert & iErrv & iPerg & iCmag;
iGoodWaterColumn = iGood;
iGoodWaterColumn(~iWaterColumn) = false; % override any bin outside the water column with a fail

nTotalBinWaterColumn = sum(iWaterColumn, 2);
nGoodBinWaterColumn  = sum(iGoodWaterColumn, 2);
clear iGoodWaterColumn;

iPass2 = nGoodBinWaterColumn >= nTotalBinWaterColumn/2;
clear nGoodBinBelowSurface nTotalBinBelowSurface;

iPass = iGood & iWaterColumn; % every single test is passed
clear iWaterColumn iPass1;

iPass(~iPass2, :) = false; % we flag a whole profile bad when relevant
clear iPass2;

iFail = ~iPass;

% Run QC filter (iFail) on velocity data
flags(iFail) = badFlag;
flags(iPass) = goodFlag;

sample_data.variables{idUcur}.flags = flags;
sample_data.variables{idVcur}.flags = flags;
sample_data.variables{idWcur}.flags = flags;

varChecked = {sample_data.variables{idUcur}.name, ...
    sample_data.variables{idVcur}.name, ...
    sample_data.variables{idWcur}.name};

if idCdir
    sample_data.variables{idCdir}.flags = flags;
    varChecked = [varChecked, {sample_data.variables{idCdir}.name}];
end

if idCspd
    sample_data.variables{idCspd}.flags = flags;
    varChecked = [varChecked, {sample_data.variables{idCspd}.name}];
end
    
end
