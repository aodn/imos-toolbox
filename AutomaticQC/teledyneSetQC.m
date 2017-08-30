function [sample_data, varChecked, paramsLog] = teledyneSetQC( sample_data, auto )
%TELEDYNESETQC Quality control procedure for Teledyne Workhorse (and similar)
% ADCP instrument data.
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
% Author:       Brad Morris   <b.morris@unsw.edu.au>
%               Paul McCarthy <paul.mccarthy@csiro.au>
% Contributor:  Guillaume Galibert <guillaume.galibert@utas.edu.au>
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
idHeight = getVar(sample_data.dimensions, 'HEIGHT_ABOVE_SENSOR');
idUcur = 0;
idVcur = 0;
idWcur = 0;
idEcur = 0;
idCspd = 0;
idCdir = 0;
idPERG = cell(4, 1);
idABSI = cell(4, 1);
idCMAG = cell(4, 1);
for j=1:4
    idPERG{j}  = 0;
    idABSI{j}  = 0;
    idCMAG{j}  = 0;
end
lenVar = length(sample_data.variables);
for i=1:lenVar
    paramName = sample_data.variables{i}.name;
    
    if strncmpi(paramName, 'UCUR', 4),  idUcur = i; end
    if strncmpi(paramName, 'VCUR', 4),  idVcur = i; end
    if strcmpi(paramName, 'WCUR'),      idWcur = i; end
    if strcmpi(paramName, 'ECUR'),      idEcur = i; end
    if strcmpi(paramName, 'CSPD'),      idCspd = i; end
    if strncmpi(paramName, 'CDIR', 4),  idCdir = i; end
    for j=1:4
        cc = int2str(j);
        if strcmpi(paramName, ['PERG' cc]), idPERG{j} = i; end
        if strcmpi(paramName, ['ABSI' cc]), idABSI{j} = i; end
        if strcmpi(paramName, ['CMAG' cc]), idCMAG{j} = i; end
    end
end

% check if the data is compatible with the QC algorithm
idMandatory = idHeight & idUcur & idVcur & idWcur & idEcur;
for j=1:4
    idMandatory = idMandatory & idPERG{j} & idABSI{j} & idCMAG{j};
end
if ~idMandatory, return; end

% let's get the associated vertical dimension
idVertDim = sample_data.variables{idCMAG{1}}.dimensions(2);
if strcmpi(sample_data.dimensions{idVertDim}.name, 'DIST_ALONG_BEAMS')
    disp(['Warning : teledyneSetQC applied with non tilt-corrected CMAGn and ABSIn (no bin mapping) on dataset ' sample_data.toolbox_input_file]);
end

qcSet           = str2double(readProperty('toolbox.qc_set'));
badFlag         = imosQCFlag('bad',             qcSet, 'flag');
goodFlag        = imosQCFlag('good',            qcSet, 'flag');
probGoodFlag    = imosQCFlag('probablyGood',    qcSet, 'flag');
rawFlag         = imosQCFlag('raw',             qcSet, 'flag');

%Pull out horizontal velocities
% we can afford to run the test only once (if couple of UCUR/VCUR) since u
% is only tested in absolute value (direction doesn't matter)
u = sample_data.variables{idUcur}.data;
v = sample_data.variables{idVcur}.data;
u = u + 1i*v;
clear v;

%Pull out vertical velocities
w = sample_data.variables{idWcur}.data;

%Pull out error velocities
erv = sample_data.variables{idEcur}.data;

%Pull out percent good/echo amplitude/correlation magnitude
qc = struct;
for j=1:4;
    pg = sample_data.variables{idPERG{j}}.data;
    qc(j).pg = pg;
    ea = sample_data.variables{idABSI{j}}.data;
    qc(j).ea = ea;
    cr = sample_data.variables{idCMAG{j}}.data;
    qc(j).cr = cr;
end

% read in filter parameters
propFile = fullfile('AutomaticQC', 'teledyneSetQC.txt');
qcthresh.err_vel   = str2double(readProperty('err_vel',   propFile));
qcthresh.pgood     = str2double(readProperty('pgood',     propFile));
qcthresh.cmag      = str2double(readProperty('cmag',      propFile));
qcthresh.vvel      = str2double(readProperty('vvel',      propFile));
qcthresh.hvel      = str2double(readProperty('hvel',      propFile));
qcthresh.ea_thresh = str2double(readProperty('ea_thresh', propFile));

% read dataset QC parameters if exist and override previous 
% parameters file
currentQCtest   = mfilename;
qcthresh.err_vel    = readDatasetParameter(sample_data.toolbox_input_file, currentQCtest, 'err_vel',     qcthresh.err_vel);
qcthresh.pgood      = readDatasetParameter(sample_data.toolbox_input_file, currentQCtest, 'pgood',       qcthresh.pgood);
qcthresh.cmag       = readDatasetParameter(sample_data.toolbox_input_file, currentQCtest, 'cmag',        qcthresh.cmag);
qcthresh.vvel       = readDatasetParameter(sample_data.toolbox_input_file, currentQCtest, 'vvel',        qcthresh.vvel);
qcthresh.hvel       = readDatasetParameter(sample_data.toolbox_input_file, currentQCtest, 'hvel',        qcthresh.hvel);
qcthresh.ea_thresh  = readDatasetParameter(sample_data.toolbox_input_file, currentQCtest, 'ea_thresh',   qcthresh.ea_thresh);

paramsLog = ['err_vel=' num2str(qcthresh.err_vel) ', pgood=' num2str(qcthresh.pgood) ...
    ', cmag=' num2str(qcthresh.cmag) ', vvel=' num2str(qcthresh.vvel) ...
    ', hvel=' num2str(qcthresh.hvel) ', ea_thresh=' num2str(qcthresh.ea_thresh)];

sizeCur = size(sample_data.variables{idWcur}.flags);

% same flags are given to any variable
flags = ones(sizeCur, 'int8')*rawFlag;

%Run QC
% we can afford to run the test only once (if couple of UCUR/VCUR) since u
% is only tested in absolute value (direction doesn't matter)
[iPass, iNaNerv] = adcpqctest(qcthresh, qc, u, w, erv);
iFail = ~iPass;

%Run QC filter (iFail) on velocity data
flags(iFail) = badFlag;
flags(iPass) = goodFlag;

% If the cell contains a NaN in the error velocity test, but doesn’t fail
% any other test, flag the data as level 2 (Probably good data).
flags(iPass & iNaNerv) = probGoodFlag;

sample_data.variables{idUcur}.flags = flags;
sample_data.variables{idVcur}.flags = flags;

varChecked = {sample_data.variables{idUcur}.name, ...
    sample_data.variables{idVcur}.name};

if idCdir
    sample_data.variables{idCdir}.flags = flags;
    varChecked = [varChecked, {sample_data.variables{idCdir}.name}];
end

sample_data.variables{idWcur}.flags = flags;
varChecked = [varChecked, {sample_data.variables{idWcur}.name}];

if idCspd
    sample_data.variables{idCspd}.flags = flags;
    varChecked = [varChecked, {sample_data.variables{idCspd}.name}];
end

% write/update dataset QC parameters
writeDatasetParameter(sample_data.toolbox_input_file, currentQCtest, 'err_vel',  qcthresh.err_vel);
writeDatasetParameter(sample_data.toolbox_input_file, currentQCtest, 'pgood',    qcthresh.pgood);
writeDatasetParameter(sample_data.toolbox_input_file, currentQCtest, 'cmag',     qcthresh.cmag);
writeDatasetParameter(sample_data.toolbox_input_file, currentQCtest, 'vvel',     qcthresh.vvel);
writeDatasetParameter(sample_data.toolbox_input_file, currentQCtest, 'hvel',     qcthresh.hvel);
writeDatasetParameter(sample_data.toolbox_input_file, currentQCtest, 'ea_thresh',qcthresh.ea_thresh);
        
end

function [iPass, iNaNerv] = adcpqctest(qcthresh, qc, u, w, erv)
%[iPass] = adcpqctest(qcthresh,qc,u,w,erv)
% Inputs: a structure of thresholds for each of the following:
%   qcthresh.errvel  :  error velocity
%   qcthresh.pgood   :  percent good from 4-beam solutions
%   qcthresh.cmag    :  correlation magnitude
%   qcthresh.vvel    :  vertical velocity
%   qcthresh.hvel    :  horizontal velocity
%   qcthresh.ea      :  echo amplitude

err_vel   = qcthresh.err_vel;   %test 1
pgood     = qcthresh.pgood;     %test 2
cmag      = qcthresh.cmag;      %test 3
vvel      = qcthresh.vvel;      %test 4
hvel      = qcthresh.hvel;      %test 5
ea_thresh = qcthresh.ea_thresh; %test 6
clear ib* isub* ifb iFail*

% Test 1, Error Velocity test
% measurement of disagreement of measurement estimates of opposite beams.
% Derived from 2 idpt beams and therefore is 2 indp measures of vertical
% velocity
iNaNerv = isnan(erv);
ib1 = abs(erv) <= err_vel;
ib1(iNaNerv) = true; % we don't want NaN values to interfer in the tier 2 test

% Test 2, Percent Good test on 3 and 4 beam solutions
% in earth coordinate (!=beam coordinate) configuration, pg(1) is
% percent good of measurements with 3 beam solution and pg(4) is
% percent good of measurements with 4 beam solution.
ib2 = qc(1).pg + qc(4).pg > pgood;

% Test 3, correlation magnitude test
isub1 = (qc(1).cr > cmag);
isub2 = (qc(2).cr > cmag);
isub3 = (qc(3).cr > cmag);
isub4 = (qc(4).cr > cmag);
% test nbins bins
isub_all = isub1+isub2+isub3+isub4;

% assign pass(1) or fail(0) values
% Where 2 or more beams pass, then the cmag test is passed
ib3 = isub_all >= 2;
clear isub1 isub2 isub3 isub4 isub_all;

% Test 4, Vertical velocity test
iNaN = isnan(w);
ib4 = abs(w) <= vvel;
ib4(iNaN) = true; % we don't want NaN values to interfer in the tier 2 test
clear iNaN;

% Test 5, Horizontal velocity test
iNaN = isnan(u);
ib5 = abs(u) <= hvel;
ib5(iNaN) = true; % we don't want NaN values to interfer in the tier 2 test
clear iNaN;

% Test 6, Echo Amplitude test
% this test looks at the difference between consecutive vertical bin values of ea and
% if the value exceeds the threshold, then the bin fails, and all bins
% above this are also considered to have failed.
% This test designed to get rid of surface/bottom bins.
[lenTime, lenBin] = size(u);

% if the following test is successfull, the bin gets good
ib = uint8(diff(qc(1).ea(:,:),1,2) <= ea_thresh) + ...
     uint8(diff(qc(2).ea(:,:),1,2) <= ea_thresh) + ...
     uint8(diff(qc(3).ea(:,:),1,2) <= ea_thresh) + ...
     uint8(diff(qc(4).ea(:,:),1,2) <= ea_thresh);

% we look for the bins that have 3 or more beams that pass the tests
ib = ib >= 3;
 
% we assume the first bin is good
ib = [true(lenTime, 1), ib];
 
% however, any good bin further than a bad one should have stayed bad
jkf = repmat(single(1:1:lenBin), [lenTime, 1]);

iii = single(~ib).*jkf;
clear ib;
iii(iii == 0) = NaN;
iif = min(iii, [], 2);
clear iii;
iifNotNan = ~isnan(iif);

ib6 = true(lenTime, lenBin);
if any(iifNotNan)
    % all bins further than the first bad one is reset to bad
    ib6(jkf >= repmat(iif, [1, lenBin])) = false;
end
clear iifNotNan iif jkf;

% if less than 50% of the bins in the water column (test 6) in a profile have passed all of the first
% 5 tests then the entire profile fails.
iPass1 = ib1 & ib2 & ib3 & ib4 & ib5;

ib7 = iPass1;
ib7(~ib6) = false; % override any bin outside the water column with a fail

nTotalBinWaterColumn = sum(ib6, 2);
nGoodBinWaterColumn  = sum(ib7, 2);
clear ib7;

iPass2 = nGoodBinWaterColumn >= nTotalBinWaterColumn/2;
clear nGoodBinBelowSurface nTotalBinBelowSurface;

iPass = iPass1 & ib6; % every single test is passed
clear ib6 iPass1;

iPass(~iPass2, :) = false; % we flag a whole profile bad when relevant
clear iPass2;

end
