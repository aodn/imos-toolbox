function [sample_data] = adcpWorkhorseCorrMagPP( sample_data, auto )
%ADCPWORKHORSECORRMAGPP Screening procedure for Teledyne Workhorse (and similar)
% ADCP instrument data, using the correlation magnitude velocity diagnostic variable.
%
%
% Inputs:
%   sample_data - struct containing the entire data set and dimension data.
%   auto - logical, run QC in batch mode
%
% Outputs:
%   sample_data - same as input, with QC flags added for variable/dimension
%                 data.
% Author:       Guillaume Galibert <guillaume.galibert@utas.edu.au>
%               Rebecca Cowley <rebecca.cowley@csiro.au>
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
idVel1 = 0;
idVel2 = 0;
idVel3 = 0;
idVel4 = 0;
idCMAG = cell(4, 1);
for j=1:4
    idCMAG{j}  = 0;
end
lenVar = length(sample_data.variables);
for i=1:lenVar
    paramName = sample_data.variables{i}.name;
    
    if strncmpi(paramName, 'VEL1', 4),  idVel1 = i; end
    if strncmpi(paramName, 'VEL2', 4),  idVel2 = i; end
    if strcmpi(paramName, 'VEL3',4),      idVel3 = i; end
    if strcmpi(paramName, 'VEL4',4),      idVel4 = i; end
    for j=1:4
        cc = int2str(j);
        if strcmpi(paramName, ['CMAG' cc]), idCMAG{j} = i; end
    end
end

% check if the data is compatible with the QC algorithm
idMandatory = (idVel1 | idVel2 | idVel3 | idVel4 );
for j=1:4
    idMandatory = idMandatory & idCMAG{j};
end
if ~idMandatory, return; end

% let's get the associated vertical dimension
idVertDim = sample_data.variables{idCMAG{1}}.dimensions(2);
if strcmpi(sample_data.dimensions{idVertDim}.name, 'DIST_ALONG_BEAMS')
    disp(['Warning : imosCorrMagVelocitySetQC applied with a non tilt-corrected CMAGn (no bin mapping) on dataset ' sample_data.toolbox_input_file]);
end

qcSet           = str2double(readProperty('toolbox.qc_set'));
badFlag         = imosQCFlag('bad',             qcSet, 'flag');
goodFlag        = imosQCFlag('good',            qcSet, 'flag');
rawFlag         = imosQCFlag('raw',             qcSet, 'flag');

%Pull out correlation magnitude
sizeData = size(sample_data.variables{idCMAG{1}}.data);

% read in filter parameters
propFile = fullfile('Preprocessing', 'adcpWorkhorseCorrMagPP.txt');
cmag     = str2double(readProperty('cmagPP',   propFile));

% read dataset QC parameters if exist and override previous 
% parameters file
currentQCtest = mfilename;
cmag = readDatasetParameter(sample_data.toolbox_input_file, currentQCtest, 'cmag', cmag);

paramsLog = ['cmag=' num2str(cmag)];

sizeCur = size(sample_data.variables{idVel1}.flags);

% same flags are given to any variable
for a = 1:4
    flags = ones(sizeCur, 'int8')*rawFlag;
    
    % Run QC. For this screening test, each beam is tested independently
    eval(['iPass = sample_data.variables{idCMAG{' num2str(a) '}}.data > cmag;'])
    % Run QC filter (iFail) on velocity data
    flags(~iPass) = badFlag;
    flags(iPass) = goodFlag;
    
    eval(['sample_data.variables{idVel' num2str(a) '}.flags = flags;'])

end


% write/update dataset QC parameters
writeDatasetParameter(sample_data.toolbox_input_file, currentQCtest, 'cmagPP', cmag);

end