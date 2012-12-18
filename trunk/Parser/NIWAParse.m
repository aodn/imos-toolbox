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
%   mode        - Toolbox data type mode ('profile' or 'timeSeries').
%
% Outputs:
%   sample_data - Struct containing sample data.
%
% Author: Guillaume Galibert <guillaume.galibert@utas.edu.au>
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
error(nargchk(1,2,nargin));

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

% dimensions definition must stay in this order : T, Z, Y, X, others;
% to be CF compliant
% generate time data from header information
sample_data.dimensions{1}.name          = 'TIME';
sample_data.dimensions{1}.typeCastFunc  = str2func(netcdf3ToMatlabType(imosParameters(sample_data.dimensions{1}.name, 'type')));
sample_data.dimensions{1}.data          = sample_data.dimensions{1}.typeCastFunc(data.TIME);
sample_data.dimensions{2}.name          = 'LATITUDE';
sample_data.dimensions{2}.typeCastFunc  = str2func(netcdf3ToMatlabType(imosParameters(sample_data.dimensions{2}.name, 'type')));
sample_data.dimensions{2}.data          = sample_data.dimensions{2}.typeCastFunc(NaN);
sample_data.dimensions{3}.name          = 'LONGITUDE';
sample_data.dimensions{3}.typeCastFunc  = str2func(netcdf3ToMatlabType(imosParameters(sample_data.dimensions{3}.name, 'type')));
sample_data.dimensions{3}.data          = sample_data.dimensions{3}.typeCastFunc(NaN);

% scan through the list of parameters that were read
% from the file, and create a variable for each
vars = fieldnames(data);
for k = 1:length(vars)
    
    if strncmp('TIME', vars{k}, 4), continue; end
    
    sample_data.variables{end+1}.dimensions     = [1 2 3];
    sample_data.variables{end  }.name           = vars{k};
    sample_data.variables{end  }.typeCastFunc   = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{end}.name, 'type')));
    sample_data.variables{end  }.data           = sample_data.variables{end  }.typeCastFunc(data.(vars{k}));
    sample_data.variables{end  }.comment        = '';
    
    if strncmp('PRES_REL', vars{k}, 8)
        % let's document the constant pressure atmosphere offset previously
        % applied by SeaBird software on the absolute presure measurement
        sample_data.variables{end}.applied_offset = sample_data.variables{end}.typeCastFunc(-14.7*0.689476);
    end
end

end