function [sample_data, varChecked, paramsLog] = imosTeledyneSetQC( sample_data, auto )
%IMOSTELEDYNESETQC Quality control procedure for Teledyne Workhorse (and similar)
% ADCP instrument data.
%
% Quality control procedure for Teledyne Workhorse (and similar) ADCP
% instrument data.
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
error(nargchk(1, 2, nargin));
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
idADCP_GOOD = cell(4, 1);
idABSI      = cell(4, 1);
idADCP_CORR = cell(4, 1);
for j=1:4
    idADCP_GOOD{j}  = 0;
    idABSI{j}       = 0;
    idADCP_CORR{j}  = 0;
end
lenVar = size(sample_data.variables,2);
for i=1:lenVar
    if strcmpi(sample_data.variables{i}.name, 'UCUR'), idUcur = i; end
    if strcmpi(sample_data.variables{i}.name, 'VCUR'), idVcur = i; end
    if strcmpi(sample_data.variables{i}.name, 'WCUR'), idWcur = i; end
    if strcmpi(sample_data.variables{i}.name, 'ECUR'), idEcur = i; end
    if strcmpi(sample_data.variables{i}.name, 'CSPD'), idCspd = i; end
    if strcmpi(sample_data.variables{i}.name, 'CDIR'), idCdir = i; end
    for j=1:4
        cc = int2str(j);
        if strcmpi(sample_data.variables{i}.name, ['ADCP_GOOD_' cc]),   idADCP_GOOD{j}  = i; end
        if strcmpi(sample_data.variables{i}.name, ['ABSI_' cc]),        idABSI{j}       = i; end
        if strcmpi(sample_data.variables{i}.name, ['ADCP_CORR_' cc]),   idADCP_CORR{j}  = i; end
    end
end

% check if the data is compatible with the QC algorithm
idMandatory = idHeight & idUcur & idVcur & idWcur & idEcur;
for j=1:4
    idMandatory = idMandatory & idADCP_GOOD{j} & idABSI{j} & idADCP_CORR{j};
end
if ~idMandatory, return; end


qcSet = str2double(readProperty('toolbox.qc_set'));
badFlag  = imosQCFlag('bad',  qcSet, 'flag');
goodFlag = imosQCFlag('good', qcSet, 'flag');
rawFlag  = imosQCFlag('raw',  qcSet, 'flag');

%Pull out horizontal velocities
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
    pg = sample_data.variables{idADCP_GOOD{j}}.data;
    qc(j).pg = pg;
    ea = sample_data.variables{idABSI{j}}.data;
    qc(j).ea = ea;
    cr = sample_data.variables{idADCP_CORR{j}}.data;
    qc(j).cr = cr;
end

% read in filter parameters
propFile = fullfile('AutomaticQC', 'imosTeledyneSetQC.txt');
qcthresh.err_vel   = str2double(readProperty('err_vel',   propFile));
qcthresh.pgood     = str2double(readProperty('pgood',     propFile));
qcthresh.cmag      = str2double(readProperty('cmag',      propFile));
qcthresh.vvel      = str2double(readProperty('vvel',      propFile));
qcthresh.hvel      = str2double(readProperty('hvel',      propFile));
qcthresh.ea_thresh = str2double(readProperty('ea_thresh', propFile));

paramsLog = ['err_vel=' num2str(qcthresh.err_vel) ', pgood=' num2str(qcthresh.pgood) ...
    ', cmag=' num2str(qcthresh.cmag) ', vvel=' num2str(qcthresh.vvel) ...
    ', hvel=' num2str(qcthresh.hvel) ', ea_thresh=' num2str(qcthresh.ea_thresh)];

%Run QC
[iPass] = adcpqctest(qcthresh,qc,u,w,erv);
iFail = ~iPass;

sizeCur = size(sample_data.variables{idUcur}.flags);

% same flags are given to any variable
flags = ones(sizeCur)*rawFlag;

%Run QC filter (iFail) on velocity data
flags(iFail) = badFlag;
flags(~iFail) = goodFlag;

sample_data.variables{idUcur}.flags = flags;
sample_data.variables{idVcur}.flags = flags;
sample_data.variables{idWcur}.flags = flags;

varChecked = {'UCUR', 'VCUR', 'WCUR'};

if any(idCspd)
    sample_data.variables{idCspd}.flags = flags;
    varChecked = [varChecked, {'CSPD'}];
end

if any(idCdir)
    sample_data.variables{idCdir}.flags = flags;
    varChecked = [varChecked, {'CDIR'}];
end

end

function [iPass] = adcpqctest(qcthresh,qc,u,w,erv)
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

%test 1, Error Velocity test
% measurement of disagreement of measurement estimates of opposite beams.
% Derived from 2 idpt beams and therefore is 2 indp measures of vertical
% velocity
ib1 = abs(erv) < err_vel;

%test 2, Percent Good test for Long ranger, use only
%good for 4 beam solutions (ie pg(4))
%use 4 as it is the percentage of measurements that have 4 beam solutions
ib2 = qc(4).pg >= pgood;

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
ib4 = abs(w) < vvel;

% Test 5, Horizontal velocity test
ib5 = abs(u) < hvel;

%Test 6, Echo Amplitude test
% this test looks at the difference between consecutive vertical bin values of ea and
% if the value exceeds the threshold, then the bin fails, and all bins
% above this are also considered to have failed.
% This test is only applied from the middle bin to the end bin, since it is
% a test designed to get rid of surface bins
[lenTime, lenBin] = size(u);
halfLenBin = round(lenBin/2);

% if the following test is successfull, the bin gets good
ib = (abs(diff(qc(1).ea(:,halfLenBin:lenBin),1,2)) <= ea_thresh) & ...
     (abs(diff(qc(2).ea(:,halfLenBin:lenBin),1,2)) <= ea_thresh) & ...
     (abs(diff(qc(3).ea(:,halfLenBin:lenBin),1,2)) <= ea_thresh) & ...
     (abs(diff(qc(4).ea(:,halfLenBin:lenBin),1,2)) <= ea_thresh);
 
ib = [true(lenTime, lenBin-size(ib, 2)), ib];

% however, any good bin over a bad one should have stayed bad
jkf = repmat((1:1:lenBin), lenTime, 1);

iii = double(~ib).*jkf;
clear ib;
iii(iii == 0) = NaN;
iif = min(iii, [], 2);
clear iii;
iifNotNan = ~isnan(iif);

if any(iifNotNan)
    ib6 = true(lenTime, lenBin);
    % all bins above the first bad one is reset to bad
    ib6(jkf >= repmat(iif, 1, lenBin)) = false;
end

%Find the number that fail the first five tests
ib7 = ib1 + ib2 + ib3 + ib4 + ib5;
iPass1 = ib7 >= 4;

iPass2 = iPass1 + ib6;

iPass = iPass2 >= 2;

end
