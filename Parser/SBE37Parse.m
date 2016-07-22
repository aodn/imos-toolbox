function sample_data = SBE37Parse( filename, mode )
%SBE37PARSE Parse a raw '.asc' file containing SBE37 data, or SBE37-IM hex 
% format from OOI (USA).
%
% This function can read in data that has been downloaded from an SBE37
% 'Microcat' temperature/conductivity/pressure sensor.
%
% The output format for the SBE37 is very similar to the SBE39, so this
% function simply delegates the parsing to the SBE3x function, which parses
% data from both instrument types.
%
% Inputs:
%   filename    - name of the input file to be parsed
%   mode        - Toolbox data type mode.
%
% Outputs:
%   sample_data - struct containing the sample data
%
% Author:           Paul McCarthy <paul.mccarthy@csiro.au>
% Contributor:      Guillaume Galibert <guillaume.galibert@utas.edu.au>
%
% See SBE3x.m
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

% ensure that there is exactly one argument, 
% and that it is a cell array of strings
narginchk(1,2);

if ~iscellstr(filename), error('filename must be a cell array of strings'); end

% only one file supported currently
filename = filename{1};
if ~ischar(filename), error('filename must contain a string'); end

[~, ~, ext] = fileparts(filename);

% read first line in the file
try
    
    fid = fopen(filename, 'rt');
    line = fgetl(fid);
    fclose(fid);
    
catch e
    if fid ~= -1, fclose(fid); end
    rethrow(e);
end

if strcmpi(ext, '.DAT') && strcmp(line, '//Status Information')
    % try to read SBE37-IM hex format from OOI (USA)
    
    % read in every line in the file, separating
    % them out into each of the three sections
    instHeaderLines = {};
    dataLines       = {};
    try
        
        fid = fopen(filename, 'rt');
        line = fgetl(fid);
        header = false;
        dataBody = false;
        while ischar(line)
            
            line = deblank(line);
            if isempty(line)
                line = fgetl(fid);
                continue;
            end
            
            if strcmp(line, '//Status Information')
                header = true;
                dataBody = false;
                line = fgetl(fid);
                continue;
            elseif strcmp(line, '//Begin Data')
                header = false;
                dataBody = true;
                line = fgetl(fid);
                continue;
            elseif strcmp(line, '//End Data')
                break;
            end
            
            if header
                instHeaderLines{end+1} = line;
            elseif dataBody
                dataLines{      end+1} = line;
            end
            
            line = fgetl(fid);
        end
        
        fclose(fid);
        
    catch e
        if fid ~= -1, fclose(fid); end
        rethrow(e);
    end
    
    % read in the raw instrument header
    instHeader = parseInstrumentHeader(instHeaderLines);
    
    data = readSBE37hex(dataLines, instHeader);
    
    % create sample data struct,
    % and copy all the data in
    sample_data = struct;
  
    sample_data.toolbox_input_file  = filename;
    sample_data.meta.featureType    = mode;
    sample_data.meta.instHeader     = instHeader;
    
    sample_data.meta.instrument_make = 'Seabird';
    if isfield(instHeader, 'instrument_model')
        sample_data.meta.instrument_model = instHeader.instrument_model;
    else
        sample_data.meta.instrument_model = 'SBE37';
    end
    
    if isfield(instHeader, 'instrument_firmware')
        sample_data.meta.instrument_firmware = instHeader.instrument_firmware;
    else
        sample_data.meta.instrument_firmware = '';
    end
    
    if isfield(instHeader, 'instrument_serial_no')
        sample_data.meta.instrument_serial_no = instHeader.instrument_serial_no;
    else
        sample_data.meta.instrument_serial_no = '';
    end
    
    if isfield(instHeader, 'sampleInterval')
        sample_data.meta.instrument_sample_interval = instHeader.sampleInterval;
    else
        sample_data.meta.instrument_sample_interval = median(diff(data.TIME*24*3600));
    end
    
    sample_data.dimensions = {};
    sample_data.variables  = {};
    
    % dimensions creation
    sample_data.dimensions{1}.name          = 'TIME';
    sample_data.dimensions{1}.typeCastFunc  = str2func(netcdf3ToMatlabType(imosParameters(sample_data.dimensions{1}.name, 'type')));
    % generate time data from header information
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
        sample_data.variables{end  }.coordinates    = coordinates;
        
        if strncmp('PRES_REL', vars{k}, 8)
            % let's document the constant pressure atmosphere offset previously
            % applied by SeaBird software on the absolute presure measurement
            sample_data.variables{end}.applied_offset = sample_data.variables{end}.typeCastFunc(-14.7*0.689476);
        end
    end
else
    % use the classic SBE3x ASCII format suggested for IMOS
    sample_data = SBE3x(filename, mode);
end
end

function header = parseInstrumentHeader(headerLines)
%PARSEINSTRUMENTHEADER Parses the header lines from a SBE37-IM .DAT file.
% Returns the header information in a struct.
%
% Inputs:
%   headerLines - cell array of strings, the lines of the header section.
%
% Outputs:
%   header      - struct containing information that was in the header
%                 section.
%
header = struct;

% there's no real structure to the header information, which
% is annoying. my approach is to use various regexes to search
% for info we want, and to ignore everything else. inefficient,
% but it's the nicest way i can think of

headerExpr   = 'SBE(\S+)\s+(\S+)\s+SERIAL NO.\s+(\d+)';
memExpr      = 'samplenumber = (\d+), free = (\d+)';
sampleExpr   = 'sample interval = (\d+) seconds';
pressureExpr   = 'PressureRange = (\d+)';
outputExpr   = '//Data Format: (\S+)';
otherExpr    = '([^\s=]+)\s*=\s*([^\s=]+)';

exprs = {headerExpr   memExpr      sampleExpr   ...
         pressureExpr outputExpr   otherExpr};

for l = 1:length(headerLines)
    
    % try each of the expressions
    for m = 1:length(exprs)
        
        % until one of them matches
        tkns = regexp(headerLines{l}, exprs{m}, 'tokens');
        if ~isempty(tkns)
            
            % yes, ugly, but easiest way to figure out which regex we're on
            switch m
                
                % header
                case 1
                    header.instrument_model     = ['SBE' tkns{1}{1}];
                    header.instrument_firmware  = tkns{1}{2};
                    header.instrument_serial_no = tkns{1}{3};
                    
                % mem
                case 2
                    header.numSamples = str2double(tkns{1}{1});
                    header.freeMem    = str2double(tkns{1}{2});
                    
                % sample
                case 3
                    header.sampleInterval        = str2double(tkns{1}{1});
                    
                % pressure
                case 4
                    header.PressureRange         = str2double(tkns{1}{1});
                    
                % output
                case 5
                    header.outputFormat = tkns{1}{1};
                    
                % name = value
                case 6
                    for i=1:length(tkns)
                        name = genvarname(tkns{i}{1});
                        value = tkns{i}{2};
                        if strcmpi(value(end), ','), value = value(1:end-1); end
                        header.(name) = value;
                    end
            end
            break;
        end
    end
end
end