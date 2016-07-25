function sample_data = workhorseParse( filename, tMode )
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
% 
% Inputs:
%   filename    - raw binary data file retrieved from a Workhorse.
%   tMode       - Toolbox data type mode.
%
% Outputs:
%   sample_data - sample_data struct containing the data retrieved from the
%                 input file.
%
% Author:       Paul McCarthy <paul.mccarthy@csiro.au>
% Contributors: Leeying Wu <Wu.Leeying@saugov.sa.gov.au>
%               Bradley Morris <b.morris@unsw.edu.au>
%               Charles James May 2010 <charles.james@sa.gov.au>
%               Guillaume Galibert <guillaume.galibert@utas.edu.au>
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
narginchk(1, 2);

  filename = filename{1};

  % we first look if the file has been processed to extract current and
  % wave data separately (.PD0 and .WVS)
  [filePath, fileRadName, ~] = fileparts(filename);
  
  currentFile   = fullfile(filePath, [fileRadName '.PD0']);
  waveFile      = fullfile(filePath, [fileRadName '.WVS']);
  
  isWaveData = false;
  if exist(currentFile, 'file') && exist(waveFile, 'file')
      % we process current and wave files
      isWaveData = true;
  end
  
  ensembles = readWorkhorseEnsembles( filename );
  
  if isempty(ensembles), error(['no ensembles found in file ' filename]); end
  
  %
  % retrieve metadata and data from struct
  %
  
  fixed = ensembles.fixedLeader;
  
  % metadata for this ensemble
  variable = ensembles.variableLeader;
  
  velocity = ensembles.velocity;
  
  backscatter1 = ensembles.echoIntensity.field1;
  backscatter2 = ensembles.echoIntensity.field2;
  backscatter3 = ensembles.echoIntensity.field3;
  backscatter4 = ensembles.echoIntensity.field4;
  
  correlation1 = ensembles.corrMag.field1;
  correlation2 = ensembles.corrMag.field2;
  correlation3 = ensembles.corrMag.field3;
  correlation4 = ensembles.corrMag.field4;
  
  percentGood1 = ensembles.percentGood.field1;
  percentGood2 = ensembles.percentGood.field2;
  percentGood3 = ensembles.percentGood.field3;
  percentGood4 = ensembles.percentGood.field4;
  clear ensembles;
  
  % we use these to set up variables and dimensions
  % we set a static value for these variables to the most frequent value found
  numBeams   = mode(fixed.numBeams);
  numCells   = mode(fixed.numCells);
  cellLength = mode(fixed.depthCellLength);
  cellStart  = mode(fixed.bin1Distance);
  
  % we can populate distance data now using cellLength and cellStart
  % ( / 100.0, as the ADCP gives the values in centimetres)
  cellStart  = cellStart  / 100.0;
  cellLength = cellLength / 100.0;
  
  % note this is actually distance between the ADCP's transducers and the
  % middle of each cell
  distance = (cellStart):  ...
      (cellLength): ...
      (cellStart + (numCells-1) * cellLength);
  
  % rearrange the sample data
  time = datenum(...
      [variable.y2kCentury*100 + variable.y2kYear,...
      variable.y2kMonth,...
      variable.y2kDay,...
      variable.y2kHour,...
      variable.y2kMinute,...
      variable.y2kSecond + variable.y2kHundredth/100.0]);
  
  timePerPing = fixed.tppMinutes*60 + fixed.tppSeconds + fixed.tppHundredths/100;
  timePerEnsemble = fixed.pingsPerEnsemble .* timePerPing;
%   % shift the timestamp to the middle of the burst
%   time = time + (timePerEnsemble / (3600 * 24))/2;
  
  %
  % auxillary data
  %
  temperature = variable.temperature;
  pressure    = variable.pressure;
  salinity    = variable.salinity;
  pitch       = variable.pitch;
  roll        = variable.roll;
  heading     = variable.heading;
  clear variable;
  
  %
  % calculate velocity (speed and direction)
  % currently assuming earth coordinate transform
  %
  
  veast = velocity.velocity1;
  vnrth = velocity.velocity2;
  wvel  = velocity.velocity3;
  evel  = velocity.velocity4;
  clear velocity;
  
  % set all bad values to NaN.
  vnrth(vnrth == -32768) = NaN;
  veast(veast == -32768) = NaN;
  wvel (wvel  == -32768) = NaN;
  evel (evel  == -32768) = NaN;
  
  %
  % temperature / 100.0  (0.01 deg   -> deg)
  % pressure    / 1000.0 (decapascal -> decibar)
  % vnrth       / 1000.0 (mm/s       -> m/s)
  % veast       / 1000.0 (mm/s       -> m/s)
  % wvel        / 1000.0 (mm/s       -> m/s)
  % evel        / 1000.0 (mm/s       -> m/s)
  % pitch       / 100.0  (0.01 deg   -> deg)
  % roll        / 100.0  (0.01 deg   -> deg)
  % heading     / 100.0  (0.01 deg   -> deg)
  % no conversion for salinity - i'm treating
  % ppt and PSU as interchangeable
  %
  temperature  = temperature  / 100.0;
  pressure     = pressure     / 1000.0;
  vnrth        = vnrth        / 1000.0;
  veast        = veast        / 1000.0;
  wvel         = wvel         / 1000.0;
  evel         = evel         / 1000.0;
  pitch        = pitch        / 100.0;
  roll         = roll         / 100.0;
  heading      = heading      / 100.0;
  
  % check for electrical/magnetic heading bias (usually magnetic declination)
  isMagBias = false;
  % we set a static value for this variable to the most frequent value found
  magDec = mode(fixed.headingBias)*0.01; % Scaling: LSD = 0.01degree; Range = -179.99 to 180.00degrees
  if magDec ~= 0
      isMagBias = true;
      magBiasComment = ['A compass correction of ' num2str(magDec) ...
          'degrees has been applied to the data by a technician using RDI''s software ' ...
          '(usually to account for magnetic declination).'];
  end
  
  speed = sqrt(vnrth.^2 + veast.^2);
  direction = getDirectionFromUV(veast, vnrth);
  
  serial = fixed.instSerialNumber(1); % we assume the first value is correct for the rest of the dataset
  if isnan(serial)
      serial = '';
  else
      serial = num2str(serial);
  end
  
  % fill in the sample_data struct
  sample_data.toolbox_input_file        = filename;
  sample_data.meta.featureType          = ''; % strictly this dataset cannot be described as timeSeriesProfile since it also includes timeSeries data like TEMP
  sample_data.meta.fixedLeader          = fixed;
  sample_data.meta.binSize              = mode(fixed.depthCellLength)/100; % we set a static value for this variable to the most frequent value found
  sample_data.meta.instrument_make      = 'Teledyne RDI';
  
  % try to guess model information
  adcpFreqs = str2num(fixed.systemConfiguration(:, 6:8)); % str2num is actually more relevant than str2double here
  adcpFreq = mode(adcpFreqs); % hopefully the most frequent value reflects the frequency when deployed
  switch adcpFreq
      case 0
          adcpFreq = 75;
          model = 'Long Ranger';
          
      case 1
          adcpFreq = 150;
          model = 'Quartermaster';
          
      case 10
          adcpFreq = 300;
          model = 'Sentinel or Monitor';
          
      case 11
          adcpFreq = 600;
          model = 'Sentinel or Monitor';
          
      case 100
          adcpFreq = 1200;
          model = 'Sentinel or Monitor';
          
      otherwise
          adcpFreq = 2400;
          model = 'Unknown';
          
  end
  
  sample_data.meta.instrument_model     = [model ' Workhorse ADCP'];
  sample_data.meta.instrument_serial_no =  serial;
  sample_data.meta.instrument_sample_interval = median(diff(time*24*3600));
  sample_data.meta.instrument_average_interval = mode(timePerEnsemble);
  sample_data.meta.instrument_firmware  = ...
    strcat(num2str(fixed.cpuFirmwareVersion(1)), '.', num2str(fixed.cpuFirmwareRevision(1))); % we assume the first value is correct for the rest of the dataset
  if all(isnan(fixed.beamAngle))
      sample_data.meta.beam_angle       =  20;  % http://www.hydro-international.com/files/productsurvey_v_pdfdocument_19.pdf
  else
      sample_data.meta.beam_angle       =  mode(fixed.beamAngle); % we set a static value for this variable to the most frequent value found
  end
  
  % add dimensions with their data mapped
  adcpOrientations = str2num(fixed.systemConfiguration(:, 1)); % str2num is actually more relevant than str2double here
  adcpOrientation = mode(adcpOrientations); % hopefully the most frequent value reflects the orientation when deployed
  height = distance;
  if adcpOrientation == 0
      % case of a downward looking ADCP -> negative values
      height = -height;
      distance = -distance;
  end
  iWellOriented = adcpOrientations == adcpOrientation; % we'll only keep data collected when ADCP is oriented as expected
  dims = {
      'TIME',                   time(iWellOriented),    ['Time stamp corresponds to the start of the measurement which lasts ' num2str(sample_data.meta.instrument_average_interval) ' seconds.']; ...
      'HEIGHT_ABOVE_SENSOR',    height(:),              'Data has been vertically bin-mapped using tilt information so that the cells have consistant heights above sensor in time.'; ...
      'DIST_ALONG_BEAMS',       distance(:),            'Data is not vertically bin-mapped (no tilt correction applied). Cells are lying parallel to the beams, at heights above sensor that vary with tilt.'
      };
  clear time height distance;
  
  nDims = size(dims, 1);
  sample_data.dimensions = cell(nDims, 1);
  for i=1:nDims
      sample_data.dimensions{i}.name         = dims{i, 1};
      sample_data.dimensions{i}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(dims{i, 1}, 'type')));
      sample_data.dimensions{i}.data         = sample_data.dimensions{i}.typeCastFunc(dims{i, 2});
      sample_data.dimensions{i}.comment      = dims{i, 3};
  end
  clear dims;
  
  % add information about the middle of the measurement period
  sample_data.dimensions{1}.seconds_to_middle_of_measurement = sample_data.meta.instrument_average_interval/2;
  
  % add variables with their dimensions and data mapped
  if isMagBias
      magExt = '';
  else
      magExt = '_MAG';
  end
  
  vars = {
      'TIMESERIES',         [],     1; ...
      'LATITUDE',           [],     NaN; ...
      'LONGITUDE',          [],     NaN; ...
      'NOMINAL_DEPTH',      [],     NaN; ...
      ['VCUR' magExt],      [1 2],  vnrth(iWellOriented, :); ...
      ['UCUR' magExt],      [1 2],  veast(iWellOriented, :); ...
      'WCUR',               [1 2],  wvel(iWellOriented, :); ...
      'ECUR',               [1 2],  evel(iWellOriented, :); ...
      'CSPD',               [1 2],  speed(iWellOriented, :); ...
      ['CDIR' magExt],      [1 2],  direction(iWellOriented, :); ...
      'ABSIC1',              [1 3],  backscatter1(iWellOriented, :); ...
      'ABSIC2',              [1 3],  backscatter2(iWellOriented, :); ...
      'ABSIC3',              [1 3],  backscatter3(iWellOriented, :); ...
      'ABSIC4',              [1 3],  backscatter4(iWellOriented, :); ...
      'TEMP',               1,      temperature(iWellOriented); ...
      'PRES_REL',           1,      pressure(iWellOriented); ...
      'PSAL',               1,      salinity(iWellOriented); ...
      'CMAG1',              [1 3],  correlation1(iWellOriented, :); ...
      'CMAG2',              [1 3],  correlation2(iWellOriented, :); ...
      'CMAG3',              [1 3],  correlation3(iWellOriented, :); ...
      'CMAG4',              [1 3],  correlation4(iWellOriented, :); ...
      'PERG1',              [1 2],  percentGood1(iWellOriented, :); ...
      'PERG2',              [1 2],  percentGood2(iWellOriented, :); ...
      'PERG3',              [1 2],  percentGood3(iWellOriented, :); ...
      'PERG4',              [1 2],  percentGood4(iWellOriented, :); ...
      'PITCH',              1,      pitch(iWellOriented); ...
      'ROLL',               1,      roll(iWellOriented); ...
      ['HEADING' magExt],   1,      heading(iWellOriented)
      };
  
  clear vnrth veast wvel evel speed direction backscatter1 ...
      backscatter2 backscatter3 backscatter4 temperature pressure ...
      salinity correlation1 correlation2 correlation3 correlation4 ...
      percentGood1 percentGood2 percentGood3 percentGood4 pitch roll ...
      heading;
  
  nVars = size(vars, 1);
  sample_data.variables = cell(nVars, 1);
  for i=1:nVars
      sample_data.variables{i}.name         = vars{i, 1};
      sample_data.variables{i}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(vars{i, 1}, 'type')));
      sample_data.variables{i}.dimensions   = vars{i, 2};
      
      % we don't want coordinates attribute for LATITUDE, LONGITUDE and NOMINAL_DEPTH
      if ~isempty(sample_data.variables{i}.dimensions)
          switch sample_data.variables{i}.dimensions(end)
              case 1
                  sample_data.variables{i}.coordinates = 'TIME LATITUDE LONGITUDE NOMINAL_DEPTH';
              case 2
                  sample_data.variables{i}.coordinates = 'TIME LATITUDE LONGITUDE HEIGHT_ABOVE_SENSOR';
              case 3
                  sample_data.variables{i}.coordinates = 'TIME LATITUDE LONGITUDE DIST_ALONG_BEAMS';
          end
      end
      
      sample_data.variables{i}.data         = sample_data.variables{i}.typeCastFunc(vars{i, 3});
      if strcmpi(vars{i, 1}, 'PRES_REL')
          sample_data.variables{i}.applied_offset = sample_data.variables{i}.typeCastFunc(-gsw_P0/10^4); % (gsw_P0/10^4 = 10.1325 dbar)
      end
      if any(strcmpi(vars{i, 1}, {'VCUR', 'UCUR', 'CDIR', 'HEADING'}))
          sample_data.variables{i}.compass_correction_applied = magDec;
          sample_data.variables{i}.comment = magBiasComment;
      end
  end
  clear vars;
  
  % remove auxillary data if the sensors 
  % were not installed on the instrument
  hasPres    = mode(str2num(fixed.sensorsAvailable(:, 3))); % str2num is actually more relevant than str2double here
  hasHeading = mode(str2num(fixed.sensorsAvailable(:, 4)));
  hasPitch   = mode(str2num(fixed.sensorsAvailable(:, 5)));
  hasRoll    = mode(str2num(fixed.sensorsAvailable(:, 6)));
  hasPsal    = mode(str2num(fixed.sensorsAvailable(:, 7)));
  hasTemp    = mode(str2num(fixed.sensorsAvailable(:, 8)));

  % indices of variables to remove
  remove = [];
  
  if ~hasPres,    remove(end+1) = getVar(sample_data.variables, 'PRES_REL');end
  if ~hasHeading, remove(end+1) = getVar(sample_data.variables, 'HEADING'); end
  if ~hasPitch,   remove(end+1) = getVar(sample_data.variables, 'PITCH');   end
  if ~hasRoll,    remove(end+1) = getVar(sample_data.variables, 'ROLL');    end
  if ~hasPsal,    remove(end+1) = getVar(sample_data.variables, 'PSAL');    end
  if ~hasTemp,    remove(end+1) = getVar(sample_data.variables, 'TEMP');    end
  
  % also remove empty backscatter and correlation data in case of ADCP with
  % less than 4 beams
  for k = 4:-1:numBeams+1
      kStr = num2str(k);
      remove(end+1) = getVar(sample_data.variables, ['ABSIC' kStr]);
      remove(end+1) = getVar(sample_data.variables, ['CMAG' kStr]);
      remove(end+1) = getVar(sample_data.variables, ['PERG' kStr]);
  end
  
  sample_data.variables(remove) = [];
  
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
          ['DIR' magExt],           waveData.Dspec.dir,     ''
          };
      
      nDims = size(dims, 1);
      sample_data{2}.dimensions = cell(nDims, 1);
      for i=1:nDims
          sample_data{2}.dimensions{i}.name         = dims{i, 1};
          sample_data{2}.dimensions{i}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(dims{i, 1}, 'type')));
          sample_data{2}.dimensions{i}.data         = sample_data{2}.dimensions{i}.typeCastFunc(dims{i, 2});
          if strcmpi(dims{i, 1}, 'DIR')
              sample_data{2}.dimensions{i}.compass_correction_applied = magDec;
              sample_data{2}.dimensions{i}.comment  = magBiasComment;
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
          'WSSH',           1,          waveData.param.Hs; ...   % sea_surface_wave_spectral_significant_height
          'WPPE',           1,          waveData.param.Tp; ...   % sea_surface_wave_period_at_variance_spectral_density_maximum
          ['WPDI' magExt],  1,          waveData.param.Dp; ...   % sea_surface_wave_from_direction_at_variance_spectral_density_maximum
          'WWSH',           1,          waveData.param.Hs_W; ... % sea_surface_wind_wave_significant_height
          'WWPP',           1,          waveData.param.Tp_W; ... % sea_surface_peak_wind_sea_wave_period
          ['WWPD' magExt],  1,          waveData.param.Dp_W; ... % sea_surface_peak_wind_sea_wave_from_direction
          'SWSH',           1,          waveData.param.Hs_S; ... % sea_surface_swell_wave_significant_height
          'SWPP',           1,          waveData.param.Tp_S; ... % sea_surface_peak_swell_wave_period
          ['SWPD' magExt],  1,          waveData.param.Dp_S; ... % sea_surface_peak_swell_wave_from_direction
          % ht is in mm
          'DEPTH',          1,          waveData.param.ht/1000; ...
          'WMXH',           1,          waveData.param.Hmax; ...  % sea_surface_wave_maximum_height
          'WMPP',           1,          waveData.param.Tmax; ...  % sea_surface_wave_maximum_zero_crossing_period
          'WHTH',           1,          waveData.param.Hth; ...   % sea_surface_wave_significant_height_of_highest_one_third
          'WPTH',           1,          waveData.param.Tth; ...   % sea_surface_wave_period_of_highest_one_third
          'WMSH',           1,          waveData.param.Hmn; ...   % sea_surface_wave_zero_crossing_mean_height
          'WPMH',           1,          waveData.param.Tmn; ...   % sea_surface_wave_zero_crossing_period
          'WHTE',           1,          waveData.param.Hte; ...   % sea_surface_wave_significant_height_of_highest_one_tenth
          'WPTE',           1,          waveData.param.Tte; ...   % sea_surface_wave_period_of_highest_one_tenth
          ['VDIR' magExt],  1,          waveData.param.Dmn; ...   % sea_surface_wave_from_direction
          % Vspec is in mm/sqrt(Hz)
          'VDEV',           [1 2],      (waveData.Vspec.data/1000).^2; ... % sea_surface_wave_variance_spectral_density_from_velocity
          'VDEP',           [1 2],      (waveData.Pspec.data/1000).^2; ... % sea_surface_wave_variance_spectral_density_from_pressure
          'VDES',           [1 2],      (waveData.Sspec.data/1000).^2; ... % sea_surface_wave_variance_spectral_density_from_range_to_surface
          % Dspec is in mm^2/Hz/deg
          ['SSWV' magExt],  [1 2 3],    waveData.Dspec.data/1000.^2 % sea_surface_wave_directional_variance_spectral_density
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
              sample_data{2}.variables{i}.compass_correction_applied = magDec;
              sample_data{2}.variables{i}.comment  = magBiasComment;
          end
      end
      clear vars;
  end
end

function direction = getDirectionFromUV(uvel, vvel)
    % direction is in degrees clockwise from north
    direction = atan(abs(uvel ./ vvel)) .* (180 / pi);
    
    % !!! if vvel == 0 we get NaN !!!
    direction(vvel == 0) = 90;
    
    se = vvel <  0 & uvel >= 0;
    sw = vvel <  0 & uvel <  0;
    nw = vvel >= 0 & uvel <  0;
    
    direction(se) = 180 - direction(se);
    direction(sw) = 180 + direction(sw);
    direction(nw) = 360 - direction(nw);
end

function angle = make0To360(angle)
    iLower = angle < 0;
    angle(iLower) = 360 + angle(iLower);
    
    iHigher = angle >= 360;
    angle(iHigher) = angle(iHigher) - 360;
end