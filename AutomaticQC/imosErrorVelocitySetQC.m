function [sample_data, varChecked, paramsLog] = imosErrorVelocitySetQC( sample_data, auto )
%IMOSERRORVELOCITYSETQC Quality control procedure for Teledyne Workhorse (and similar)
% ADCP instrument data, using the error velocity diagnostic variable.
%
% Error Velocity test : measurement of disagreement of measurement estimates 
% of opposite beams. Derived from 2 independent beams and therefore is 2 
% indenpendent measures of vertical velocity. Velocity data is flagged bad
% when error velocity is greater than a specific threshold.
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
idEcur = 0;
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
    if strcmpi(paramName, 'ECUR'),      idEcur = i; end
    if strcmpi(paramName, 'CSPD'),      idCspd = i; end
    if strncmpi(paramName, 'CDIR', 4),  idCdir = i; end
end

% check if the data is compatible with the QC algorithm
idMandatory = idEcur & (idUcur | idVcur | idWcur | idCspd | idCdir);
if ~idMandatory, return; end

qcSet           = str2double(readProperty('toolbox.qc_set'));
badFlag         = imosQCFlag('bad',             qcSet, 'flag');
goodFlag        = imosQCFlag('good',            qcSet, 'flag');
probGoodFlag    = imosQCFlag('probablyGood',    qcSet, 'flag');
rawFlag         = imosQCFlag('raw',             qcSet, 'flag');

% Pull out error velocities
erv = sample_data.variables{idEcur}.data;

% read in filter parameters
propFile = fullfile('AutomaticQC', 'imosErrorVelocitySetQC.txt');
err_vel  = str2double(readProperty('err_vel',   propFile));

% read dataset QC parameters if exist and override previous 
% parameters file
currentQCtest = mfilename;
err_vel = readDatasetParameter(sample_data.toolbox_input_file, currentQCtest, 'err_vel', err_vel);

paramsLog = ['err_vel=' num2str(err_vel)];

sizeCur = size(sample_data.variables{idUcur}.flags);

% same flags are given to any variable
flags = ones(sizeCur, 'int8')*rawFlag;

% NaN for erv doesn't mean data is bad, it is just a 3 beam solution and ECUR is not available
iNaNerv = isnan(erv);
% Run QC
iPass = abs(erv) <= err_vel;
iPass(iNaNerv) = true;

iFail = ~iPass;

% Run QC filter (iFail) on velocity data
flags(iFail) = badFlag;
flags(iPass) = goodFlag;

% If the cell contains a NaN in the error velocity test, then is set to 
% probably good
flags(iPass & iNaNerv) = probGoodFlag;

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

% write/update dataset QC parameters
writeDatasetParameter(sample_data.toolbox_input_file, currentQCtest, 'err_vel', err_vel);

end