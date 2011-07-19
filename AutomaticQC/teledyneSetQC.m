function [sample_data] = teledyneSetQC( sample_data, auto )
%TELEDYNESETQC Quality control procedure for Teledyne Workhorse (and similar)
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
%
% Author:       Brad Morris   <b.morris@unsw.edu.au>   (Implementation)
%               Paul McCarthy <paul.mccarthy@csiro.au> (Integration into toolbox)
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

%BDM - 13/08/2010 - Added code to check if the data is from a Teledyne RD
%ADCP, if not returns.
if auto
    if ~strcmp('Teledyne RD Workhorse ADCP',sample_data.source), return; end
end

qcSet = str2double(readProperty('toolbox.qc_set'));
badFlag  = imosQCFlag('bad',  qcSet, 'flag');
goodFlag = imosQCFlag('good', qcSet, 'flag');
rawFlag  = imosQCFlag('raw',  qcSet, 'flag');

adcp = sample_data;

%Get variable names
for ii=1:size(adcp.variables,2)
    var(ii)=adcp.variables{ii};
    n{ii}=var(ii).name;
end

%Pull out ADCP bin details
BinSize=adcp.meta.fixedLeader.depthCellLength/100;
Bins=getVar(sample_data.dimensions, 'HEIGHT_ABOVE_SENSOR');
Bins=adcp.dimensions{Bins}.data';

%BDM - 16/08/2010 - Added if statement below to take into account ADCPs
%without pressure records. Use mean of nominal water depth minus sensor height.

%Pull out pressure and calculate array of depth bins
kk=strcmp('PRES',n);
if ~any(kk)
    kk=strcmp('TEMP',n);
    ff=union(find(var(kk).flags==rawFlag), find(var(kk).flags==goodFlag));
    
    if isempty(adcp.geospatial_vertical_max)
        error('No pressure data in file => Fill geospatial_vertical_max!');
    else
        pressure=ones(size(var(kk).data(ff),1),1).*(adcp.geospatial_vertical_max);
    end
    disp('Using nominal depth')
else
    ff=union(find(var(kk).flags==rawFlag), find(var(kk).flags==goodFlag));
    pressure=var(kk).data(ff);
end

%BDM (07/04/2010) - Bug fix due to scaling of pressure! Was originally setup to scale for pressure in mm.
%   bdepth=(pressure/1e6)*ones(1,length(Bins))-ones(length(pressure),1)*Bins;
bdepth=pressure*ones(1,length(Bins))-ones(length(pressure),1)*Bins;

%Pull out horizontal velocities
uIdx=strcmp('UCUR',n);
vIdx=strcmp('VCUR',n);
u=var(uIdx).data(ff,:)+1i*var(vIdx).data(ff,:);

%Pull out vertical velocities
kk=strcmp('WCUR',n);
w=var(kk).data(ff,:);

%Pull out error velocities
kk=strcmp('ECUR',n);
erv=var(kk).data(ff,:);

%Pull out percent good/echo amplitude/correlation magnitude
for j=1:4;
    cc = int2str(j);
    kk=strcmp(['ADCP_GOOD_' cc],n);
    eval(['qc(',cc,').pg=var(kk).data(ff,:);'])
    
    kk=strcmp(['ABSI_' cc],n);
    eval(['qc(',cc,').ea=var(kk).data(ff,:);'])
    
    kk=strcmp(['ADCP_CORR_' cc],n);
    eval(['qc(',cc,').cr=var(kk).data(ff,:);'])
end

% read in filter parameters
propFile = fullfile('AutomaticQC', 'teledyneSetQC.txt');
qcthresh.err_vel   = str2double(readProperty('err_vel',   propFile));
qcthresh.pgood     = str2double(readProperty('pgood',     propFile));
qcthresh.cmag      = str2double(readProperty('cmag',      propFile));
qcthresh.vvel      = str2double(readProperty('vvel',      propFile));
qcthresh.hvel      = str2double(readProperty('hvel',      propFile));
qcthresh.ea_thresh = str2double(readProperty('ea_thresh', propFile));
sCutOff            = str2double(readProperty('cutoff',    propFile));

%Run QC
[ifail] = adcpqctest(qcthresh,qc,u,w,erv);

%Clean up above-surface bins
%Edited to correct above surface bin cutoff, it is a function of bin size, i.e. sCutOff=2*BinSize;
%BDM (08/04/2010)
for k=1:size(bdepth,2)
    %     jjr=find(bdepth(:,k)<=sCutOff);
    jjr=find(bdepth(:,k)<=sCutOff*BinSize);
    if ~isempty(jjr)
        ifail(jjr,k)=1;
    end
end

%Run QC filter (ifail) on velocity data
%Need to take into account that we only used an inwater subset of the adcp
%data thus ifail is indexed to this subset!!!
%This is clumsy but works, probably a more elegant way to do this!
for k=1:size(ifail,2)
    sample_data.variables{uIdx}.flags(ff(ifail(:,k)),k) = badFlag;
    sample_data.variables{vIdx}.flags(ff(ifail(:,k)),k) = badFlag;
end
% sample_data.variables{uIdx}.flags(ifail) = badFlag;
% sample_data.variables{vIdx}.flags(ifail) = badFlag;
end

function [ifail] = adcpqctest(qcthresh,qc,u,w,erv)
%[ifail] = adcpqctest(qcthresh,qc,u,w,erv)
% Inputs: a structure of thresholds for each of the following:
%   qcthresh.errvel  :  error velocity
%   qcthresh.pgood   :  percent good from 4-beam solutions
%   qcthresh.cmag    :  correlation magnitude
%   qcthresh.vvel    :  vertical velocity
%   qcthresh.hvel    :  horizontal velocity
%   qcthresh.ea      :  echo amplitude

err_vel = qcthresh.err_vel;  %test 1
pgood =qcthresh.pgood;   %test 2
cmag = qcthresh.cmag;    %test 3
vvel = qcthresh.vvel;    % test 4
hvel = qcthresh.hvel;   %test 5
ea_thresh = qcthresh.ea_thresh;   %test 6
clear ib* isub* ifb ifail*
%test 1, Error Velocity test
% measurement of disagreement of measurement estimates of opposite beams.
% Derived from 2 idpt beams and therefore is 2 indp measures of vertical
% velocity
ib1 = abs(erv) >= err_vel;

%test 2, Percent Good test for Long ranger, use only
%good for 4 beam solutions (ie pg(4))
%use 4 as it is the percentage of measurements that have 4 beam solutions
ib2 = qc(4).pg < pgood;

% Test 3, correlation magnitude test
isub1 = (qc(1).cr<=cmag);
isub2 = (qc(2).cr<=cmag);
isub3 = (qc(3).cr<=cmag);
isub4 = (qc(4).cr<=cmag);
% test nbins bins
isub_all = isub1+isub2+isub3+isub4;

% assign pass(0) or fail(1) values
% Where 3 or more beams fail, then the cmag test is failed
ib3 = isub_all >= 3;

% Test 4, Vertical velocity test
ib4 = abs(w) >= vvel;

% Test 5, Horizontal velocity test
ib5 = abs(u) >= hvel;

%Test 6, Echo Amplitude test
% this test looks at the difference between consecutive bin values of ea and
% if the value exceeds the threshold, then the bin fails, and all bins
% above this are also considered to have failed.
% This test is only applied from the middle bin to the end bin, since it is
% a test designed to get rid of surface bins
[ii,jj] = size(u);
ib6=zeros(size(u));
ik = round(jj/2);

for it=1:length(erv)
    ib = (diff(qc(1).ea(it,ik:jj),1,2)>ea_thresh)+ ...
        (diff(qc(2).ea(it,ik:jj),1,2)>ea_thresh)+ ...
        (diff(qc(3).ea(it,ik:jj),1,2)>ea_thresh)+ ...
        (diff(qc(4).ea(it,ik:jj),1,2)>ea_thresh);
    ifb = find(ib>=1);
    if(ifb)
        
        ib6(it,ik+ifb(1):jj) = 1;
    end
end

%Find the number that fail the first five tests
ib7 = ib1 + ib2 + ib3 + ib4 + ib5;
ifail1 = ib7 >= 2;

ifail2 = ifail1 + ib6;
ifail = ifail2 >= 1;

end
