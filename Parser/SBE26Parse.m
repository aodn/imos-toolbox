function sample_data = SBE26Parse( filename, mode )
%SBE26PARSE Parses a .tid data file from a Seabird SBE26
% TP logger.
%
% This function is able to read in a .tid data file retrieved
% from a Seabird SBE26 Temperature and Pressure Logger. It is 
% assumed the file consists in the following columns:
%
%   - measurement number
%   - date and time (mm/dd/yyyy HH:MM:SS) of beginning of measurement
%   - pressure in psia
%   - temperature in degrees Celsius
%
% Inputs:
%   filename    - cell array of files to import (only one supported).
%   mode        - Toolbox data type mode.
%
% Outputs:
%   sample_data - Struct containing sample data.
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
narginchk(1,2);

if ~iscellstr(filename)
    error('filename must be a cell array of strings');
end

% only one file supported currently
filename = filename{1};

formatSpec = '%*d %f %f %f %f %f %f %f %f';

% read in every line in the file
try
    fid = fopen(filename, 'rt');
    data = textscan(fid, formatSpec, 'Delimiter', {' ', '/', ':'}, 'MultipleDelimsAsOne', true);
    
    fclose(fid);
    
catch e
    if fid ~= -1, fclose(fid); end
    rethrow(e);
end

Y   = data{3};
M   = data{1};
D   = data{2};
H   = data{4};
MN  = data{5};
S   = data{6};

time        = datenum(Y, M, D, H, MN+2, S); % we assume a measurement is averaged over 4 minutes
pressure    = data{7} * 0.6894757; % 1psi = 0.6894757dbar
temperature = data{8};

% create sample data struct,
% and copy all the data in
sample_data = struct;

sample_data.toolbox_input_file  = filename;
sample_data.meta.featureType    = mode;

sample_data.meta.instrument_make = 'Seabird';
sample_data.meta.instrument_model = 'SBE26';

sample_data.meta.instrument_firmware = '';

sample_data.meta.instrument_serial_no = '';

sample_data.meta.instrument_sample_interval = median(diff(time*24*3600));

sample_data.dimensions = {};
sample_data.variables  = {};

% generate time data from header information
sample_data.dimensions{1}.name              = 'TIME';
sample_data.dimensions{1}.typeCastFunc      = str2func(netcdf3ToMatlabType(imosParameters(sample_data.dimensions{1}.name, 'type')));
sample_data.dimensions{1}.data              = sample_data.dimensions{1}.typeCastFunc(time);
sample_data.dimensions{1}.comment           = 'Time stamp corresponds to the centre of the measurement which lasts 4 minutes.';

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

% create a variable for each parameter
coordinates = 'TIME LATITUDE LONGITUDE NOMINAL_DEPTH';
    
% dimensions definition must stay in this order : T, Z, Y, X, others;
% to be CF compliant
sample_data.variables{end+1}.dimensions     = 1;
sample_data.variables{end  }.name           = 'PRES_REL';
sample_data.variables{end  }.typeCastFunc   = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{end}.name, 'type')));
sample_data.variables{end  }.data           = sample_data.variables{end}.typeCastFunc(pressure);
sample_data.variables{end  }.coordinates    = coordinates;
% let's document the constant pressure atmosphere offset previously
% applied by SeaBird software on the absolute presure measurement
sample_data.variables{end}.applied_offset   = sample_data.variables{end}.typeCastFunc(-14.7*0.689476);

sample_data.variables{end+1}.dimensions     = 1;
sample_data.variables{end  }.name           = 'TEMP';
sample_data.variables{end  }.typeCastFunc   = str2func(netcdf3ToMatlabType(imosParameters(sample_data.variables{end}.name, 'type')));
sample_data.variables{end  }.data           = sample_data.variables{end}.typeCastFunc(temperature);
sample_data.variables{end  }.coordinates    = coordinates;

end