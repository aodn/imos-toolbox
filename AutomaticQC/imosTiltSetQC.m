function [sample_data, varChecked, paramsLog] = imosTiltSetQC( sample_data, auto )
%IMOSTILTSETQC Quality control procedure for ADCP instrument data against their tilt.
%
% Quality control ADCP bin-mapped data, assessing the tilt of the instrument over the
% bin-mapping algotithm.
%
% Following Alessandra Mantovanelli recommendations :
% The bin-mapping algorithm cannot accurately correct for tilting if angles
% are greater than a physical limit imposed by the sensor output. For most
% RDI Workhorse ADCPs this angle is 20deg, for the RDI Workhorse LongRanger
% 50deg and for the Sentinel V there is no such limit.
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
% Contributor:  Alessandra Mantovanelli <alessandra.mantovanelli@uwa.edu.au>
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
idUcur = 0;
idVcur = 0;
idWcur = 0;
idCspd = 0;
idCdir = 0;
idPitch = 0;
idRoll = 0;
lenVar = size(sample_data.variables,2);
for i=1:lenVar
    paramName = sample_data.variables{i}.name;
    
    if strncmpi(paramName, 'UCUR', 4),  idUcur    = i; end
    if strncmpi(paramName, 'VCUR', 4),  idVcur    = i; end
    if strcmpi(paramName, 'WCUR'),      idWcur    = i; end
    if strcmpi(paramName, 'CSPD'),      idCspd    = i; end
    if strncmpi(paramName, 'CDIR', 4),  idCdir    = i; end
    if strcmpi(paramName, 'PITCH'),     idPitch   = i; end
    if strcmpi(paramName, 'ROLL'),      idRoll    = i; end
end

% check if the data is compatible with the QC algorithm
idMandatory = idPitch & idRoll & (idUcur | idVcur | idWcur | idCspd | idCdir);

if ~idMandatory, return; end

qcSet = str2double(readProperty('toolbox.qc_set'));
badFlag         = imosQCFlag('bad',             qcSet, 'flag');
probBadFlag     = imosQCFlag('probablyBad',     qcSet, 'flag');
goodFlag        = imosQCFlag('good',            qcSet, 'flag');
rawFlag         = imosQCFlag('raw',             qcSet, 'flag');

probBadTilt = [];
badTilt     = [];

% we try to find out which kind of ADCP we're dealing with
if ~isempty(strfind(sample_data.instrument, 'RDI')) || ~isempty(strfind(lower(sample_data.instrument), 'workhorse'))
    probBadTilt = 15;
    badTilt     = 20;
end
if ~isempty(strfind(lower(sample_data.instrument), 'nortek'))
    probBadTilt = 20;
    badTilt     = 30;
end

if isempty(probBadTilt)
    error(['Impossible to determine whether ' sample_data.toolbox_input_file ' is RDI or Nortek => Fill instrument!']);
end

paramsLog = ['probBadTilt=' num2str(probBadTilt) ', badTilt=' num2str(badTilt)];

pitch = sample_data.variables{idPitch}.data;
roll  = sample_data.variables{idRoll}.data;

tilt = acos(sqrt(1 - sin(roll*pi/180).^2 - sin(pitch*pi/180).^2))*180/pi;

% initially everything is bad
sizeCur = size(sample_data.variables{idWcur}.flags);
flags = ones(sizeCur, 'int8')*badFlag;

% tilt test
iPass = tilt < badTilt;
flags(iPass,:) = probBadFlag;

iPass = tilt < probBadTilt;
flags(iPass,:) = goodFlag;

if idWcur
    sample_data.variables{idWcur}.flags = flags;
    varChecked = [varChecked, {'WCUR'}];
end
if idCspd
    sample_data.variables{idCspd}.flags = flags;
    varChecked = [varChecked, {'CSPD'}];
end

if idUcur
    sample_data.variables{idUcur}.flags = flags;
    varChecked = [varChecked, {sample_data.variables{idUcur}.name}];
end
if idVcur
    sample_data.variables{idVcur}.flags = flags;
    varChecked = [varChecked, {sample_data.variables{idVcur}.name}];
end
if idCdir
    sample_data.variables{idCdir}.flags = flags;
    varChecked = [varChecked, {sample_data.variables{idCdir}.name}];
end
end