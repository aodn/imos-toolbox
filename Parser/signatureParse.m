function sample_data = signatureParse( filename, tMode )
%SIGNATUREPARSE Parses ADCP data from a raw Nortek Signature 
% binary (.ad2cp) file.
%
%
% Inputs:
%   filename    - Cell array containing the name of the raw signature
%                 file to parse.
%   tMode       - Toolbox data type mode.
% 
% Outputs:
%   sample_data - Struct containing sample data.
%
% Author: 		Guillaume Galibert <guillaume.galibert@utas.edu.au>
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
narginchk(1,2);

if ~iscellstr(filename), error('filename must be a cell array of strings'); end

% only one file supported
filename = filename{1};
[path, name, ext] = fileparts(filename);

isMagBias = false;
magDec = 0;

switch lower(ext)
    case '.ad2cp'
        % read in all of the structures in the raw file
        structures = readAD2CPBinary(filename);
        
        instrumentModel = '';
        if isfield(structures, 'IdA0')
            % this is a string data record
            if structures.IdA0.Data.Id == 16
                % looking for instrument model
                instrumentModel = regexp(structures.IdA0.Data.String, 'Signature[0-9]*', 'match', 'once');
                
                % check for magnetic declination
                stringCell = textscan(structures.IdA0.Data.String, '%s', 'Delimiter', ',');
                iMagDec = strncmp('DECL=', stringCell{1}, 5);
                if any(iMagDec)
                    magDec = stringCell{1}{iMagDec};
                    magDec = textscan(magDec, 'DECL=%f');
                    magDec = magDec{1};
                end
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
        
        cellSize  = unique(vertcat(structures.(dataRecordType).Data.CellSize))*0.001; % m
        blankDist = unique(vertcat(structures.(dataRecordType).Data.Blanking))*0.001; % m
        if length(cellSize) > 1, error('Multiple cell sizes/blanking distance not supported'); end
        
        % retrieve sample data
        Time            = vertcat(structures.(dataRecordType).Data.Time);
        speedOfSound    = vertcat(structures.(dataRecordType).Data.SpeedOfSound)*0.1; % m/s
        Temperature     = vertcat(structures.(dataRecordType).Data.Temperature)*0.01; % degree Celsius
        Pressure        = vertcat(structures.(dataRecordType).Data.Pressure)*0.001; % dBar
        Heading         = vertcat(structures.(dataRecordType).Data.Heading)*0.01; % deg
        Pitch           = vertcat(structures.(dataRecordType).Data.Pitch)*0.01; % deg
        Roll            = vertcat(structures.(dataRecordType).Data.Roll)*0.01; % deg
        Battery         = vertcat(structures.(dataRecordType).Data.BatteryVoltage)*0.1; % Volt
        Status          = vertcat(structures.(dataRecordType).Data.Status);
        velocity        = cat(3, structures.(dataRecordType).Data.VelocityData);
        velocityScaling = repmat(10.^vertcat(structures.(dataRecordType).Data.VelocityScaling), 1, nCells);
        Velocity_E      = squeeze(velocity(1,:,:))'.*velocityScaling; % m/s
        Velocity_N      = squeeze(velocity(2,:,:))'.*velocityScaling;
        Velocity_U      = squeeze(velocity(3,:,:))'.*velocityScaling;
        Velocity_U2     = squeeze(velocity(4,:,:))'.*velocityScaling;
        amplitude       = cat(3, structures.(dataRecordType).Data.AmplitudeData);
        Backscatter1    = squeeze(amplitude(1,:,:))'; % count
        Backscatter2    = squeeze(amplitude(2,:,:))';
        Backscatter3    = squeeze(amplitude(3,:,:))';
        Backscatter4    = squeeze(amplitude(4,:,:))';
        correlation     = cat(3, structures.(dataRecordType).Data.CorrelationData);
        Correlation1    = squeeze(correlation(1,:,:))'; % percent [0 - 100]
        Correlation2    = squeeze(correlation(2,:,:))';
        Correlation3    = squeeze(correlation(3,:,:))';
        Correlation4    = squeeze(correlation(4,:,:))';
        clear structures velocity velocityScaling amplitude correlation;
        
    case '.mat'
        % read in all of the structures in the file
        structures = load(filename);
        dataFields = fieldnames(structures.Data);
        
        % look for potentially more data in other .mat files
        [path, name, ext] = fileparts(filename);
        iMatFile = 1;
        nextFilename = fullfile(path, [name '_' num2str(iMatFile) ext]);
        while exist(nextFilename, 'file')
            nextStructures = load(nextFilename);
            % for each field of the structure we append new data to the
            % existing ones
            for i=1:length(dataFields)
                structures.Data.(dataFields{i}) = [structures.Data.(dataFields{i}); nextStructures.Data.(dataFields{i})];
            end
            
            iMatFile = iMatFile + 1;
            nextFilename = fullfile(path, [name '_' num2str(iMatFile) ext]);
            clear nextStructures;
        end
        
        % investigate which mode has been set for acquisition
        if strcmpi(structures.Config.Plan_BurstEnabled, 'TRUE')
            acquisitionMode = 'Burst';
        end
        
        if strcmpi(structures.Config.Plan_AverageEnabled, 'TRUE')
            acquisitionMode = 'Average';
        end

        % we need to sort the data by time just in case
        [Time, iSort] = sort(structures.Data.([acquisitionMode '_Time']));
        for i=1:length(dataFields)
            structures.Data.(dataFields{i}) = structures.Data.(dataFields{i})(iSort, :);
        end
        
        nSamples    = length(Time);
        nCells      = double(structures.Config.([acquisitionMode '_NCells']));
        
        serialNumber = num2str(structures.Config.SerialNo);
        instrumentModel = structures.Config.InstrumentName;
        
        cellSize    = structures.Config.([acquisitionMode '_CellSize']);
        blankDist   = structures.Config.([acquisitionMode '_BlankingDistance']);
        
        % check for magnetic declination
        magDec = structures.Config.Declination;
        
        [~, ~, cpuEndianness] = computer;
        
        Status              = dec2bin(bytecast(structures.Data.([acquisitionMode '_Status']), 'L', 'uint32', cpuEndianness), 32);
        % Error               = structures.Data.Average_Error; % error codes for each cell of a velocity profile inferred from the beams. 0=good; otherwise error. See http://www.nortek-as.com/en/knowledge-center/forum/waves/20001875?b_start=0#769595815
        % AmbiguityVel        = structures.Data.Average_AmbiguityVel;
        
        if isfield(structures.Data, [acquisitionMode '_Velocity_ENU'])
            Velocity_E          = squeeze(structures.Data.([acquisitionMode '_ENU'])(:, 1, :));
            Velocity_N          = squeeze(structures.Data.([acquisitionMode '_ENU'])(:, 2, :));
            Velocity_U          = squeeze(structures.Data.([acquisitionMode '_ENU'])(:, 3, :));
            Velocity_U2         = squeeze(structures.Data.([acquisitionMode '_ENU'])(:, 4, :));
        else
            Velocity_E          = structures.Data.([acquisitionMode '_VelEast']);
            Velocity_N          = structures.Data.([acquisitionMode '_VelNorth']);
            Velocity_U          = structures.Data.([acquisitionMode '_VelUp']);
            Velocity_U2         = structures.Data.([acquisitionMode '_VelUp2']);
        end
        if isfield(structures.Data, [acquisitionMode '_Amplitude_Beam'])
            Backscatter1        = squeeze(structures.Data.([acquisitionMode '_Amplitude_Beam'])(:, 1, :))*2; % looks like the .mat format is giving raw counts * 0.5 by default
            Backscatter2        = squeeze(structures.Data.([acquisitionMode '_Amplitude_Beam'])(:, 2, :))*2;
            Backscatter3        = squeeze(structures.Data.([acquisitionMode '_Amplitude_Beam'])(:, 3, :))*2;
            Backscatter4        = squeeze(structures.Data.([acquisitionMode '_Amplitude_Beam'])(:, 4, :))*2;
        else
            Backscatter1        = structures.Data.([acquisitionMode '_AmpBeam1'])*2;
            Backscatter2        = structures.Data.([acquisitionMode '_AmpBeam2'])*2;
            Backscatter3        = structures.Data.([acquisitionMode '_AmpBeam3'])*2;
            Backscatter4        = structures.Data.([acquisitionMode '_AmpBeam4'])*2;
        end
        if isfield(structures.Data, [acquisitionMode '_Correlation_Beam'])
            Correlation1        = squeeze(structures.Data.([acquisitionMode '_Correlation_Beam'])(:, 1, :));
            Correlation2        = squeeze(structures.Data.([acquisitionMode '_Correlation_Beam'])(:, 2, :));
            Correlation3        = squeeze(structures.Data.([acquisitionMode '_Correlation_Beam'])(:, 3, :));
            Correlation4        = squeeze(structures.Data.([acquisitionMode '_Correlation_Beam'])(:, 4, :));
        else
            Correlation1        = structures.Data.([acquisitionMode '_CorBeam1']);
            Correlation2        = structures.Data.([acquisitionMode '_CorBeam2']);
            Correlation3        = structures.Data.([acquisitionMode '_CorBeam3']);
            Correlation4        = structures.Data.([acquisitionMode '_CorBeam4']);
        end
        Battery             = structures.Data.([acquisitionMode '_Battery']);
        Heading             = structures.Data.([acquisitionMode '_Heading']);
        Pitch               = structures.Data.([acquisitionMode '_Pitch']);
        Roll                = structures.Data.([acquisitionMode '_Roll']);
        Temperature         = structures.Data.([acquisitionMode '_Temperature']);
        speedOfSound        = structures.Data.([acquisitionMode '_Soundspeed']);
        Pressure            = structures.Data.([acquisitionMode '_Pressure']);
        clear structures;

    otherwise
        error('Data format not supported');
        
end

sample_data = struct;
    
if magDec ~= 0
    isMagBias = true;
    magBiasComment = ['A compass correction of ' num2str(magDec) ...
        'degrees has been applied to the data by a technician using Nortek''s software ' ...
        '(usually to account for magnetic declination).'];
end

sample_data.toolbox_input_file              = filename;
sample_data.meta.featureType                = ''; % strictly this dataset cannot be described as timeSeriesProfile since it also includes timeSeries data like TEMP
sample_data.meta.binSize                    = cellSize;
sample_data.meta.instrument_make            = 'Nortek';
if isempty(instrumentModel)
    sample_data.meta.instrument_model       = 'Signature';
else
    sample_data.meta.instrument_model       = instrumentModel;
    
end
sample_data.meta.instrument_serial_no       = serialNumber;
sample_data.meta.instrument_sample_interval = median(diff(Time*24*3600));
switch sample_data.meta.instrument_model
    case 'Signature250'
        sample_data.meta.beam_angle         = 20;
    otherwise % Signature500 and Signature1000
        sample_data.meta.beam_angle         = 25;
end

% generate distance values
distance = nan(nCells, 1);
distance(:) = (blankDist):  ...
    (cellSize): ...
    (blankDist + (nCells-1) * cellSize);

% distance between the ADCP's transducers and the middle of each cell
% See http://www.nortek-bv.nl/en/knowledge-center/forum/current-profilers-and-current-meters/579860330
distance = (distance + cellSize);

% add dimensions with their data mapped
iStartOrientation = 26;
iEndOrientation = 28;
adcpOrientations = bin2dec(Status(:, end-iEndOrientation+1:end-iStartOrientation+1));
adcpOrientation = mode(adcpOrientations); % hopefully the most frequent value reflects the orientation when deployed
% we assume adcpOrientation == 4 by default "ZUP"
if adcpOrientation == 5
    % case of a downward looking ADCP -> negative values
    distance = -distance;
end
iWellOriented = all(adcpOrientations == repmat(adcpOrientation, nSamples, 1), 2); % we'll only keep data collected when ADCP is oriented as expected
dims = {
    'TIME',             Time(iWellOriented),    ''; ...
    'DIST_ALONG_BEAMS', distance,               'Nortek instrument data is not vertically bin-mapped (no tilt correction applied). Cells are lying parallel to the beams, at heights above sensor that vary with tilt.'
    };
clear Time distance;

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
if isMagBias
    magExt = '';
else
    magExt = '_MAG';
end
iDimVel = nDims;
iDimDiag = nDims;
vars = {
    'TIMESERIES',       [],             1;...
    'LATITUDE',         [],             NaN; ...
    'LONGITUDE',        [],             NaN; ...
    'NOMINAL_DEPTH',    [],             NaN; ...
    ['VCUR' magExt],    [1 iDimVel],    Velocity_N(iWellOriented, :); ... % V
    ['UCUR' magExt],    [1 iDimVel],    Velocity_E(iWellOriented, :); ... % U
    'WCUR',             [1 iDimVel],    Velocity_U(iWellOriented, :); ...
    'WCUR_2',           [1 iDimVel],    Velocity_U2(iWellOriented, :); ...
    'ABSIC1',           [1 iDimDiag],   Backscatter1(iWellOriented, :); ...
    'ABSIC2',           [1 iDimDiag],   Backscatter2(iWellOriented, :); ...
    'ABSIC3',           [1 iDimDiag],   Backscatter3(iWellOriented, :); ...
    'ABSIC4',           [1 iDimDiag],   Backscatter4(iWellOriented, :); ...
    'CMAG1',            [1 iDimDiag],   Correlation1(iWellOriented, :); ...
    'CMAG2',            [1 iDimDiag],   Correlation2(iWellOriented, :); ...
    'CMAG3',            [1 iDimDiag],   Correlation3(iWellOriented, :); ...
    'CMAG4',            [1 iDimDiag],   Correlation4(iWellOriented, :); ...
    'TEMP',             1,              Temperature(iWellOriented); ...
    'PRES_REL',         1,              Pressure(iWellOriented); ...
    'SSPD',             1,              speedOfSound(iWellOriented); ...
    'VOLT',             1,              Battery(iWellOriented); ...
    'PITCH',            1,              Pitch(iWellOriented); ...
    'ROLL',             1,              Roll(iWellOriented); ...
    ['HEADING' magExt], 1,              Heading(iWellOriented)
    };
clear Velocity_N Velocity_E Velocity_U Velocity_U2 ...
    Backscatter1 Backscatter2 Backscatter3 Backscatter4 ...
    Correlation1 Correlation2 Correlation3 Correlation4 ...
    Temperature Pressure speedOfSound Battery Pitch Roll Heading Status;

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
    
    if any(strcmpi(vars{i, 1}, {'VCUR', 'UCUR', 'HEADING'}))
        sample_data.variables{i}.compass_correction_applied = magDec;
        sample_data.variables{i}.comment = magBiasComment;
    end
end
clear vars;
