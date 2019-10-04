function [sample_data, varChecked, paramsLog] = imosEchoIntensityVelocitySetQC( sample_data, auto )
%IMOSECHOINTENSITYVELOCITYSETQC Quality control procedure for Teledyne Workhorse (and similar)
% ADCP instrument data, using the echo intensity velocity diagnostic variable.
%
% Echo Amplitude test :
% this test looks at the difference between consecutive vertical bin values of ea and
% if the value exceeds the threshold, then the bin fails, and all bins
% above/below it are also considered to have failed. This test is designed to get 
% rid of above/below surface/bottom bins.
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
idABSIC = cell(4, 1);
for j=1:4
    idABSIC{j}  = 0;
end
lenVar = length(sample_data.variables);
for i=1:lenVar
    paramName = sample_data.variables{i}.name;
    
    if strncmpi(paramName, 'UCUR', 4),  idUcur = i; end
    if strncmpi(paramName, 'VCUR', 4),  idVcur = i; end
    if strcmpi(paramName, 'WCUR'),      idWcur = i; end
    if strcmpi(paramName, 'CSPD'),      idCspd = i; end
    if strncmpi(paramName, 'CDIR', 4),  idCdir = i; end
    for j=1:4
        cc = int2str(j);
        if strcmpi(paramName, ['ABSIC' cc]), idABSIC{j} = i; end
    end
end

% check if the data is compatible with the QC algorithm
idMandatory = (idUcur | idVcur | idWcur | idCspd | idCdir);
for j=1:4
    idMandatory = idMandatory & idABSIC{j};
end
if ~idMandatory, return; end

% let's get the associated vertical dimension
idVertDim = sample_data.variables{idABSIC{1}}.dimensions(2);
if strcmpi(sample_data.dimensions{idVertDim}.name, 'DIST_ALONG_BEAMS')
    disp(['Warning : imosEchoIntensityVelocitySetQC applied with a non tilt-corrected ABSICn (no bin mapping) on dataset ' sample_data.toolbox_input_file]);
end

qcSet           = str2double(readProperty('toolbox.qc_set'));
badFlag         = imosQCFlag('bad',             qcSet, 'flag');
goodFlag        = imosQCFlag('good',            qcSet, 'flag');
rawFlag         = imosQCFlag('raw',             qcSet, 'flag');

%Pull out echo intensity
sizeData = size(sample_data.variables{idABSIC{1}}.data);
ea = nan(4, sizeData(1), sizeData(2));
for j=1:4
    ea(j, :, :) = sample_data.variables{idABSIC{j}}.data;
end

% read in filter parameters
propFile  = fullfile('AutomaticQC', 'imosEchoIntensityVelocitySetQC.txt');
ea_thresh = str2double(readProperty('ea_thresh',   propFile));

% read dataset QC parameters if exist and override previous 
% parameters file
currentQCtest = mfilename;
ea_thresh = readDatasetParameter(sample_data.toolbox_input_file, currentQCtest, 'ea_thresh', ea_thresh);

paramsLog = ['ea_thresh=' num2str(ea_thresh)];

sizeCur = size(sample_data.variables{idUcur}.flags);

% same flags are given to any variable
flags = ones(sizeCur, 'int8')*rawFlag;

% Run QC
% this test looks at the difference between consecutive vertical bin values of ea and
% if the value exceeds the threshold, then the bin fails, and all bins
% above it are also considered to have failed. This test is designed to get 
% rid of above/below surface/bottom bins.
lenTime = sizeCur(1);
lenBin  = sizeCur(2);

% if the following test is successfull, the bin gets good
ib = uint8(abs(diff(squeeze(ea(1, :,:)),1,2)) <= ea_thresh) + ...
     uint8(abs(diff(squeeze(ea(2, :,:)),1,2)) <= ea_thresh) + ...
     uint8(abs(diff(squeeze(ea(3, :,:)),1,2)) <= ea_thresh) + ...
     uint8(abs(diff(squeeze(ea(4, :,:)),1,2)) <= ea_thresh);

% we look for the bins that have 3 or more beams that pass the tests
ib = ib >= 3;
 
% we assume that the first half of bins should always be good
ib = [true(lenTime, 1), ib];
for i=1:round(lenBin/2)
    ib(:, i) = true;
end
 
% any good bin further than a bad one should be set bad
jkf = repmat(single(1:1:lenBin), [lenTime, 1]);

iii = single(~ib).*jkf;
clear ib;
iii(iii == 0) = NaN;
iif = min(iii, [], 2);
clear iii;
iifNotNan = ~isnan(iif);

iPass = true(lenTime, lenBin);
if any(iifNotNan)
    % all bins further than the first bad one is reset to bad
    iPass(jkf >= repmat(iif, [1, lenBin])) = false;
end
iFail = ~iPass;
clear iifNotNan iif jkf;

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

% write/update dataset QC parameters
writeDatasetParameter(sample_data.toolbox_input_file, currentQCtest, 'ea_thresh', ea_thresh);

end
