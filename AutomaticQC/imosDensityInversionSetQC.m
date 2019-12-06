function [sample_data, varChecked, paramsLog] = imosDensityInversionSetQC( sample_data, auto )
%DENSITYINVERSIONSETQC Flags any PSAL + TEMP + CNDC + DENS value that shows an inversion in density 
% or an increase/decrease in density that is greater than a threshold set in 
% imosDensityInversionQC.txt.
%
% Density inversion test on profiles data from ARGO which finds and flags 
% good any data which value Vn passes the tests:
% - density difference when going down <= threshold
% - density difference when going up >= -threshold
%
% Inputs:
%   sample_data - struct containing the data set.
%
%   auto        - logical, run QC in batch mode
%
% Outputs:
%   sample_data - same as input, with QC flags added for variable/dimension
%                 data.
%
%   varChecked  - cell array of variables' name which have been checked
%
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
if ~isstruct(sample_data),              error('sample_data must be a struct');      end

% auto logical in input to enable running under batch processing
if nargin<5, auto=false; end

varChecked = {};
paramsLog  = [];

% this test only applies to profile mode
mode = readProperty('toolbox.mode');
if ~strcmpi(mode, 'profile')
    return;
end

% this test only applies on PSAL when TEMP and pressure data is available
tempIdx = getVar(sample_data.variables, 'TEMP');
psalIdx = getVar(sample_data.variables, 'PSAL');

[presRel, zName, ~] = getPresRelForGSW(sample_data);
[lat, lon] = getLatLonForGSW(sample_data);

if ~(psalIdx && tempIdx && ~isempty(zName) && ~isempty(lat) && ~isempty(lon)), return; end

temp = sample_data.variables{tempIdx}.data;
psal = sample_data.variables{psalIdx}.data;

% read threshold value from properties file
threshold = str2double(readProperty('threshold', fullfile('AutomaticQC', 'imosDensityInversionSetQC.txt')));

% read dataset QC parameters if exist and override previous parameters file
currentQCtest = mfilename;
threshold = readDatasetParameter(sample_data.toolbox_input_file, currentQCtest, 'threshold', 0.03); % default threshold value of 0.03kg/m3
threshold = threshold(1); % fix for compatibility with previous version 2.5.37 and older that used to unnecessarily store an array of thresholds

qcSet = str2double(readProperty('toolbox.qc_set'));
rawFlag         = imosQCFlag('raw',         qcSet, 'flag');
goodFlag        = imosQCFlag('good',        qcSet, 'flag');
probGoodFlag    = imosQCFlag('probablyGood',qcSet, 'flag');
probBadFlag     = imosQCFlag('probablyBad', qcSet, 'flag');
badFlag         = imosQCFlag('bad',         qcSet, 'flag');

badFlags = [probBadFlag, badFlag];

paramsLog = ['threshold=' num2str(threshold)];

% matrix case, we unfold the matrix in one vector for profile study
% purpose
isMatrix = size(temp, 1)>1 & size(temp, 2)>1;
if isMatrix
    len1 = size(temp, 1);
    len2 = size(temp, 2);
    len3 = size(temp, 3);
    temp = temp(:);
end

lenData = length(temp);

% we don't consider already bad data in the current test
tempFlags = sample_data.variables{tempIdx}.flags;
psalFlags = sample_data.variables{psalIdx}.flags;

zIdx = getVar(sample_data.variables, zName);
if zIdx == 0
    % we either have DEPTH as a dimension or we have NOMINAL_DEPTH: in both
    % cases we don't have any flag information, then it is safe to duplicate TEMP flags
    % for example.
    presFlags = tempFlags;
else
    presFlags = sample_data.variables{zIdx}.flags;
end

iBadData = ismember(tempFlags, badFlags) | ismember(psalFlags, badFlags) | ismember(presFlags, badFlags);

% we need at least 2 valid measurements to perform this test
if sum(~iBadData) <= 1, return; end

temp    = temp(~iBadData);
psal    = psal(~iBadData);
presRel = presRel(~iBadData);

lenDataTested = length(temp);

flags = ones(lenData, 1, 'int8')*rawFlag;
flagsTested = ones(lenDataTested, 1, 'int8')*rawFlag;

I = true(lenDataTested, 1);
I(end) = false;

Ip1 = [false; I(1:end-1)];

presRelRef = (presRel(I) + presRel(Ip1))/2;

SA = gsw_SA_from_SP(psal, presRel, lon, lat);
CT = gsw_CT_from_t(SA, temp, presRel);
rhoPotI   = gsw_rho(SA(I), CT(I), presRelRef); % potential density referenced to the mid-point pressure
rhoPotIp1 = gsw_rho(SA(Ip1), CT(Ip1), presRelRef);

deltaUpBottom = [rhoPotI - rhoPotIp1; NaN];
deltaBottomUp = [NaN; rhoPotIp1 - rhoPotI];

iDensInv = deltaUpBottom >= threshold | deltaBottomUp <= -threshold;

flagsTested(iDensInv) = badFlag;
flagsTested(~iDensInv) = goodFlag;
flags(~iBadData) = flagsTested;

if isMatrix
    % we fold the vector back into a matrix
    flags = reshape(flags, [len1, len2, len3]);
end

sample_data.variables{tempIdx}.flags = flags;
sample_data.variables{psalIdx}.flags = flags;

varChecked = {sample_data.variables{tempIdx}.name, ...
    sample_data.variables{psalIdx}.name};

densIdx = getVar(sample_data.variables, 'DENS');
if densIdx
    sample_data.variables{densIdx}.flags = flags;
    varChecked = [varChecked, {sample_data.variables{densIdx}.name}];
end

cndcIdx = getVar(sample_data.variables, 'CNDC');
if cndcIdx
    if any(ismember(sample_data.variables{cndcIdx}.flags, [goodFlag, probGoodFlag]))
        sample_data.variables{cndcIdx}.flags = flags;
        varChecked = [varChecked, {sample_data.variables{cndcIdx}.name}];
    end
end

% write/update dataset QC parameters
writeDatasetParameter(sample_data.toolbox_input_file, currentQCtest, 'threshold', threshold);