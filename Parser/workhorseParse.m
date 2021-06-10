function sample_data = workhorseParse( filename, ~)
%WORKHORSEPARSE Parses a raw (binary) data file from a Teledyne RD Workhorse
% ADCP.
%
% This function uses the readWorkhorseEnsembles function to read in a set
% of ensembles from a raw binary PD0 Workhorse ADCP file. It parses the
% ensembles, and extracts and returns the following:
%
%   - time
%   - temperature (at each time)
%   - pressure (at each time, if present)
%   - salinity (at each time, if present)
%   - water speed (at each time and distance)
%   - water direction (at each time and distance)
%   - Acoustic backscatter intensity (at each time and distance, a separate
%     variable for each beam)
%
% The conversion from the ADCP velocity values currently assumes that the
% ADCP is using earth coordinates (see section 13.4 'Velocity Data Format'
% of the Workhorse H-ADCP Operation Manual).
% Add code to convert Beam coordinates to ENU. RC July, 2020.
%
% Inputs:
%   filename [char]   - raw binary data file path retrieved from a Workhorse.
%
% Outputs:
%   sample_data - sample_data struct containing the data retrieved from the
%                 input file.
%
% Author:       Paul McCarthy <paul.mccarthy@csiro.au>
% Contributors: 
%               Leeying Wu <Wu.Leeying@saugov.sa.gov.au>
%               Bradley Morris <b.morris@unsw.edu.au>
%               Charles James May 2010 <charles.james@sa.gov.au>
%               Guillaume Galibert <guillaume.galibert@utas.edu.au>
%               Shawn Meredyk <shawn.meredyk@as.ulaval.ca>
%               Hugo Oliveira <hugo.oliveira@utas.edu.au>
%
  narginchk(1, 2);
  sample_data = struct();

  filename = filename{1};

  % we first look if the file has been processed to extract current and
  % wave data separately (.PD0 and .WVS)
  [filePath, fileRadName, ~] = fileparts(filename);

  currentFile   = fullfile(filePath, [fileRadName '.PD0']);
  waveFile      = fullfile(filePath, [fileRadName '.WVS']);

  isWaveData = exist(currentFile, 'file') && exist(waveFile, 'file');
  ensembles = readWorkhorseEnsembles(filename);
  if isempty(ensembles)
    errormsg('no ensembles found in file %s',filename);
  end

  sample_data.toolbox_input_file = filename;
  meta = Workhorse.load_fixedLeader_metadata(ensembles.fixedLeader);

  no_magnetic_corrections = meta.compass_correction_applied == 0;
  if no_magnetic_corrections
    magdec_name_extension = '_MAG';
    magdec_attrs = struct('comment','');
     else
    magdec_name_extension = '';
    comment_msg = ['A compass correction of ' num2str(meta.compass_correction_applied) ...
          'degrees has been applied to the data by a technician using RDI''s software ' ...
          '(usually to account for magnetic declination).'];
    magdec_attrs = struct('compass_correction_applied',meta.compass_correction_applied, 'comment',comment_msg);
  end

  dimensions = IMOS.gen_dimensions('adcp');

  time = Workhorse.convert_time(ensembles.variableLeader,meta.instrument_firmware);
  timePerPing = 60.*ensembles.fixedLeader.tppMinutes + ensembles.fixedLeader.tppSeconds + 0.01.*ensembles.fixedLeader.tppHundredths;
  timePerEnsemble = ensembles.fixedLeader.pingsPerEnsemble .* timePerPing;

  meta.instrument_sample_interval   = mode(diff(time*24*3600));
  meta.instrument_average_interval  = mode(timePerEnsemble);

  dimensions{1}.data = time;
  dimensions{1}.comment = ['Time stamp corresponds to the start of the measurement which lasts ' num2str(meta.instrument_average_interval) ' seconds.'];
  dimensions{1}.seconds_to_middle_of_measurement = meta.instrument_average_interval/2;

  distance = 0.01.*Workhorse.cell_cdistance(mode(ensembles.fixedLeader.bin1Distance),...
    mode(ensembles.fixedLeader.depthCellLength),...
    mode(ensembles.fixedLeader.numCells),...
    meta.adcp_info.beam_face_config); %cm to m

  dimensions{2}.data = distance;  %TODO: it doesn't make sense to use negative values for DIST_ALONG_BEAMS even if downward facing, but we need to be backward compatible.
  dimensions{2}.comment = ['Values correspond to the distance between the instrument''s transducers and the centre of each cells. ' ...
      'Data is not vertically bin-mapped (no tilt correction applied). Cells are lying parallel to the beams, at heights above sensor that vary with tilt.'];

  %cherry-pick the raw fields we wish to import and avoid copies lying around.
  [imap, vel_vars, beam_vars, ts_vars] = Workhorse.import_mappings(meta.adcp_info.sensors_settings,...
                                                                   meta.adcp_info.number_of_beams,...,
                                                                   magdec_name_extension,...,
                                                                   meta.adcp_info.coords.frame_of_reference);
  ivars = fieldnames(imap);
  for k=1:numel(ivars)
    vname = ivars{k};
    vaddr = imap.(vname);
    ogroup = vaddr{1};
    ovar = vaddr{2};
    try
      imported.(vname) = ensembles.(ogroup).(ovar);
    catch
      %raise a nice error msg in case the ensembles functionality is changed 
      % and we didn't update the import maps, or the import mapping is outdated.
      errormsg('Trying to associate vname=%s with associated with ogroup=%s and ovar=%s failed!',vname,ogroup,ovar)
    end
    ensembles.(ogroup) = rmfield(ensembles.(ogroup),ovar);
  end

  % assume bad orientation beams measurements are missing data.
  %TODO: this should be a pre-processing or be dropped.
  orientation_bit = strcmpi(meta.adcp_info.beam_face_config,'Up'); %0 for Down, 1 for Up.
  bad_orientation = ensembles.fixedLeader.systemConfiguration(:,1) ~= orientation_bit;
  binned_vars = [vel_vars,beam_vars];
  for k=1:numel(binned_vars)
      vname = binned_vars{k};
      imported.(vname)(bad_orientation,:) = NaN;
  end
  clear ensembles

  % fill-in missing velocity data based on RDI manual information.
  %TODO: this should be a pre-processing.
  missing_val = -32768;%-2.^15;
  fill_missing_with_nan = @(x)(fillwith(x,NaN,x==missing_val));
  for k=1:numel(vel_vars)
    vname = vel_vars{k};
    missing = imported.(vname) == missing_val;
    imported.(vname)(missing) = NaN;
  end

  % load voltage as diagnostic with nan filling
  %TODO: this should be a pre-processing.
  % There are 8 ADC channels and this results in the following nuances:
  %     a. Only one ADC channel is sampled at a time per ping.  This means it takes 8 pings in order to sample all 8 channels.
  %     b. Until 8 pings have happened the data in a given channel is not valid (NaN).
  %     c. Once 8 pings have happened the last value for each channel sampled will be stored into the leader data until the next sample is made.
  %     d. Only the last sample made is stored; there is no accumulation or averaging of the ADC channels.
  %     e. The ADC channels are stored over ensembles meaning the ADC channel is not reset until the instrument deployment is stopped.
  %     f. Examples:
  %         i.  If you do 4 pings and then stop the deployment, only ADC channels 0-3 are valid.
  %         ii. If you do 12 pings and then stop the deployment, ADCP channels 0-3 will be updated with values from pings 9-12 respectively, and channels 4-7 will be updated with values from pings 4-7 respectively.
  imported.('TX_VOLT') = fillmissing(imported.('TX_VOLT'),'next');
  volt_attr = struct('comment', ['This parameter is actually the transmit voltage (ADC channel 1), which is NOT the same as battery voltage. ' ...
      'The transmit voltage is sampled after a DC/DC converter and as such does not represent the true battery voltage. ' ...
      'It does give a relative illustration of the battery voltage though which means that it will drop as the battery ' ...
      'voltage drops. In addition, The circuit is not calibrated which means that the measurement is noisy and the values ' ...
      'will vary between same frequency WH ADCPs.']);


  % inplace conversions
  cmap = Workhorse.conversion_mappings(meta.adcp_info.sensors_settings,...
                                       magdec_name_extension,...
                                       meta.adcp_info.xmit_voltage_scale,...
                                       meta.adcp_info.coords.frame_of_reference);

  cvars = fieldnames(cmap);
  for k=1:numel(cvars)
    vname = cvars{k};
    imported.(vname) = cmap.(vname)(imported.(vname));
  end

  % derived variables
  switch meta.adcp_info.coords.frame_of_reference
    case 'earth'
      all_vel_vars = [vel_vars, 'CSPD', ['CDIR' magdec_name_extension]];
      u = imported.(['UCUR' magdec_name_extension]);
      v = imported.(['VCUR' magdec_name_extension]);
      imported.('CSPD') = hypot(u,v);
      imported.(['CDIR' magdec_name_extension]) = azimuth_direction(u,v);
    case 'beam'
      all_vel_vars = vel_vars;
  end

  %define toolbox struct.
  vars0d = IMOS.featuretype_variables('timeSeries'); %basic vars from timeSeries

  coords1d = 'TIME LATITUDE LONGITUDE NOMINAL_DEPTH';
  vars1d = IMOS.gen_variables(dimensions,ts_vars,{},fields2cell(imported,ts_vars),'coordinates',coords1d);

  coords2d_beam = 'TIME LATITUDE LONGITUDE DIST_ALONG_BEAMS';
  vars2d_beam = IMOS.gen_variables(dimensions,beam_vars,{},fields2cell(imported,beam_vars),'coordinates',coords2d_beam);
 
  switch meta.adcp_info.coords.frame_of_reference
    case 'beam'
      coords2d_vel = 'TIME LATITUDE LONGITUDE DIST_ALONG_BEAMS';
      vars2d_vel = IMOS.gen_variables(dimensions,all_vel_vars,{},fields2cell(imported,all_vel_vars),'coordinates',coords2d_vel);
    case 'earth'
      coords2d_vel = 'TIME LATITUDE LONGITUDE HEIGHT_ABOVE_SENSOR';
      earth_dims = [1,3];

      dimensions{3}.name = 'HEIGHT_ABOVE_SENSOR';
      dimensions{3}.typeCastFunc = IMOS.resolve.imos_type('HEIGHT_ABOVE_SENSOR');
      dimensions{3}.data = distance;
      dimensions{3}.comment = ['Values correspond to the distance between the instrument''s transducers and the centre of each cells. ' ...
      'Data has been vertically bin-mapped using tilt information so that the cells have consistent heights above sensor in time.'];

      vars2d_vel = cell(1,numel(all_vel_vars));
      for k=1:numel(all_vel_vars)
        vname = all_vel_vars{k};
        %force conversion for backward compatibility - this incur in at least 4 type-conversion from original data to netcdf - madness!
        typecast_func = IMOS.resolve.imos_type(vname);
        type_converted_var = typecast_func(imported.(vname));
        imported = rmfield(imported,vname);
        vars2d_vel{k} = struct('name',vname,'typeCastFunc',typecast_func,'dimensions',earth_dims,'data',type_converted_var,'coordinates',coords2d_vel);
      end          
    otherwise 
         errormsg('Frame of reference `%s` not supported',meta.adcp_info.coords.frame_of_reference)
  end
  sample_data.meta = meta;
  sample_data.dimensions = dimensions;
  sample_data.variables = [vars0d,vars2d_vel,vars2d_beam,vars1d]; % follow prev conventions

  %%particular attributes
  xattrs = containers.Map('KeyType','char','ValueType','any');
  switch meta.adcp_info.coords.frame_of_reference
    case 'earth'
      xattrs(['UCUR' magdec_name_extension]) = magdec_attrs;
      xattrs(['VCUR' magdec_name_extension]) = magdec_attrs;
      xattrs(['CDIR' magdec_name_extension]) = magdec_attrs;
  end

  xattrs('TX_VOLT') = volt_attr;
  cast_fun = IMOS.resolve.imos_type('PRES_REL');
  xattrs('PRES_REL') = struct('applied_offset',cast_fun(-gsw_P0/10^4)); % (gsw_P0/10^4 = 10.1325 dbar)

  indexes = IMOS.find(sample_data.variables,xattrs.keys);
  for vind = indexes
    iname = sample_data.variables{vind}.name;
    sample_data.variables{vind} = combineStructFields(sample_data.variables{vind},xattrs(iname));
  end

  %TODO: Refactor below - search for testing files.
  if isWaveData
      %
      % if wave data files are present, read them in
      %
      filename = waveFile;

      waveData = readWorkhorseWaveAscii(filename);

      % turn sample data into a cell array
      temp{1} = sample_data;
      sample_data = temp;
      clear temp;

      % copy wave data into a sample_data struct; start with a copy of the
      % first sample_data struct, as all the metadata is the same
      sample_data{2} = sample_data{1};

      sample_data{2}.toolbox_input_file              = filename;
      sample_data{2}.meta.head                       = [];
      sample_data{2}.meta.hardware                   = [];
      sample_data{2}.meta.user                       = [];
      sample_data{2}.meta.instrument_sample_interval = median(diff(waveData.param.time*24*3600));

      avgInterval = [];
      if isfield(waveData, 'summary')
          iMatch = ~cellfun(@isempty, regexp(waveData.summary, 'Each Burst Contains  [0-9]* Samples, Taken at [0-9\.]* Hz.'));
          if any(iMatch)
              avgInterval = textscan(waveData.summary{iMatch}, 'Each Burst Contains  %f Samples, Taken at %f Hz.');
              avgInterval = avgInterval{1}/avgInterval{2};
          end
      end
      sample_data{2}.meta.instrument_average_interval = avgInterval;
      if isempty(avgInterval), avgInterval = '?'; end

      sample_data{2}.dimensions = {};
      sample_data{2}.variables  = {};

      % add dimensions with their data mapped
      dims = {
          'TIME',                   waveData.param.time,    ['Time stamp corresponds to the start of the measurement which lasts ' num2str(avgInterval) ' seconds.']; ...
          'FREQUENCY',              waveData.Dspec.freq,    ''; ...
          ['DIR' magdec_name_extension],           waveData.Dspec.dir,     ''
          };

      nDims = size(dims, 1);
      sample_data{2}.dimensions = cell(nDims, 1);
      for i=1:nDims
          sample_data{2}.dimensions{i}.name         = dims{i, 1};
          sample_data{2}.dimensions{i}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(dims{i, 1}, 'type')));
          sample_data{2}.dimensions{i}.data         = sample_data{2}.dimensions{i}.typeCastFunc(dims{i, 2});
          if strcmpi(dims{i, 1}, 'DIR')
              sample_data{2}.dimensions{i}.compass_correction_applied = meta.compass_correction_applied;
              sample_data{2}.dimensions{i}.comment  = magdec_attrs.comment;
          end
      end
      clear dims;

      % add information about the middle of the measurement period
      sample_data{2}.dimensions{1}.seconds_to_middle_of_measurement = sample_data{2}.meta.instrument_average_interval/2;

      % add variables with their dimensions and data mapped
      vars = {
          'TIMESERIES',     [],         1; ...
          'LATITUDE',       [],         NaN; ...
          'LONGITUDE',      [],         NaN; ...
          'NOMINAL_DEPTH',  [],         NaN; ...
          'WSSH',           1,          waveData.param.Hs; ...   % Significant Wave Height Hs = 4 sqrt(M0)
          'WPPE',           1,          waveData.param.Tp; ...   % Peak Wave Period (seconds) - period associated with the largest peak in the power spectrum
          ['WPDI' magdec_name_extension],  1,          waveData.param.Dp; ...   % Peak Wave Direction (degrees) - peak direction at the peak period
          'WWSH',           1,          waveData.param.Hs_W; ... % Significant Wave Height in the sea region of the power spectrum
          'WWPP',           1,          waveData.param.Tp_W; ... % Peak Sea Wave Period (seconds) - period associated with the largest peak in the sea region of the power spectrum
          ['WWPD' magdec_name_extension],  1,          waveData.param.Dp_W; ... % Peak Sea Wave Direction (degrees) - peak sea direction at the peak period in the sea region
          'SWSH',           1,          waveData.param.Hs_S; ... % Significant Wave Height in the swell region of the power spectrum
          'SWPP',           1,          waveData.param.Tp_S; ... % Peak Swell Wave Period (seconds) - period associated with the largest peak in the swell region of the power spectrum
          ['SWPD' magdec_name_extension],  1,          waveData.param.Dp_S; ... % Peak Swell Wave Direction (degrees) - peak swell direction at the peak period in the swell region
          % ht is in mm
          'DEPTH',          1,          waveData.param.ht/1000; ...
          'WMXH',           1,          waveData.param.Hmax; ...  % Maximum wave height (meters) as determined by Zero-Crossing analysis of the surface track time series
          'WMPP',           1,          waveData.param.Tmax; ...  % Maximum Peak Wave Period (seconds) as determined by Zero-Crossing analysis of the surface track time series
          'WHTH',           1,          waveData.param.Hth; ...   % Significant wave height of the largest 1/3 of the waves in the field as determined by Zero-Crossing analysis of the surface track time series
          'WPTH',           1,          waveData.param.Tth; ...   % The period associated with the peak wave height of the largest 1/3 of the waves in the field as determined by Zero-Crossing analysis of the surface track time series
          'WMSH',           1,          waveData.param.Hmn; ...   % The mean significant wave height of the waves in the field as determined by Zero-Crossing analysis of the surface track time series
          'WPMH',           1,          waveData.param.Tmn; ...   % The period associated with the mean significant wave height of the waves in the field as determined by Zero-Crossing analysis of the surface track time series
          'WHTE',           1,          waveData.param.Hte; ...   % Significant wave height of the largest 1/10 of the waves in the field as determined by Zero-Crossing analysis of the surface track time series
          'WPTE',           1,          waveData.param.Tte; ...   % The period associated with the peak wave height of the largest 1/10 of the waves in the field as determined by Zero-Crossing analysis of the surface track time series
          ['VDIR' magdec_name_extension],  1,          waveData.param.Dmn; ...   % Mean Peak Wave Direction
          % Vspec is in mm/sqrt(Hz)
          'VDEV',           [1 2],      (waveData.Vspec.data/1000).^2; ... % sea_surface_wave_variance_spectral_density_from_velocity
          'VDEP',           [1 2],      (waveData.Pspec.data/1000).^2; ... % sea_surface_wave_variance_spectral_density_from_pressure
          'VDES',           [1 2],      (waveData.Sspec.data/1000).^2; ... % sea_surface_wave_variance_spectral_density_from_range_to_surface
          % Dspec is in mm^2/Hz/deg
          ['SSWV' magdec_name_extension],  [1 2 3],    waveData.Dspec.data/1000.^2 % sea_surface_wave_directional_variance_spectral_density
          };
      clear waveData;

      nVars = size(vars, 1);
      sample_data{2}.variables = cell(nVars, 1);
      for i=1:nVars
          sample_data{2}.variables{i}.name         = vars{i, 1};
          sample_data{2}.variables{i}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(vars{i, 1}, 'type')));
          sample_data{2}.variables{i}.dimensions   = vars{i, 2};
          if ~isempty(vars{i, 2}) % we don't want this for scalar variables
              if strcmpi(vars{i, 1}, 'DEPTH')
                  sample_data{2}.variables{i}.coordinates = 'TIME LATITUDE LONGITUDE NOMINAL_DEPTH';
              else
                  sample_data{2}.variables{i}.coordinates = 'TIME LATITUDE LONGITUDE'; % data at the surface, can be inferred from standard/long names
              end
          end
          sample_data{2}.variables{i}.data         = sample_data{2}.variables{i}.typeCastFunc(vars{i, 3});
          if any(strcmpi(vars{i, 1}, {'WPDI', 'WWPD', 'SWPD', 'VDIR', 'SSWV'}))
              sample_data{2}.variables{i}.compass_correction_applied = meta.compass_correction_applied;
              sample_data{2}.variables{i}.comment  = magdec_attrs.comment;
          end
      end
      clear vars;
  end
end
