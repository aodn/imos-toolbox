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
idPERG = cell(4, 1);
idABSI = cell(4, 1);
idCMAG = cell(4, 1);
for j=1:4
    idPERG{j}  = 0;
    idABSI{j}  = 0;
    idCMAG{j}  = 0;
end
lenVar = size(sample_data.variables, 2);
for i=1:lenVar
    % let's handle the case where same current params 
    % are distinguished by "_1" and "_2"
    paramName = sample_data.variables{i}.name;
    
    if strcmpi(paramName, 'UCUR_MAG'),  idUcur(1)   = i; end
    if strcmpi(paramName, 'UCUR'),      idUcur(2)   = i; end
    if strcmpi(paramName, 'UCUR_1'),    idUcur(2)   = i; end % PARAM and PARAM_1 shouldn't be possible
    if strcmpi(paramName, 'UCUR_2'),    idUcur(3)   = i; end
    
    if strcmpi(paramName, 'VCUR_MAG'),  idVcur(1)   = i; end
    if strcmpi(paramName, 'VCUR'),      idVcur(2)   = i; end
    if strcmpi(paramName, 'VCUR_1'),    idVcur(2)   = i; end
    if strcmpi(paramName, 'VCUR_2'),    idVcur(3)   = i; end
    
    if strcmpi(paramName, 'WCUR'),      idWcur      = i; end
    if strcmpi(paramName, 'ECUR'),      idEcur      = i; end
    if strcmpi(paramName, 'CSPD'),      idCspd      = i; end
    
    if strcmpi(paramName, 'CDIR_MAG'),  idCdir(1)   = i; end
    if strcmpi(paramName, 'CDIR'),      idCdir(2)   = i; end
    if strcmpi(paramName, 'CDIR_1'),    idCdir(2)   = i; end
    if strcmpi(paramName, 'CDIR_2'),    idCdir(3)   = i; end
    for j=1:4
        cc = int2str(j);
        if strcmpi(paramName, ['PERG' cc]), idPERG{j} = i; end
        if strcmpi(paramName, ['ABSI' cc]), idABSI{j} = i; end
        if strcmpi(paramName, ['CMAG' cc]), idCMAG{j} = i; end
    end
end

% check if the data is compatible with the QC algorithm
idMandatory = idHeight & idUcur(1) & idVcur(1) & idWcur & idEcur; % PARAM_MAG will always be there first
for j=1:4
    idMandatory = idMandatory & idPERG{j} & idABSI{j} & idCMAG{j};
end
if ~idMandatory, return; end


qcSet = str2double(readProperty('toolbox.qc_set'));
badFlag  = imosQCFlag('bad',  qcSet, 'flag');
goodFlag = imosQCFlag('good', qcSet, 'flag');
rawFlag  = imosQCFlag('raw',  qcSet, 'flag');

%Pull out horizontal velocities
% we can afford to run the test only once (if couple of UCUR/VCUR) since u
% is only tested in absolute value (direction doesn't matter)
u = sample_data.variables{idUcur(1)}.data;
v = sample_data.variables{idVcur(1)}.data;
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

sizeCur = size(sample_data.variables{idWcur}.flags);

% same flags are given to any variable
flags = ones(sizeCur, 'int8')*rawFlag;

%Run QC
% we can afford to run the test only once (if couple of UCUR/VCUR) since u
% is only tested in absolute value (direction doesn't matter)
[iPass] = adcpqctest(qcthresh, qc, u, w, erv);
iFail = ~iPass;

%Run QC filter (iFail) on velocity data
flags(iFail) = badFlag;
flags(~iFail) = goodFlag;

nCurrentData = length(idUcur);
for i=1:nCurrentData
    sample_data.variables{idUcur(i)}.flags = flags;
    sample_data.variables{idVcur(i)}.flags = flags;
    
    varChecked = {sample_data.variables{idUcur(i)}.name, ...
        sample_data.variables{idVcur(i)}.name};
    
    if any(idCdir(1)) % if the first is identified then the folowing are as well
        sample_data.variables{idCdir(i)}.flags = flags;
        varChecked = [varChecked, {sample_data.variables{idCdir(i)}.name}];
    end
end

sample_data.variables{idWcur}.flags = flags;
varChecked = [varChecked, {'WCUR'}];

if any(idCspd)
    sample_data.variables{idCspd}.flags = flags;
    varChecked = [varChecked, {'CSPD'}];
end
    
end

function [iPass] = adcpqctest(qcthresh, qc, u, w, erv)
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
ib1 = abs(erv) <= err_vel;

%test 2, Percent Good test on 4 beam solution only
% in earth coordinate (!=beam coordinate) configuration, pg(1) is
% percent good of measurements with 3 beam solution and pg(4) is
% percent good of measurements with 4 beam solution.
ib2 = qc(4).pg > pgood;

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
ib4 = abs(w) <= vvel;

% Test 5, Horizontal velocity test
ib5 = abs(u) <= hvel;

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

ib6 = true(lenTime, lenBin);
if any(iifNotNan)
    % all bins above the first bad one is reset to bad
    ib6(jkf >= repmat(iif, 1, lenBin)) = false;
end

%Find the number that pass the first five tests
ib7 = ib1 + ib2 + ib3 + ib4 + ib5;
iPass1 = ib7 >= 4;

iPass2 = iPass1 + ib6;

iPass = iPass2 >= 2;

end
