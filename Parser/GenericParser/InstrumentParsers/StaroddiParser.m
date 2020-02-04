function [sample_data, sdata] = StaroddiParser(filename, mode)
% function [sample_data] = StaroddiParser(filename, mode)
%
% Read data from a Star-oddi Instrument series.
%
% Inputs:
%
% filename - a string or 1x1 cell with the filename string.
% mode - a string  - IMOS toolbox mode [`timeSeries',`profile`]
%
% Outputs:
%
% sample_data - the expected IMOS toolbox structure
% sdata - a structure with all the header/data information
% sdata.file_encoding - the encoding used
% sdata.file_machineformat - the machineformat used
% sdata.header_def_rules - the header definition rules for reading
% sdata.header_oper_rules - as above, but for conversion
% sdata.data_def_rules - the data definition rules for reading
% sdata.data_oper_rules - as above, but for conversion
% sdata.header_lines - the raw header lines
% sdata.header_content - the header info after reading
% sdata.header_info - the header info after processing
% sdata.raw_data - the data information after reading
% sdata.proc_data - the data information after processing
%
% Example:
%
% idata = StaroddiParser({'0-4T3769.DAT'},'timeSeries');
%
% author: hugo.oliveira@utas.edu.au
%

% Copyright (C) 2019, Australian Ocean Data Network (AODN) and Integrated
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
%
% You should have received a copy of the GNU General Public License
% along with this program.
% If not, see <https://www.gnu.org/licenses/gpl-3.0.en.html>.
%

narginchk(1, 2);

if iscellstr(filename) || isstring(filename)
    filename = filename{1};
end

if ~strcmp(mode, 'timeSeries') &&~strcmp(mode, 'Profile')
    error('mode is not a valid string')
end

[sdata] = StaroddiRules();

sdata.file_name = filename;
sdata.mode = mode;
[sdata.file_encoding, sdata.file_machineformat] = detectEncoding(filename);

fid = fopen(filename, 'r', sdata.file_machineformat, sdata.file_encoding);
[sdata.header_info, sdata.header_content, sdata.header_lines] = HeaderParser(fid, sdata.header_def_rules, sdata.header_oper_rules);
[sdata.rawdata, sdata.procdata] = DataParser(fid, sdata);
data = mapDataNames(sdata.procdata, sdata.name_map_rules, sdata.header_info);
sdata.data = data;
fclose(fid);

% map variable names
hvmap = containers.Map();
hvmap('Temperature') = 'TEMP';
hvmap('Pressure') = 'PRES';
hvmap('Depth') = 'DEPTH';
hvmap('Salinity') = 'PSAL';
hvmap('Conductivity') = 'CNDC';
hvmap('SoundVelocity') = 'SOUND_VEL';
hvmap('Roll') = 'ROLL';
hvmap('Pitch') = 'PITCH';

%map dimension names
hdmap = containers.Map();
hdmap('Temperature') = 1;
hdmap('Pressure') = 1;
hdmap('Depth') = 1;
hdmap('Salinity') = 1;
hdmap('Conductivity') = 1;
hdmap('SoundVelocity') = 1;
hdmap('Roll') = 1;
hdmap('Pitch') = 1;

sample_data = struct;
sample_data.toolbox_input_file = filename;
sample_data.meta.header = sdata.header_info;
sample_data.meta.instrument_make = 'Star ODDI';
sample_data.meta.instrument_model = sdata.header_info.recorder.instrument_name;
sample_data.meta.instrument_serial_no = sdata.header_info.recorder.serial_number;
sample_data.meta.instrument_sample_interval = median(diff(data.('TIME') * 24 * 3600));
sample_data.meta.featureType = mode;

[coordinates, sample_data.dimensions, sample_data.variables] = loadTimeSeriesSampleTemplate(data.('TIME'));
converted_variables = convertVariables(data, hvmap, hdmap, coordinates);

sample_data.variables = [sample_data.variables, converted_variables];

is_degF_mini = isfield(sdata.header_info, 'channel_index_1') && isfield(sdata.header_info,'channel_info_1') && strcmp(sdata.header_info.channel_info_1.channel_units, [char(176) 'F']);
is_degF_dst = isfield(sdata.header_info, 'axis_index_0') && isfield(sdata.header_info,'axis_info_0') && strcmp(sdata.header_info.axis_info_0.axis_units, [char(176) 'F']);
is_temp_fahrenheit = is_degF_mini || is_degF_dst;

if is_temp_fahrenheit
    for k = 1:length(sample_data.variables)
        vname = sample_data.variables{k}.name;
        is_temp = strcmp(vname, 'TEMP') || contains(vname, 'TEMP_');

        if is_temp
            sample_data.variables{k}.data = toCelsius(sample_data.variables{k}.data,'fahrenheit');
            sample_data.variables{k}.comment = 'Originaly expressed in Fahrenheit.';
        end

    end

end

is_temp_corrected = isfield(sdata.header_info, 'no_temperature_correction') && ~sdata.header_info.no_temperature_correction;
is_pres_corrected = isfield(sdata.header_info, 'pressure_offset_correction') && sdata.header_info.pressure_offset_correction;
is_salt_corrected = (is_temp_corrected || is_pres_corrected) && getVar(sample_data.variables, 'PSAL');

if is_temp_corrected
    k = getVar(sample_data.variables, 'TEMP_2');
    if k>0
        cmt = sample_data.variables{k}.comment;
        sample_data.variables{k}.comment = [cmt 'Normal temperature correction applied.'];
    else
        error("Filename %s does not contain corrected temperature field");
    end
end

if is_pres_corrected
    k = getVar(sample_data.variables, 'PRES');
    if k>0
        pres_rel = sample_data.variables{k};
        pres_rel.name = 'PRES_REL';
        pres_rel.comment = ['A zero offset of value ' sdata.header_info.pressure_offset_correction 'mbar was adjusted.'];
        pres_rel.applied_offset = sdata.header_info.pressure_offset_correction / 100;
        sample_data.variables{end + 1} = pres_rel;
    else
        error("Filename %s does not contain corrected pressure field");
    end


    k = getVar(sample_data.variables, 'DEPTH');
    if k>0
        depth_rel = sample_data.variables{k};
        depth_rel.name = 'DEPTH_2';
        depth_rel.comment = ['A zero offset of value ' sdata.header_info.pressure_offset_correction 'mbar was adjusted to pressure.'];
        sample_data.variables{end + 1} = depth_rel;
    end
end

if is_salt_corrected
    k = getVar(sample_data.variables, 'PSAL');
    if k>0
        psal_rel = sample_data.variables{k};
        psal_rel.name = 'PSAL_2';

        if is_temp_corrected
            psal_rel.comment = 'Normal temperature correction applied.';
        end

        if is_pres_corrected
            psal_rel.comment = [psal_rel.comment 'A zero offset of value ' sdata.header_info.pressure_offset_correction 'mbar was adjusted to pressure.'];
        end

        sample_data.variables{end + 1} = psal_rel;
    else
        error("Filename %s does not contain corrected salinity field");
    end

end

end
