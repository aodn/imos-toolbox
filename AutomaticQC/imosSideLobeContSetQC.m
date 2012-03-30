function [sample_data] = imosSideLobeContSetQC( sample_data, auto )
%IMOSSIDELOBECONTSETQC Quality control procedure for ADCP instrument data.
%
% Quality control ADCP instrument data, assessing the side lobe effects on 
% the cells close to the surface.
%
% Following Hrvoje Mihanovic recommendations :
% The beam emitted from the transducer is not an ideal
% line, it has a certain 3D structure with the main lobe and side lobes.
% Some of the side lobes are emitted perpendicularly towards the surface.
% Therefore, the measurements become contaminated when that part of the beam
% reaches the surface, since the reflection on the surface influences
% information coming from the main lobe. If you plot a cirle around the ADCP
% with radius equalling the entire depth, you will see that as the
% perpendicular side lobe going perpendicularly towards the surface the main
% lobe (having a 20 degree angle for RDI and 25 for Nortek) reaches the
% height above the sensor corresponding to: depth*cos(beam angle).
%
% See also RDI documentation : 
% http://www.nortekusa.com/usa/knowledge-center/table-of-contents/doppler-velocity#Sidelobes
%
% Inputs:
%   sample_data - struct containing the entire data set and dimension data.
%   auto - logical, run QC in batch mode
%
% Outputs:
%   sample_data - same as input, with QC flags added for variable/dimension
%                 data.
%
% Author:       Guillaume Galibert <guillaume.galibert@utas.edu.au>
% Contributor:  Hrvoje Mihanovic <hrvoje.mihanovic@hhi.hr>
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

% get all necessary dimensions and variables id in sample_data struct
idHeight = getVar(sample_data.dimensions, 'HEIGHT_ABOVE_SENSOR');
idPres = 0;
idPresRel = 0;
idDepth = 0;
idUcur = 0;
idVcur = 0;
idWcur = 0;
lenVar = size(sample_data.variables,2);
for i=1:lenVar
    if strcmpi(sample_data.variables{i}.name, 'PRES'), idPres = i; end
    if strcmpi(sample_data.variables{i}.name, 'PRES_REL'), idPresRel = i; end
    if strcmpi(sample_data.variables{i}.name, 'DEPTH'), idDepth = i; end
    if strcmpi(sample_data.variables{i}.name, 'UCUR'), idUcur = i; end
    if strcmpi(sample_data.variables{i}.name, 'VCUR'), idVcur = i; end
    if strcmpi(sample_data.variables{i}.name, 'WCUR'), idWcur = i; end
end

% check if the data is compatible with the QC algorithm
idMandatory = idHeight & idUcur & idVcur & idWcur;

if ~idMandatory, return; end

qcSet = str2double(readProperty('toolbox.qc_set'));
badFlag  = imosQCFlag('bad',  qcSet, 'flag');
goodFlag = imosQCFlag('good', qcSet, 'flag');
rawFlag  = imosQCFlag('raw',  qcSet, 'flag');

%Pull out ADCP bin details
BinSize = sample_data.meta.fixedLeader.depthCellLength/100;
Bins    = sample_data.dimensions{idHeight}.data';

%BDM - 16/08/2010 - Added if statement below to take into account ADCPs
%without pressure records. Use mean of nominal water depth minus sensor height.

%Pull out pressure and calculate array of depth bins
if idPres == 0 && idPresRel == 0 && idDepth == 0
    lenData = size(sample_data.variables{idUcur}.flags, 1);
    ff = true(lenData, 1);
    
    if isempty(sample_data.instrument_nominal_depth)
        error('No pressure data in file => Fill instrument_nominal_depth!');
    else
        pressure = ones(lenData, 1).*(sample_data.instrument_nominal_depth);
        disp('Warning : imosSideLobeContSetQC uses nominal depth because no pressure data in file')
    end
elseif idPres ~= 0 || idPresRel ~= 0
    if idPresRel == 0
        ff = (sample_data.variables{idPres}.flags == rawFlag) | ...
            (sample_data.variables{idPres}.flags == goodFlag);
        % relative pressure is used to compute depth
        pressure = sample_data.variables{idPres}.data - 10.1325;
    else
        ff = (sample_data.variables{idPresRel}.flags == rawFlag) | ...
            (sample_data.variables{idPresRel}.flags == goodFlag);
        pressure = sample_data.variables{idPresRel}.data;
    end
end

if idDepth == 0
    % assuming 1 dbar = 1 m, computing depth of each bin
    depth = pressure;
else
    ff = (sample_data.variables{idDepth}.flags == rawFlag) | ...
            (sample_data.variables{idDepth}.flags == goodFlag);
    depth = sample_data.variables{idDepth}.data;
end

% let's take into account QC information
if any(~ff)
    if isempty(sample_data.instrument_nominal_depth)
        error('Bad pressure/depth data in file => Fill instrument_nominal_depth!');
    else
        depth(~ff) = sample_data.instrument_nominal_depth;
        disp('Warning : imosSideLobeContSetQC uses nominal depth instead of pressure/depth data flagged as not ''good'' in file')
    end
end

% calculate contaminated depth
%
% http://www.nortekusa.com/usa/knowledge-center/table-of-contents/doppler-velocity#Sidelobes
%
% substraction of 2*BinSize to the non-contaminated height in order to be
% conservative and be sure that the first bin below the contaminated depth
% hasn't been computed from any contaminated signal.
cDepth = depth - (depth * cos(sample_data.meta.beam_angle*pi/180) - 2*BinSize);

% calculate bins depth
binDepth = depth*ones(1,length(Bins)) - ones(length(depth),1)*Bins;

sizeCur = size(sample_data.variables{idUcur}.flags);

% same flags are given to any U, V or W variable
flags = ones(sizeCur)*rawFlag;

% test, all bins above the contaminated depth are flagged
iFail = binDepth <= repmat(cDepth, 1, length(Bins));
iPass = binDepth > repmat(cDepth, 1, length(Bins));

%Need to take into account QC from previous algorithms
allFF = repmat(ff, 1, size(flags, 2));
iFail = allFF & iFail;

flags(iPass) = goodFlag;
flags(iFail) = badFlag;

sample_data.variables{idUcur}.flags = flags;
sample_data.variables{idVcur}.flags = flags;
sample_data.variables{idWcur}.flags = flags;

end