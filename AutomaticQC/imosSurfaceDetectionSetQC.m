function [sample_data, varChecked, paramsLog] = imosSurfaceDetectionSetQC( sample_data, auto )
%IMOSSURFACEDETECTIONSETQC Quality control procedure for Teledyne Workhorse (and similar)
% ADCP instrument data, using the echo intensity velocity diagnostic variable,
% in conjunction with a side-lobe test and enhancements.
%
% Echo Amplitude test :
% this test looks at the difference between consecutive vertical bin values of ea and
% if the value exceeds the threshold, then the bin fails, and all bins
% above/below it are also considered to have failed. This test is designed to get 
% rid of above/below surface/bottom bins.
% Enhancements to this test (originally imosEchoIntensityVelocitySetQC):
%   1. only bins within 3 * bin size of the surface/bottom are examined
%   2. NaN values in bins are counted as a pass
%   3. Only one beam has to fail the threshold test (was 3)
%   4. The imosSideLobeVelocitySetQC test is applied for bins that still
%   have 'good' data that is above the surface + 1 bin (below the bottom - 1 bin)
%
% Assumptions: 
%   1. The echo data has been bin mapped (but it will work without the bin
%   mapping)
%   2. The depth is known for each time stamp 
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
% check if the data is compatible with the QC algorithm, otherwise quit
% silently
idHeight = getVar(sample_data.dimensions, 'HEIGHT_ABOVE_SENSOR');
% check if the data is compatible with the QC algorithm
idMandatory = idHeight;
if ~idMandatory, return; end

Bins    = sample_data.dimensions{idHeight}.data';
idDepth = getVar(sample_data.variables, 'DEPTH');
depth = sample_data.variables{idDepth}.data;

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
propFile  = fullfile('AutomaticQC', 'imosSurfaceDetectionSetQC.txt');
ea_thresh = str2double(readProperty('ea_thresh',   propFile));
nBinSize = str2double(readProperty('nBinSize',   propFile));

% read dataset QC parameters if exist and override previous 
% parameters file
currentQCtest = mfilename;
ea_thresh = readDatasetParameter(sample_data.toolbox_input_file, currentQCtest, 'ea_thresh', ea_thresh);
nBinSize = readDatasetParameter(sample_data.toolbox_input_file, currentQCtest, 'nBinSize', nBinSize);

paramsLog = ['ea_thresh=' num2str(ea_thresh) ', nBinSize=' num2str(nBinSize)];

sizeCur = size(sample_data.variables{idUcur}.flags);

% same flags are given to any variable
flags = ones(sizeCur, 'int8')*rawFlag;

isUpwardLooking = true;
if all(Bins <= 0), isUpwardLooking = false; end
% we handle the case of a downward looking ADCP
if ~isUpwardLooking
    if isempty(sample_data.site_nominal_depth) && isempty(sample_data.site_depth_at_deployment)
        error(['Downward looking ADCP in file ' sample_data.toolbox_input_file ' => Fill site_nominal_depth or site_depth_at_deployment!']);
    else
        % the distance between transducer and obstacle is not depth anymore but
        % (site_nominal_depth - depth)
        if ~isempty(sample_data.site_nominal_depth)
        	site_nominal_depth = sample_data.site_nominal_depth;
        end
        if ~isempty(sample_data.site_depth_at_deployment)
        	site_nominal_depth = sample_data.site_depth_at_deployment;
        end
    end
end

% Run QC
% this test looks at the difference between consecutive vertical bin values of ea and
% if the value exceeds the threshold, then the bin fails, and all bins
% above it are also considered to have failed. This test is designed to get 
% rid of above/below surface/bottom bins.
lenTime = sizeCur(1);
lenBin  = sizeCur(2);
%Let's refine this to only look at bins within +/- 3 bins of the surface/bottom
% and profiles where the last bin reaches the surface/bottom
% currently assumes that there is a depth calcuated.
binDepth = depth - repmat(Bins,lenTime,1);
binRange = Bins(2) - Bins(1);
if isUpwardLooking
    isurface = binDepth <= 5*binRange ;
else
    isurface = binDepth >= site_nominal_depth - 5*binRange;
end

% if the following test is successfull, the bin gets good
ib = uint8(abs(diff(squeeze(ea(1, :,:)),1,2)) <= ea_thresh) + ...
     uint8(abs(diff(squeeze(ea(2, :,:)),1,2)) <= ea_thresh) + ...
     uint8(abs(diff(squeeze(ea(3, :,:)),1,2)) <= ea_thresh) + ...
     uint8(abs(diff(squeeze(ea(4, :,:)),1,2)) <= ea_thresh);
 

% allow for NaNs in the ea - false fails where more than 1 beam has NaN
inan = isnan(abs(diff(squeeze(ea(1, :,:)),1,2))) + ...
     isnan(abs(diff(squeeze(ea(2, :,:)),1,2))) + ...
     isnan(abs(diff(squeeze(ea(3, :,:)),1,2))) + ...
     isnan(abs(diff(squeeze(ea(4, :,:)),1,2)));

% we look for the bins where all bins pass the tests, as we know the depth
% and we know where the surface is, so any beam that sees is indicates
% where bad data is.
ib = ib + uint8(inan) == 4; %these are 'good', no beam sees the surface/bottom
ib = [true(lenTime, 1), ib]; %add one row at the start to account for diff
ib(~isurface) = 4; % bins not within 5*binRange of surface or bottom do not fail
 
% any good bin further than a bad one should be set bad
jkf = repmat(single(1:1:lenBin), [lenTime, 1]);

iii = single(~ib).*jkf;
iii(iii == 0) = NaN;
iif = min(iii, [], 2);
iifNotNan = ~isnan(iif);

iPass = true(lenTime, lenBin);
if any(iifNotNan)
    % all bins further than the first bad one is reset to bad
    iPass(jkf >= repmat(iif, [1, lenBin])) = false;
end
clear iifNotNan iif jkf ib iii

% finally, tidy up bins that still have good data above the surface with
% the side-lobe test:
% calculate contaminated depth
%
% http://www.nortekusa.com/usa/knowledge-center/table-of-contents/doppler-velocity#Sidelobes
%
% by default substraction of 1/2*BinSize to the non-contaminated height in order to be
% conservative and be sure that the first bin below the contaminated depth
% hasn't been computed from any contaminated signal.
% read in filter parameters
BinSize = sample_data.meta.binSize;
ipass = single(iPass).*binDepth; %bin depths that pass

if isUpwardLooking
    distanceTransducerToObstacle = depth;
    cDepth = distanceTransducerToObstacle - (distanceTransducerToObstacle * cos(sample_data.meta.beam_angle*pi/180) - nBinSize*BinSize);
else
    distanceTransducerToObstacle=site_nominal_depth - depth;
    cDepth = site_nominal_depth - (distanceTransducerToObstacle - (distanceTransducerToObstacle * cos(sample_data.meta.beam_angle*pi/180) - nBinSize*BinSize));
end
cd = repmat(cDepth, [1, length(Bins)]);

% test bins depths against contaminated depth
% where ibad, apply the cDepth cutoff:
if isUpwardLooking
    % upward looking : all bins above the contaminated depth are flagged,
    % except where the maximum bin depth is > 0
    ipass(ipass < cd & ipass <= 0 + binRange)  = NaN;
else
    % downward looking : all bins below the contaminated depth are flagged,
    % except where the maximum bin depth is < bottom
    ipass(ipass > cd & ipass >= site_nominal_depth - binRange)  = NaN;
end

%ipass is a matrix of depths that passes
%fix the pass/fail
ipass(ipass==0) = NaN;
iPass = ~isnan(ipass);
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

% write/update dataset QC parameters
writeDatasetParameter(sample_data.toolbox_input_file, currentQCtest, 'ea_thresh', ea_thresh);
writeDatasetParameter(sample_data.toolbox_input_file, currentQCtest, 'nBinSize', nBinSize);

end
