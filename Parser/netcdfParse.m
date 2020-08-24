function sample_data = netcdfParse( filename, mode )
%NETCDFPARSE Parses an IMOS NetCDF file.
%
% This function is able to import an IMOS compliant NetCDF file.
%
% Inputs:
%   filename    - cell array of file names (only one supported).
%   mode        - Toolbox data type mode.
%
% Outputs:
%   sample_data - struct containing the imported data set.
%
% Author:       Paul McCarthy <paul.mccarthy@csiro.au>
% Contributor : Laurent Besnard <laurent.besnard@utas.edu.au>
%               Guillaume Galibert <guillaume.galibert@utas.edu.au>
%               Gordon Keith <gordon.keith@csiro.au>

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

  if ~iscellstr(filename), error('filename must be a cell array of strings');
  end

  % only one input file supported
  filename = filename{1};

  % get date format for netcdf time attributes
  try
      dateFmt = readProperty('exportNetCDF.dateFormat');
  catch e
      dateFmt = 'yyyy-mm-ddTHH:MM:SSZ';
  end

  ncid = netcdf.open(filename, 'NC_NOWRITE');

  globals    = [];
  dimensions = {};
  variables  = {};
  qcVars     = {};

  % get global attributes
  globals = readNetCDFAtts(ncid, netcdf.getConstant('NC_GLOBAL'));

  % transform any time attributes into matlab serial dates
  timeAtts = getTimeAtts();
  for k = 1:length(timeAtts)

    if isfield(globals, timeAtts{k})

      % Aargh, Datenum cannot handle a trailing 'Z',
      % even though it's ISO8601 compliant. Assuming
      % knowledge of the date format here (dropping the last character).
      newTime = 0;
      try
        newTime = datenum(globals.(timeAtts{k}), dateFmt(1:end-1));

      % Glider NetCDF files use doubles for
      % time_coverage_start and time_coverage_end
      catch e
        try newTime = globals.(timeAtts{k}) + datenum('1950-01-01 00:00:00');
        catch e
        end
      end
      globals.(timeAtts{k}) = newTime;
    end
  end

  % update date_created attribute so that the newly exported file has a
  % different creation date
  globals.date_created = now_utc;

  % get dimensions
  k = 0;
  try
    while 1

      [name len] = netcdf.inqDim(ncid, k);

      try
      	% get id of associated coordinate variable
      	varid = netcdf.inqVarID(ncid, name);

      	dimensions{end+1} = readNetCDFVar(ncid, varid);
      	dimensions{end}   = rmfield(dimensions{end}, 'dimensions');

      catch e
      end
      k = k + 1;
    end
  catch e
  end

  % get variable data/attributes
  k = 0;
  try
    while 1

      v = readNetCDFVar(ncid, k);

      k = k + 1;

      % skip dimensions - they have
      % already been added as dimensions
      if getVar(dimensions, v.name) ~= 0, continue; end

      % update dimension IDs
      dims = v.dimensions;
      v.dimensions = [];
      for m = 1:length(dims)

        name = netcdf.inqDim(ncid, dims(m));
        v.dimensions(end+1) = getVar(dimensions, name);
      end

      % collate qc variables separately
      if strfind(v.name, '_quality_control'), qcVars   {end+1} = v;
      else                                    variables{end+1} = v;
      end
    end
  catch e
  end

  netcdf.close(ncid);

  % add QC flags to dimensions
  for k = 1:length(dimensions)

    idx = getVar(qcVars, [dimensions{k}.name '_quality_control']);
    if idx == 0, continue; end
    dimensions{k}.flags = qcVars{idx}.data;
  end

  % and the same for the variables
  for k = 1:length(variables)

    idx = getVar(qcVars, [variables{k}.name '_quality_control']);
    if idx == 0, continue; end
    variables{k}.flags = qcVars{idx}.data;
  end

  % offset time dimension - IMOS files store date as
  % days since 1950; matlab stores as days since 0000
  time = getVar(dimensions, 'TIME');
  if time ~= 0
      dimensions{time}.data = ...
      dimensions{time}.data + datenum('1950-01-01 00:00:00');
  end

  % fill out the resulting struct
  sample_data            = globals;
  sample_data.dimensions = dimensions;
  sample_data.variables  = variables;

  % set meta fields
  if isfield(sample_data, 'file_version')
      sample_data.meta.level = imosFileVersion(sample_data.file_version, 'index');
  end

  sample_data.toolbox_input_file              = filename;

  [~, sample_data.meta.file_name, ext]        = fileparts(filename);
  sample_data.meta.file_name                  = [sample_data.meta.file_name, ext];
  sample_data.meta.site_id                    = '';
  sample_data.meta.survey                     = '';
  sample_data.meta.station                    = '';
  sample_data.meta.instrument_make            = '';
  sample_data.meta.instrument_model           = '';
  sample_data.meta.instrument_serial_no       = '';
  sample_data.meta.instrument_sample_interval = '';
  sample_data.meta.instrument_burst_duration  = '';
  sample_data.meta.instrument_burst_interval  = '';
  sample_data.meta.featureType                = '';

  %special names mappings
  if isfield(sample_data, 'deployment_code')
      sample_data.meta.site_id = sample_data.deployment_code;
  end

  if isfield(sample_data, 'cruise')
      sample_data.meta.survey = sample_data.cruise;
  end

  if isfield(sample_data, 'station')
      sample_data.meta.station = sample_data.station;
  end

  if isfield(sample_data, 'instrument')
      space = ' ';
      [sample_data.meta.instrument_make, sample_data.meta.instrument_model] = strtok(sample_data.instrument, space);
      sample_data.meta.instrument_model = strtrim(sample_data.meta.instrument_model);
  end

  if isfield(sample_data, 'quality_control_log')
      sample_data.meta.log = sample_data.quality_control_log;
  end

  if isfield(sample_data, 'instrument_serial_no')
      sample_data.meta.instrument_serial_no = sample_data.instrument_serial_no;
  end

  if isfield(sample_data, 'instrument_serial_number')
      sample_data.meta.instrument_serial_no = sample_data.instrument_serial_number;
  end

  if isfield(sample_data, 'instrument_beam_angle')
      sample_data.meta.beam_angle = sample_data.instrument_beam_angle;
  end

  if isfield(sample_data, 'instrument_nominal_depth')
      sample_data.meta.depth = sample_data.instrument_nominal_depth;
  end

  % standard naming mappings
  if isfield(sample_data, 'instrument_sample_interval')
      sample_data.meta.instrument_sample_interval = sample_data.instrument_sample_interval;
  end

  if isfield(sample_data, 'instrument_burst_duration')
      sample_data.meta.instrument_burst_duration = sample_data.instrument_burst_duration;
  end

  if isfield(sample_data, 'instrument_burst_interval')
      sample_data.meta.instrument_burst_interval = sample_data.instrument_burst_interval;
  end

  if isfield(sample_data, 'instrument_average_interval')
      sample_data.meta.instrument_average_interval = sample_data.instrument_average_interval;
  end

  if isfield(sample_data, 'featureType')
      sample_data.meta.featureType = sample_data.featureType;
  end

  %custom dimensions mappings
  iHeightAboveSensor = getVar(sample_data.dimensions, 'HEIGHT_ABOVE_SENSOR');
  if iHeightAboveSensor
      sample_data.meta.binSize = diff(sample_data.dimensions{iHeightAboveSensor}.data(1:2));
  end

  iDistAlongBeams = getVar(sample_data.dimensions, 'DIST_ALONG_BEAMS');
  if iDistAlongBeams
      sample_data.meta.binSize = diff(sample_data.dimensions{iDistAlongBeams}.data(1:2));
  end
end

function timeAtts = getTimeAtts()
  timeAtts = {'date_created', 'time_coverage_start', 'time_coverage_end', ...
      'time_deployment_start', 'time_deployment_end','time_deployment_start_origin','time_deployment_end_origin'};

  fid = -1;
  try
      path = readProperty('toolbox.templateDir');
      if isempty(path) || ~exist(path, 'dir')
          path = '';
          if ~isdeployed, [path, ~, ~] = fileparts(which('imosToolbox.m')); end
          if isempty(path), path = pwd; end
          path = fullfile(path, 'NetCDF', 'template');
      end

      file = fullfile(path, 'global_attributes.txt');
      if exist(file,'file') == 2
          % open file for reading
          fid = fopen(file, 'rt');
          if fid == -1, error(['couldn''t open ' file ' for reading']); end

          tkns = textscan(fid,'%c,%s%*[^\n]', 'Whitespace',' \b\t=', 'CommentStyle', '%');
          fclose(fid);
          fid = -1;

          atts = tkns{2}(tkns{1} == 'D');

          if ~isempty(atts)
              timeAtts = atts;
          end

      end
  catch e
      if fid ~= -1, fclose(fid); end
      warning(e.message);
  end
end
