function sample_data = signatureParse( filename, tMode )
%SIGNATUREPARSE Parses ADCP data from a raw Nortek Signature 
% binary (.ad2cp) file.
%
%
% Inputs:
%   filename    - Cell array containing the name of the raw signature
%                 file to parse.
%   tMode       - Toolbox data type mode ('profile' or 'timeSeries').
% 
% Outputs:
%   sample_data - Struct containing sample data.
%
% Author: 		Guillaume Galibert <guillaume.galibert@utas.edu.au>
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
narginchk(1,2);

if ~iscellstr(filename), error('filename must be a cell array of strings'); end

% only one file supported
filename = filename{1};

% read in all of the structures in the raw file
structures = readAD2CPBinary(filename);

instrumentConfig = '';
if isfield(structures, 'IdA0')
    % this is a string data record
    if structures.IdA0.Data.Id == 16
        instrumentConfig = structures.IdA0.Data.String;
    end
end

if isfield(structures, 'Id15Version3')
    % this is a burst data record
    dataRecordType = 'Id15Version3';
elseif isfield(structures, 'Id16Version3')
    % this is an average data record
    dataRecordType = 'Id16Version3';
else
    % string/bottom track/interleaved data record is not supported
    error('Only burst/average data record version 3 format is supported');
end

nSamples = length(structures.(dataRecordType).Header);
nCells   = structures.(dataRecordType).Data(1).nCells;

serialNumber = num2str(unique(vertcat(structures.(dataRecordType).Data.SerialNumber)));

% generate distance values
cellSize  = unique(vertcat(structures.(dataRecordType).Data.CellSize))*0.001; % m
blankDist = unique(vertcat(structures.(dataRecordType).Data.Blanking))*0.001; % m
if length(cellSize) > 1, error('Multiple cell sizes/blanking distance not supported'); end
distance = (blankDist):  ...
           (cellSize): ...
           (blankDist + (nCells-1) * cellSize);
       
% Note this is actually the distance between the ADCP's transducers and the
% middle of each cell
% See http://www.nortek-bv.nl/en/knowledge-center/forum/current-profilers-and-current-meters/579860330
distance = (distance + cellSize);
       
% retrieve sample data
time            = vertcat(structures.(dataRecordType).Data.Time);
speedOfSound    = vertcat(structures.(dataRecordType).Data.SpeedOfSound)*0.1; % m/s
temperature     = vertcat(structures.(dataRecordType).Data.Temperature)*0.01; % degree Celsius
pressure        = vertcat(structures.(dataRecordType).Data.Pressure)*0.001; % dBar
heading         = vertcat(structures.(dataRecordType).Data.Heading)*0.01; % deg
pitch           = vertcat(structures.(dataRecordType).Data.Pitch)*0.01; % deg
roll            = vertcat(structures.(dataRecordType).Data.Roll)*0.01; % deg
battery         = vertcat(structures.(dataRecordType).Data.BatteryVoltage)*0.1; % Volt
status          = vertcat(structures.(dataRecordType).Data.Status);
velocity        = cat(3, structures.(dataRecordType).Data.VelocityData);
velocityScaling = repmat(10.^vertcat(structures.(dataRecordType).Data.VelocityScaling), 1, nCells);
velocity1       = squeeze(velocity(1,:,:))'.*velocityScaling; % m/s
velocity2       = squeeze(velocity(2,:,:))'.*velocityScaling;
velocity3       = squeeze(velocity(3,:,:))'.*velocityScaling;
velocity4       = squeeze(velocity(4,:,:))'.*velocityScaling;
amplitude       = cat(3, structures.(dataRecordType).Data.AmplitudeData);
backscatter1    = squeeze(amplitude(1,:,:))'; % count
backscatter2    = squeeze(amplitude(2,:,:))';
backscatter3    = squeeze(amplitude(3,:,:))';
backscatter4    = squeeze(amplitude(4,:,:))';
correlation     = cat(3, structures.(dataRecordType).Data.CorrelationData);
correlation1    = squeeze(correlation(1,:,:))'; % percent [0 - 100]
correlation2    = squeeze(correlation(2,:,:))';
correlation3    = squeeze(correlation(3,:,:))';
correlation4    = squeeze(correlation(4,:,:))';
clear structures velocity velocityScaling amplitude correlation;

sample_data = struct;
    
sample_data.toolbox_input_file              = filename;
sample_data.meta.featureType                = ''; % strictly this dataset cannot be described as timeSeriesProfile since it also includes timeSeries data like TEMP
sample_data.meta.binSize                    = cellSize;
sample_data.meta.instrument_make            = 'Nortek';
if isempty(instrumentConfig)
    sample_data.meta.instrument_model       = 'Signature';
else
    sample_data.meta.instrument_model       = regexp(instrumentConfig, 'Signature[0-9]*', 'match', 'once');
    
end
sample_data.meta.instrument_serial_no       = serialNumber;
sample_data.meta.instrument_sample_interval = median(diff(time*24*3600));
switch sample_data.meta.instrument_model
    case {'Signature500', 'Signature1000'}
        sample_data.meta.beam_angle         = 25;
    otherwise % Signature250
        sample_data.meta.beam_angle         = 20;
end

% add dimensions with their data mapped
iStartOrientation = 26;
iEndOrientation = 28;
adcpOrientations = bin2dec(status(:, end-iEndOrientation+1:end-iStartOrientation+1));
adcpOrientation = mode(adcpOrientations); % hopefully the most frequent value reflects the orientation when deployed
% we assume adcpOrientation == 4 by default "ZUP"
if adcpOrientation == 5
    % case of a downward looking ADCP -> negative values
    distance = -distance;
end
iWellOriented = all(adcpOrientations == repmat(adcpOrientation, nSamples, 1), 2); % we'll only keep data collected when ADCP is oriented as expected
dims = {
    'TIME',             time(iWellOriented),    ''; ...
    'DIST_ALONG_BEAMS', distance,               'Nortek instrument data is not vertically bin-mapped (no tilt correction applied). Cells are lying parallel to the beams, at heights above sensor that vary with tilt.'
    };
clear time distance;

nDims = size(dims, 1);
sample_data.dimensions = cell(nDims, 1);
for i=1:nDims
    sample_data.dimensions{i}.name         = dims{i, 1};
    sample_data.dimensions{i}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(dims{i, 1}, 'type')));
    sample_data.dimensions{i}.data         = sample_data.dimensions{i}.typeCastFunc(dims{i, 2});
    sample_data.dimensions{i}.comment      = dims{i, 3};
end
clear dims;

% add variables with their dimensions and data mapped.
% we assume no correction for magnetic declination has been applied
iDimVel = nDims;
iDimDiag = nDims;
vars = {
    'TIMESERIES',       [],             1;...
    'LATITUDE',         [],             NaN; ...
    'LONGITUDE',        [],             NaN; ...
    'NOMINAL_DEPTH',    [],             NaN; ...
    'VCUR_MAG',         [1 iDimVel],    velocity2(iWellOriented, :); ... % V
    'UCUR_MAG',         [1 iDimVel],    velocity1(iWellOriented, :); ... % U
    'WCUR',             [1 iDimVel],    velocity3(iWellOriented, :); ...
    'WCUR_2',           [1 iDimVel],    velocity4(iWellOriented, :); ...
    'ABSIC1',           [1 iDimDiag],   backscatter1(iWellOriented, :); ...
    'ABSIC2',           [1 iDimDiag],   backscatter2(iWellOriented, :); ...
    'ABSIC3',           [1 iDimDiag],   backscatter3(iWellOriented, :); ...
    'ABSIC4',           [1 iDimDiag],   backscatter4(iWellOriented, :); ...
    'CMAG1',            [1 iDimDiag],   correlation1(iWellOriented, :); ...
    'CMAG2',            [1 iDimDiag],   correlation2(iWellOriented, :); ...
    'CMAG3',            [1 iDimDiag],   correlation3(iWellOriented, :); ...
    'CMAG4',            [1 iDimDiag],   correlation4(iWellOriented, :); ...
    'TEMP',             1,              temperature(iWellOriented); ...
    'PRES_REL',         1,              pressure(iWellOriented); ...
    'SSPD',             1,              speedOfSound(iWellOriented); ...
    'VOLT',             1,              battery(iWellOriented); ...
    'PITCH',            1,              pitch(iWellOriented); ...
    'ROLL',             1,              roll(iWellOriented); ...
    'HEADING_MAG',      1,              heading(iWellOriented)
    };
clear analn1 analn2 time distance velocity1 velocity2 velocity3 velocity4 ...
    backscatter1 backscatter2 backscatter3 backscatter4 ...
    correlation1 correlation2 correlation3 correlation4 ...
    temperature pressure speedOfSound battery pitch roll heading status;

nVars = size(vars, 1);
sample_data.variables = cell(nVars, 1);
for i=1:nVars
    sample_data.variables{i}.name         = vars{i, 1};
    sample_data.variables{i}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(vars{i, 1}, 'type')));
    sample_data.variables{i}.dimensions   = vars{i, 2};
    if ~isempty(vars{i, 2}) % we don't want this for scalar variables
        if length(sample_data.variables{i}.dimensions) == 2
            sample_data.variables{i}.coordinates = ['TIME LATITUDE LONGITUDE ' sample_data.dimensions{sample_data.variables{i}.dimensions(2)}.name];
        else
            sample_data.variables{i}.coordinates = 'TIME LATITUDE LONGITUDE NOMINAL_DEPTH';
        end
    end
    sample_data.variables{i}.data         = sample_data.variables{i}.typeCastFunc(vars{i, 3});
end
clear vars;
