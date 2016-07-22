function [sample_data, varChecked, paramsLog] = imosHorizontalVelocitySetQC( sample_data, auto )
%IMOSHORIZONTALVELOCITYSETQC Quality control procedure for horizontal
% velocity of any ADCP instrument data.
%
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
% Copyright (c) 2016, Australian Ocean Data Network (AODN) and Integrated
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
%     * Neither the name of the AODN/IMOS nor the names of its contributors
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
narginchk(1, 2);
if ~isstruct(sample_data), error('sample_data must be a struct'); end

% auto logical in input to enable running under batch processing
if nargin<2, auto=false; end

varChecked = {};
paramsLog  = [];

% get all necessary dimensions and variables id in sample_data struct
idUcur = 0;
idVcur = 0;
idCspd = 0;
idCdir = 0;
lenVar = length(sample_data.variables);
for i=1:lenVar
    paramName = sample_data.variables{i}.name;
    
    if strncmpi(paramName, 'UCUR', 4),  idUcur = i; end
    if strncmpi(paramName, 'VCUR', 4),  idVcur = i; end
    if strcmpi(paramName, 'CSPD'),      idCspd = i; end
    if strncmpi(paramName, 'CDIR', 4),  idCdir = i; end
end

% check if the data is compatible with the QC algorithm
idMandatory = idUcur & idVcur;
if ~idMandatory, return; end

qcSet           = str2double(readProperty('toolbox.qc_set'));
badFlag         = imosQCFlag('bad',             qcSet, 'flag');
goodFlag        = imosQCFlag('good',            qcSet, 'flag');
rawFlag         = imosQCFlag('raw',             qcSet, 'flag');

% Pull out horizontal velocities
% we can afford to run the test only once (if couple of UCUR/VCUR) since u
% is only tested in absolute value (direction doesn't matter)
u = sample_data.variables{idUcur}.data;
v = sample_data.variables{idVcur}.data;
velocity = u + 1i*v;
clear u v;

% read in filter parameters
propFile = fullfile('AutomaticQC', 'imosHorizontalVelocitySetQC.txt');
hvel     = str2double(readProperty('hvel',      propFile));

% read dataset QC parameters if exist and override previous 
% parameters file
currentQCtest = mfilename;
hvel = readQCparameter(sample_data.toolbox_input_file, currentQCtest, 'hvel', hvel);

paramsLog = ['hvel=' num2str(hvel)];

sizeCur = size(sample_data.variables{idUcur}.flags);

% same flags are given to any variable
flags = ones(sizeCur, 'int8')*rawFlag;

% Run QC
iPass = abs(velocity) <= hvel;
iFail = ~iPass;

% Run QC filter (iFail) on velocity data
flags(iFail) = badFlag;
flags(iPass) = goodFlag;

sample_data.variables{idUcur}.flags = flags;
sample_data.variables{idVcur}.flags = flags;

varChecked = {sample_data.variables{idUcur}.name, ...
    sample_data.variables{idVcur}.name};

if idCdir
    sample_data.variables{idCdir}.flags = flags;
    varChecked = [varChecked, {sample_data.variables{idCdir}.name}];
end

if idCspd
    sample_data.variables{idCspd}.flags = flags;
    varChecked = [varChecked, {sample_data.variables{idCspd}.name}];
end

% write/update dataset QC parameters
writeQCparameter(sample_data.toolbox_input_file, currentQCtest, 'hvel', hvel);

end
