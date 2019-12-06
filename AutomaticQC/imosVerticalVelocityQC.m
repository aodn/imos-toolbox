function [data, flags, paramsLog] = imosVerticalVelocityQC ( sample_data, data, k, type, auto )
%IMOSVERTICALVELOCITYQC Quality control procedure for vertical velocity of 
% any ADCP instrument data.
%
%
% Inputs:
%   sample_data - struct containing the entire data set and dimension data.
%
%   data        - the vector/matrix of data to check.
%
%   k           - Index into the sample_data.variables vector.
%
%   type        - dimensions/variables type to check in sample_data.
%
%   auto        - logical, run QC in batch mode
%
% Outputs:
%   data        - same as input.
%
%   flags       - Vector the same length as data, with flags for corresponding
%                 data which is out of range.
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

narginchk(4, 5);
if ~isstruct(sample_data),              error('sample_data must be a struct');      end
if ~isscalar(k) || ~isnumeric(k),       error('k must be a numeric scalar');        end
if ~ischar(type),                       error('type must be a string');             end

% auto logical in input to enable running under batch processing
if nargin<5, auto=false; end

paramsLog = [];
flags     = [];

% this test doesn't apply on dimensions nor TIMESERIES, PROFILE, TRAJECTORY, LATITUDE, LONGITUDE, nor NOMINAL_DEPTH variables
if ~strcmp(type, 'variables'), return; end
if any(strcmp(sample_data.(type){k}.name, {'TIMESERIES', 'PROFILE', 'TRAJECTORY', 'LATITUDE', 'LONGITUDE', 'NOMINAL_DEPTH'})), return; end

% get all necessary dimensions and variables id in sample_data struct
idWcur = 0;
paramName = sample_data.(type){k}.name;
if strncmpi(paramName, 'WCUR', 4), idWcur = k; end

% check if the data is compatible with the QC algorithm
idMandatory = idWcur;
if ~idMandatory, return; end

qcSet           = str2double(readProperty('toolbox.qc_set'));
badFlag         = imosQCFlag('bad',             qcSet, 'flag');
goodFlag        = imosQCFlag('good',            qcSet, 'flag');
rawFlag         = imosQCFlag('raw',             qcSet, 'flag');

%Pull out vertical velocities
w = sample_data.variables{idWcur}.data;

% read in filter parameters
propFile = fullfile('AutomaticQC', 'imosVerticalVelocityQC.txt');
vvel      = str2double(readProperty('vvel',      propFile));

% read dataset QC parameters if exist and override previous 
% parameters file
currentQCtest = mfilename;
vvel = readDatasetParameter(sample_data.toolbox_input_file, currentQCtest, 'vvel', vvel);

paramsLog = ['vvel=' num2str(vvel)];

sizeCur = size(sample_data.variables{idWcur}.flags);

% same flags are given to any variable
flags = ones(sizeCur, 'int8')*rawFlag;

%Run QC
iPass = abs(w) <= vvel;
iFail = ~iPass;

%Run QC filter (iFail) on velocity data
flags(iFail) = badFlag;
flags(iPass) = goodFlag;

% write/update dataset QC parameters
writeDatasetParameter(sample_data.toolbox_input_file, currentQCtest, 'vvel', vvel);

end
