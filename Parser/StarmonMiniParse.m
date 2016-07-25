function sample_data = StarmonMiniParse( filename, mode )
%STARMONMINIPARSE Parses an ASCII file from Starmon Mini .DAT file format
% as described in http://imos-toolbox.googlecode.com/svn/wiki/documents/Instruments/Star_ODDI/StarmonT.pdf
%
% The files consist of two sections:
%
%   - file headerContent       - headerContent information with description of the data structure and content.
%                         These lines are suffixed with a #.
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

% retrieve and parse the header content
header = getHeader(filename);

% retrieve and parse the data
data = getData(filename, header);

% create sample data struct,
% and copy all the data in
sample_data = struct;

sample_data.toolbox_input_file  = filename;
sample_data.meta.header         = header;

sample_data.meta.instrument_make            = 'Star ODDI';
sample_data.meta.instrument_model           = 'Starmon Mini';
sample_data.meta.instrument_sample_interval = median(diff(data.TIME.values*24*3600));
sample_data.meta.instrument_serial_no       = header.serialNo;
sample_data.meta.featureType                = mode;

sample_data.dimensions = {};
sample_data.variables  = {};

% generate time data from headerContent information
sample_data.dimensions{1}.name          = 'TIME';
sample_data.dimensions{1}.typeCastFunc  = str2func(netcdf3ToMatlabType(imosParameters(sample_data.dimensions{1}.name, 'type')));
sample_data.dimensions{1}.data          = sample_data.dimensions{1}.typeCastFunc(data.TIME.values);

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
    sample_data.variables{end  }.data           = sample_data.variables{end  }.typeCastFunc(data.(vars{k}).values);
    sample_data.variables{end  }.coordinates    = coordinates;
    sample_data.variables{end  }.comment        = data.(vars{k}).comment;
    
    if isfield(data.(vars{k}), 'applied_offset')
        % let's document the constant pressure atmosphere offset previously
        % applied by SeaBird software on the absolute presure measurement
        sample_data.variables{end}.applied_offset = data.(vars{k}).applied_offset;
    end
end

end

function header = getHeader(filename)
%GETHEADER Reads a Starmon Mini .DAT header and return usefull content in a
% structure.
%
% Each header item is contained in one line, and all header lines start with a #
% (bookmark) and a number. Then follows a description of the header item, and then 1-4
% directives, all separated by tabs. Eventually a comment trails the directives, preceded
% by a semicolon (;).
%
header = struct;

fileId = fopen(filename);

headerFormat = '#%d\t%[^:]:\t%[^\r\n]';
headerContent = textscan(fileId, headerFormat, 'Delimiter', '');

fclose(fileId);

header.nLines = length(headerContent{1});
for i=1:header.nLines
    switch headerContent{1}(i)
        case 1 % sequence + serial number of the recorder
            header.serialNo = headerContent{3}{i}(end-4:end);
            
        case 2 % joined Date and Time
            joinInfo = textscan(headerContent{3}{i}, '%d%d%*s', 'Delimiter', '\t');
            if joinInfo{1} == 0
                header.isDateJoined = false;
            else
                header.isDateJoined = true;
            end
            
        case 3 % total number of columns
            header.nCol = str2double(headerContent{3}{i});
            
        case 4 % number of measured parameters
            header.nParam = str2double(headerContent{3}{i});
            
        case 5 % field separation
            if strcmpi(headerContent{3}{i}, '0')
                header.fieldSep = '\t';
            else
                header.fieldSep = ' ';
            end
            
        case 6 % decimal point
            if strcmpi(headerContent{3}{i}, '0')
                header.decimalChar = ',';
            else
                header.decimalChar = '.';
            end
            
        case 7 % date format
            dateInfo = textscan(headerContent{3}{i}, '%d%d%*s', 'Delimiter', '\t');
            if dateInfo{1} == 0 && dateInfo{2} == 0
                header.dateFormat = 'dd.mm.yy';
            elseif dateInfo{1} == 1 && dateInfo{2} == 0
                header.dateFormat = 'mm.dd.yy';
            elseif dateInfo{1} == 0 && dateInfo{2} == 1
                header.dateFormat = 'dd/mm/yy';
            elseif dateInfo{1} == 1 && dateInfo{2} == 1
                header.dateFormat = 'mm/dd/yy';
            elseif dateInfo{1} == 0 && dateInfo{2} == 2
                header.dateFormat = 'dd-mm-yy';
            elseif dateInfo{1} == 1 && dateInfo{2} == 2
                header.dateFormat = 'mm-dd-yy';
            end

            
        case 8 % time format
            if strcmpi(headerContent{3}{i}, '0')
                header.timeFormat = 'HH:MM:SS';
            else
                header.timeFormat = 'HH.MM.SS';
            end
            
        case 9 % channel 1 info
            channelInfo = textscan(headerContent{3}{i}, '%s%s%d%d%*s', 'Delimiter', '\t');
            header.param(1).axis = channelInfo{1}{1};
            header.param(1).column = genvarname(channelInfo{2}{1});
            header.param(1).nDec = channelInfo{3};
            if channelInfo{4} == 1
                header.param(1).isPositiveUp = true;
            else
                header.param(1).isPositiveUp = false;
            end
            
        case 10 % channel 2 info
            channelInfo = textscan(headerContent{3}{i}, '%s%s%d%d%*s', 'Delimiter', '\t');
            header.param(2).axis = channelInfo{1}{1};
            header.param(2).column = genvarname(channelInfo{2}{1});
            header.param(2).nDec = channelInfo{3};
            if channelInfo{4} == 1
                header.param(2).isPositiveUp = true;
            else
                header.param(2).isPositiveUp = false;
            end
            
        case 11 % re-conversion
            if strcmpi(headerContent{3}{i}, '0')
                header.isReconverted = false;
            else
                header.isReconverted = true;
            end
            
        case 12 % no temperature correction
            if strcmpi(headerContent{3}{i}, '0')
                header.isTempCorr = true;
            else
                header.isTempCorr = false;
            end
            
        case 13 % pressure offset correction
            pressureInfo = textscan(headerContent{3}{i}, '%d%d%*s', 'Delimiter', '\t');
            if pressureInfo{1} == 0
                header.isPresCorr = false;
            else
                header.isPresCorr = true;
            end
            if ~isempty(pressureInfo{2})
                header.presCorrValue = pressureInfo{2};
            end
            
        case 14 % channel 3 info
            channelInfo = textscan(headerContent{3}{i}, '%s%s%d%d%*s', 'Delimiter', '\t');
            header.param(3).axis = channelInfo{1}{1};
            header.param(3).column = channelInfo{2}{1};
            header.param(3).nDec = channelInfo{3};
            if channelInfo{4} == 1
                header.param(3).isPositiveUp = true;
            else
                header.param(3).isPositiveUp = false;
            end
    end
end
end

function data = getData(filename, header)
%GETDATA Reads a Starmon Mini .DAT file data based on the header content
%
% The first column is the measurement number, 
% the second column the date and the time, depending on the set-up. 
% The third column is the time or the first measured parameter, depending on set-up. 
% The following column(s) contain the converted measured parameters with units and
% number of decimals according to set-up. 
%
% Number of parameters can range from 1-3, and number of columns 3-6 accordingly.
%
data = struct;

if strcmpi(header.fieldSep, ' ') || ~header.isDateJoined
    extraColumnTime = '%s';
    nColumnTime = 2;
else
    extraColumnTime = '';
    nColumnTime = 1;
end

dataFormat = ['%*d%s' extraColumnTime];
for i=3:header.nCol
    if header.isReconverted
        dataFormat = [dataFormat '%s%s'];
    else
        dataFormat = [dataFormat '%s'];
    end
end

fileId = fopen(filename);
DataContent = textscan(fileId, dataFormat, 'Delimiter', header.fieldSep, 'HeaderLines', header.nLines);
fclose(fileId);

% we convert the data
if strcmpi(header.fieldSep, ' ')  || ~header.isDateJoined
    data.TIME.values = datenum(DataContent{1}, header.dateFormat) + datenum(DataContent{2}, header.timeFormat) - datenum(datestr(now, 'yyyy-01-01'));
else
    data.TIME.values = datenum(DataContent{1}, [header.dateFormat ' ' header.timeFormat]);
end

for i=1:header.nCol-(1+nColumnTime) % we start after the "n date time"
    
    if header.isReconverted && rem(i, 2) == 0 % second param column
        iParam = i - 1;
    else % first param column or params are not converted
        iParam = i;
    end
    
    iContent = i + nColumnTime;
    
    switch header.param(iParam).column
        case {'Temp0x280xB0C0x29', 'Temp0x280xFFFDC0x29'} %degrees C
            var = 'TEMP';
            values = strrep(DataContent{iContent}, ',', '.');
%             values = cellfun(@str2double, values);
            values = sscanf(sprintf('%s*', values{:}), '%f*'); % ~35x faster than str2double
            comment = '';
            if header.isReconverted
                if header.isTempCorr
                    if rem(i, 2) == 1
                        var = [var '_1'];
                    else
                        var = [var '_2'];
                        comment = 'Normal temperature correction applied.';
                    end
                end
            end
            data.(var).values = values;
            data.(var).comment = comment;
            
        case {'Temp0x280xB0F0x29', 'Temp0x280xFFFDF0x29'} % ([degreesF] - 32) * 5/9
            var = 'TEMP';
            values = strrep(DataContent{iContent}, ',', '.');
            values = sscanf(sprintf('%s*', values{:}), '%f*'); % ~35x faster than str2double
            comment = 'Originaly expressed in Fahrenheit.';
            if header.isReconverted
                if header.isTempCorr
                    if rem(i, 2) == 1
                        var = [var '_1'];
                    else
                        var = [var '_2'];
                        comment = [comment ' Normal temperature correction applied.'];
                    end
                end
            end
            data.(var).values = (values - 32) * 5/9;
            data.(var).comment = comment;
            
        case 'Pres(dbar)'
            var = 'PRES';
            values = strrep(DataContent{iContent}, ',', '.');
            values = sscanf(sprintf('%s*', values{:}), '%f*'); % ~35x faster than str2double
            comment = '';
            applied_offset = [];
            if header.isReconverted
                if header.isPresCorr
                    comment = '';
                    if rem(i, 2) == 0
                        var = 'PRES_REL';
                        comment = ['A zero offset of value ' header.presCorrValue 'mbar was adjusted.'];
                        applied_offset = header.presCorrValue/100;
                    end
                end
            end
            data.(var).values = values;
            data.(var).comment = comment;
            data.(var).applied_offset = applied_offset;
            
        case 'Depth(m)'
            var = 'DEPTH';
            values = strrep(DataContent{iContent}, ',', '.');
            values = sscanf(sprintf('%s*', values{:}), '%f*'); % ~35x faster than str2double
            comment = '';
            if header.isReconverted
                if header.isPresCorr
                    if rem(i, 2) == 1
                        var = [var '_1'];
                    else
                        var = [var '_2'];
                        comment = ['A zero offset of value ' header.presCorrValue 'mbar was adjusted to pressure.'];
                    end
                end
            end
            data.(var).values = values;
            data.(var).comment = comment;
            
        case 'Sal(psu)'
            var = 'PSAL';
            values = strrep(DataContent{iContent}, ',', '.');
            values = sscanf(sprintf('%s*', values{:}), '%f*'); % ~35x faster than str2double
            comment = '';
            if header.isReconverted
                if header.isTempCorr || header.isPresCorr
                    if rem(i, 2) == 1
                        var = [var '_1'];
                    else
                        var = [var '_2'];
                        if header.isTempCorr && header.isPresCorr
                            comment = ['Normal temperature correction applied. A zero offset of value ' ...
                                header.presCorrValue 'mbar was adjusted to pressure.'];
                        elseif header.isTempCorr
                            comment = 'Normal temperature correction applied.';
                        elseif header.isPresCorr
                            comment = ['A zero offset of value ' header.presCorrValue 'mbar was adjusted to pressure.'];
                        end
                    end
                end
            end
            data.(var).values = values;
            data.(var).comment = comment;
            
        otherwise
            fprintf('%s\n', ['Warning : ' header.param(i).column ' not supported' ...
                ' in ' filename '. Contact AODN.']);
            
    end 
end

end