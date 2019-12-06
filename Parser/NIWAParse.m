function sample_data = NIWAParse( filename, mode )
%NIWAPARSE Parses a .DAT3 data file from NIWA's output ASCII file format
% .DAT3 as provided by Brett Grant.
%
% The files consist of three sections:
%
%   - file header       - header information as retrieved from the instrument original file and meta file.
%                         These lines are suffixed with a number.
%   - parameters line   - a line with parameter codes
%   - units line        - a line with units
%   - data              - rows of data.
%
% Inputs:
%   filename    - cell array of files to import (only one supported).
%   mode        - Toolbox data type mode.
%
% Outputs:
%   sample_data - Struct containing sample data.
%
% Author: Guillaume Galibert <guillaume.galibert@utas.edu.au>
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
narginchk(1,2);

if ~iscellstr(filename)
    error('filename must be a cell array of strings');
end

% only one file supported currently
filename = filename{1};

% read in every line in the file, separating
% them out into each of the three sections
lenHeader = 18;
headerLines     = cell(lenHeader, 1);
data            = {};
try
    
    fid = fopen(filename, 'rt');
    for i=1:lenHeader
        line = fgetl(fid);
        headerLines{i} = deblank(line(1:78));
    end
    
    params  = textscan(fgetl(fid), '%s');
    params  = params{1};
    units   = textscan(fgetl(fid), '%s');
    units   = units{1};
    
    nParams = length(params);
    
    format = '%s %s'; % we start with date time
    for i=2:nParams
        format = [format ' %f'];
    end
    dataTxt = textscan(fid, format);
    fclose(fid);
    
catch e
    if fid ~= -1, fclose(fid); end
    rethrow(e);
end

% we convert the data
data.TIME = datenum(dataTxt{:, 1}) + datenum(dataTxt{:, 2}) - datenum(datestr(now, 'yyyy-01-01'));

for i=2:nParams
    switch params{i}
        case 'con'
            var = 'CNDC';
            
        case 'tem'
            var = 'TEMP';
            
        case 'pre'
            var = 'PRES_REL';
            
        case 'sal'
            var = 'PSAL';
            
    end
    data.(var) = dataTxt{:, i+1}; % time has actually generated 2 rows, hence +1
end
clear dataTxt;

% create sample data struct,
% and copy all the data in
sample_data = struct;

sample_data.toolbox_input_file  = filename;
sample_data.meta.featureType    = mode;
sample_data.meta.headerLines    = headerLines;

sample_data.meta.instrument_make = 'NIWA ASCII .DAT3';
if ~isempty(headerLines{2})
    instrument_model = textscan(headerLines{2}, '%s', 1);
    sample_data.meta.instrument_model = instrument_model{1}{1};
else
    sample_data.meta.instrument_model = '';
end

sample_data.meta.instrument_firmware = '';

if ~isempty(headerLines{2})
    instrument_serial_no = textscan(headerLines{2}, '%*s %s', 1);
    sample_data.meta.instrument_serial_no = instrument_serial_no{1}{1};
else
    sample_data.meta.instrument_serial_no = '';
end

if ~isempty(headerLines{7})
    sampleInterval = textscan(headerLines{7}, '%f %f %f %f %*s', 1);
    sample_data.meta.instrument_sample_interval = sampleInterval{1}*24*3600 + sampleInterval{2}*3600 + sampleInterval{3}*60 + sampleInterval{4};
else
    sample_data.meta.instrument_sample_interval = median(diff(data.TIME*24*3600));
end

for i=9:18
    if ~isempty(headerLines{i}) && i==9
        sample_data.meta.lineage = strrep([strtrim(headerLines{i}) '.'], '..', '.');
    elseif ~isempty(headerLines{i}) && i>9
        sample_data.meta.lineage = strrep([sample_data.meta.lineage ' ' strtrim(headerLines{i}) '.'], '..', '.');
    end
end

sample_data.dimensions = {};
sample_data.variables  = {};

% generate time data from header information
sample_data.dimensions{1}.name          = 'TIME';
sample_data.dimensions{1}.typeCastFunc  = str2func(netcdf3ToMatlabType(imosParameters(sample_data.dimensions{1}.name, 'type')));
sample_data.dimensions{1}.data          = sample_data.dimensions{1}.typeCastFunc(data.TIME);

sample_data.variables{end+1}.name           = 'TIMESERIES';
sample_data.variables{end}.typeCastFunc     = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{end}.name, 'type')));
sample_data.variables{end}.data             = sample_data.variables{end}.typeCastFunc(1);
sample_data.variables{end}.dimensions       = [];
sample_data.variables{end+1}.name           = 'LATITUDE';
sample_data.variables{end}.typeCastFunc     = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{end}.name, 'type')));
sample_data.variables{end}.data             = sample_data.variables{end}.typeCastFunc(NaN);
sample_data.variables{end}.dimensions       = [];
sample_data.variables{end+1}.name           = 'LONGITUDE';
sample_data.variables{end}.typeCastFunc     = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{end}.name, 'type')));
sample_data.variables{end}.data             = sample_data.variables{end}.typeCastFunc(NaN);
sample_data.variables{end}.dimensions       = [];
sample_data.variables{end+1}.name           = 'NOMINAL_DEPTH';
sample_data.variables{end}.typeCastFunc     = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{end}.name, 'type')));
sample_data.variables{end}.data             = sample_data.variables{end}.typeCastFunc(NaN);
sample_data.variables{end}.dimensions       = [];

% scan through the list of parameters that were read
% from the file, and create a variable for each
vars = fieldnames(data);
coordinates = 'TIME LATITUDE LONGITUDE NOMINAL_DEPTH';
for k = 1:length(vars)
    
    if strncmp('TIME', vars{k}, 4), continue; end
    
    % dimensions definition must stay in this order : T, Z, Y, X, others;
    % to be CF compliant
    sample_data.variables{end+1}.dimensions     = 1;
    sample_data.variables{end  }.name           = vars{k};
    sample_data.variables{end  }.typeCastFunc   = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{end}.name, 'type')));
    sample_data.variables{end  }.data           = sample_data.variables{end}.typeCastFunc(data.(vars{k}));
    sample_data.variables{end  }.comment        = '';
    sample_data.variables{end  }.coordinates    = coordinates;

    if strncmp('PRES_REL', vars{k}, 8)
        % let's document the constant pressure atmosphere offset previously
        % applied by SeaBird software on the absolute presure measurement
        sample_data.variables{end}.applied_offset = sample_data.variables{end}.typeCastFunc(-14.7*0.689476);
    end
end

end