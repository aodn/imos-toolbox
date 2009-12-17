function [sample_data] = teledyneSetQC( sample_data )
%TELEDYNESETQC Quality control procedure for Teledyne Workhorse (and similar) 
% ADCP instrument data.
%
% Quality control procedure for Teledyne Workhorse (and similar) ADCP 
% instrument data.
%
% Inputs:
%   sample_data - struct containing the entire data set and dimension data.
%
% Outputs:
%   sample_data - same as input, with QC flags added for variable/dimension 
%                 data.
%
% Author: Brad Morris   <b.morris@unsw.edu.au>   (Implementation)
%         Paul McCarthy <paul.mccarthy@csiro.au> (Integration into toolbox)
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
  error(nargchk(1, 1, nargin));
  if ~isstruct(sample_data), error('sample_data must be a struct'); end
  
  qcSet = str2num(readProperty('toolbox.qc_set'));
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
  Bins=adcp.dimensions{2}.data';

  %Pull out pressure and calculate array of depth bins
  kk=strmatch('PRES',n);
  ff=union(find(var(kk).flags==rawFlag), find(var(kk).flags==goodFlag));
  pressure=var(kk).data(ff);
  bdepth=(pressure/1e6)*ones(1,length(Bins))-ones(length(pressure),1)*Bins;

  %Pull out horizontal velocities
  uIdx=strmatch('UCUR',n);
  vIdx=strmatch('VCUR',n);
  u=fliplr(var(uIdx).data(ff,:))+1i*fliplr(var(vIdx).data(ff,:));

  %Pull out vertical velocities
  kk=strmatch('WCUR',n);
  w=fliplr(var(kk).data(ff,:));

  %Pull out error velocities
  kk=strmatch('ECUR',n);
  erv=fliplr(var(kk).data(ff,:));

  %Pull out percent good/echo amplitude/correlation magnitude
  for j=1:4;
    cc = int2str(j);
    kk=strmatch(['ADCP_GOOD_' cc],n);
    eval(['qc(',cc,').pg=fliplr(var(kk).data(ff,:));'])

    kk=strmatch(['ABSI_' cc],n);
    eval(['qc(',cc,').ea=fliplr(var(kk).data(ff,:));'])

    kk=strmatch(['ADCP_CORR_' cc],n);
    eval(['qc(',cc,').cr=fliplr(var(kk).data(ff,:));'])
  end

  %Standard 300Mhz Workhorse Settings
  %(these will need to adjustable as they change with instrument type)
  qcthresh.err_vel=0.15;  %test 1
  qcthresh.pgood=50;   %test 2
  qcthresh.cmag=110;  %test 3
  qcthresh.vvel=0.2;    % test 4
  qcthresh.hvel=2.0;   %test 5
  qcthresh.ea_thresh=30;   %test 6

  %Run QC
  [ifail] = adcpqctest(qcthresh,qc,u,w,erv);

  %Clean up above-surface bins
  sCutOff=2*BinSize;%This will also need to be adjustable
  for k=1:size(bdepth,2)
    jjr=find(bdepth(:,k)<=sCutOff);
    if ~isempty(jjr)
      ifail(jjr,k)=1;
    end
  end

  %Run QC filter (ifail) on velocity data
  sample_data.variables{uIdx}.flags(fliplr(ifail)) = badFlag;
  sample_data.variables{vIdx}.flags(fliplr(ifail)) = badFlag;
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
