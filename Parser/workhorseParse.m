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
%               Shawn Meredyk <shawn.meredyk@as.ulaval.ca>
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
  distance = (cellStart:  ...
      cellLength: ...
      cellStart + (numCells-1) * cellLength)';
  
  % rearrange the sample data
  instrument_firmware = strcat(num2str(fixed.cpuFirmwareVersion(1)), '.', num2str(fixed.cpuFirmwareRevision(1))); % we assume the first value is correct for the rest of the dataset
  if str2double(instrument_firmware) > 8.35
      time = datenum(...
          [variable.y2kCentury*100 + variable.y2kYear,...
          variable.y2kMonth,...
          variable.y2kDay,...
          variable.y2kHour,...
          variable.y2kMinute,...
          variable.y2kSecond + variable.y2kHundredth/100.0]);
  else
      % looks like before firmware 8.35 included, Y2K compliant RTC time 
      % was not implemented
      century = 2000;
      if variable.rtcYear(1) > 70 
          % first ADCP was built in the mid 1970s
          % hopefully this firmware will no longer be used
          % in 2070...
          century = 1900;
      end
      time = datenum(...
          [century + variable.rtcYear,...
          variable.rtcMonth,...
          variable.rtcDay,...
          variable.rtcHour,...
          variable.rtcMinute,...
          variable.rtcSecond + variable.rtcHundredths/100.0]);
  end
  
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
  voltage     = variable.adcChannel1;
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
  magExt = '_MAG';
  magBiasComment = '';
  % we set a static value for this variable to the most frequent value found
  magDec = mode(fixed.headingBias)*0.01; % Scaling: LSD = 0.01degree; Range = -179.99 to 180.00degrees
  if magDec ~= 0
      magExt = '';
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
  
  % try to guess model information
  adcpFreqs = str2num(fixed.systemConfiguration(:, 6:8)); % str2num is actually more relevant than str2double here
  adcpFreq = mode(adcpFreqs); % hopefully the most frequent value reflects the frequency when deployed
  switch adcpFreq
      case 0
          adcpFreq = 75;
          model = 'Long Ranger';
          xmitVoltScaleFactors = 2092719;
          
      case 1
          adcpFreq = 150;
          model = 'Quartermaster';
          xmitVoltScaleFactors = 592157;
		  
      case 10
          adcpFreq = 300;
          model = 'Sentinel or Monitor';
          xmitVoltScaleFactors = 592157;
		  
      case 11
          adcpFreq = 600;
          model = 'Sentinel or Monitor';
          xmitVoltScaleFactors = 380667;
		  
      case 100
          adcpFreq = 1200;
          model = 'Sentinel or Monitor';
          xmitVoltScaleFactors = 253765;
		  
      otherwise
          adcpFreq = 2400;
          model = 'DVS';
          xmitVoltScaleFactors = 253765;
  end
  xmitVoltScaleFactors = xmitVoltScaleFactors / 1000000; %from p.136 of Workhorse Commands and Output Data Format PDF (RDI website - March 2016)
   
  % converting xmit voltage counts to volts for diagnostics.
  voltage = voltage * xmitVoltScaleFactors;
  voltComment = ['This parameter is actually the transmit voltage (ADC channel 1), which is NOT the same as battery voltage. ' ...
      'The transmit voltage is sampled after a DC/DC converter and as such does not represent the true battery voltage. ' ...
      'It does give a relative illustration of the battery voltage though which means that it will drop as the battery ' ...
      'voltage drops. In addition, The circuit is not calibrated which means that the measurement is noisy and the values ' ...
      'will vary between same frequency WH ADCPs.'];
  
  % There are 8 ADC channels and this results in the following nuances: 
  %     a. Only one ADC channel is sampled at a time per ping.  This means it takes 8 pings in order to sample all 8 channels.
  %     b. Until 8 pings have happened the data in a given channel is not valid (NaN).
  %     c. Once 8 pings have happened the last value for each channel sampled will be stored into the leader data until the next sample is made.
  %     d. Only the last sample made is stored; there is no accumulation or averaging of the ADC channels.
  %     e. The ADC channels are stored over ensembles meaning the ADC channel is not reset until the instrument deployment is stopped.
  %     f. Examples:
  %         i.  If you do 4 pings and then stop the deployment, only ADC channels 0-3 are valid.
  %         ii. If you do 12 pings and then stop the deployment, ADCP channels 0-3 will be updated with values from pings 9-12 respectively, and channels 4-7 will be updated with values from pings 4-7 respectively.
  iNaNVoltage = isnan(voltage);
  if iNaNVoltage(end) % we need to deal separately with the last value in case it's NaN
      iLastGoodValue = find(~iNaNVoltage, 1, 'last');  % in this case we have no choice but to look for the previous available value before it
      voltage(end) = voltage(iLastGoodValue);
      iNaNVoltage(end) = false;
  end
  % set any NaN to the next available value after it (conservative approach)
  while any(iNaNVoltage)
      iNextValue = [false; iNaNVoltage(1:end-1)];
      voltage(iNaNVoltage) = voltage(iNextValue);
      iNaNVoltage = isnan(voltage);
  end
  
  % fill in the sample_data struct
  sample_data.toolbox_input_file                = filename;
  sample_data.meta.featureType                  = ''; % strictly this dataset cannot be described as timeSeriesProfile since it also includes timeSeries data like TEMP
  sample_data.meta.fixedLeader                  = fixed;
  sample_data.meta.binSize                      = mode(fixed.depthCellLength)/100; % we set a static value for this variable to the most frequent value found
  sample_data.meta.instrument_make              = 'Teledyne RDI';
  sample_data.meta.instrument_model             = [model ' Workhorse ADCP'];
  sample_data.meta.instrument_serial_no         =  serial;
  sample_data.meta.instrument_sample_interval   = median(diff(time*24*3600));
  sample_data.meta.instrument_average_interval  = mode(timePerEnsemble);
  sample_data.meta.instrument_firmware          = instrument_firmware;
  if all(isnan(fixed.beamAngle))
      sample_data.meta.beam_angle               =  20;  % http://www.hydro-international.com/files/productsurvey_v_pdfdocument_19.pdf
  else
      sample_data.meta.beam_angle               =  mode(fixed.beamAngle); % we set a static value for this variable to the most frequent value found
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
  iBadOriented = adcpOrientations ~= adcpOrientation; % we'll only keep velocity data collected when ADCP is oriented as expected
  vnrth(iBadOriented, :) = NaN;
  veast(iBadOriented, :) = NaN;
  wvel(iBadOriented, :) = NaN;
  evel(iBadOriented, :) = NaN;
  speed(iBadOriented, :) = NaN;
  direction(iBadOriented, :) = NaN;
  backscatter1(iBadOriented, :) = NaN;
  backscatter2(iBadOriented, :) = NaN;
  backscatter3(iBadOriented, :) = NaN;
  backscatter4(iBadOriented, :) = NaN;
  correlation1(iBadOriented, :) = NaN;
  correlation2(iBadOriented, :) = NaN;
  correlation3(iBadOriented, :) = NaN;
  correlation4(iBadOriented, :) = NaN;
  percentGood1(iBadOriented, :) = NaN;
  percentGood2(iBadOriented, :) = NaN;
  percentGood3(iBadOriented, :) = NaN;
  percentGood4(iBadOriented, :) = NaN;
  dims = {
      'TIME',                   time,    ['Time stamp corresponds to the start of the measurement which lasts ' num2str(sample_data.meta.instrument_average_interval) ' seconds.']; ...
      'HEIGHT_ABOVE_SENSOR',    height,   'Data has been vertically bin-mapped using tilt information so that the cells have consistant heights above sensor in time.'; ...
      'DIST_ALONG_BEAMS',       distance, 'Data is not vertically bin-mapped (no tilt correction applied). Cells are lying parallel to the beams, at heights above sensor that vary with tilt.'
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
  vars = {
      'TIMESERIES',         [],     1,              ''; ...
      'LATITUDE',           [],     NaN,            ''; ...
      'LONGITUDE',          [],     NaN,            ''; ...
      'NOMINAL_DEPTH',      [],     NaN,            ''; ...
      ['VCUR' magExt],      [1 2],  vnrth,          magBiasComment; ...
      ['UCUR' magExt],      [1 2],  veast,          magBiasComment; ...
      'WCUR',               [1 2],  wvel,           ''; ...
      'CSPD',               [1 2],  speed,          ''; ...
      ['CDIR' magExt],      [1 2],  direction,      magBiasComment; ...
      'ECUR',               [1 2],  evel,           ''; ...
      'ABSIC1',             [1 3],  backscatter1,   ''; ...
      'ABSIC2',             [1 3],  backscatter2,   ''; ...
      'ABSIC3',             [1 3],  backscatter3,   ''; ...
      'ABSIC4',             [1 3],  backscatter4,   ''; ...
      'CMAG1',              [1 3],  correlation1,   ''; ...
      'CMAG2',              [1 3],  correlation2,   ''; ...
      'CMAG3',              [1 3],  correlation3,   ''; ...
      'CMAG4',              [1 3],  correlation4,   ''; ...
      'PERG1',              [1 2],  percentGood1,   ''; ...
      'PERG2',              [1 2],  percentGood2,   ''; ...
      'PERG3',              [1 2],  percentGood3,   ''; ...
      'PERG4',              [1 2],  percentGood4,   ''; ...
      'TEMP',               1,      temperature,    ''; ...
      'PRES_REL',           1,      pressure,       ''; ...
      'PSAL',               1,      salinity,       ''; ...
      'PITCH',              1,      pitch,          ''; ...
      'ROLL',               1,      roll,           ''; ...
      ['HEADING' magExt],   1,      heading,        magBiasComment; ...
      'VOLT',               1,      voltage,        voltComment
      };
  
  clear vnrth veast wvel evel speed direction backscatter1 ...
      backscatter2 backscatter3 backscatter4 temperature pressure ...
      salinity correlation1 correlation2 correlation3 correlation4 ...
      percentGood1 percentGood2 percentGood3 percentGood4 pitch roll ...
      heading voltage;
  
  nVars = size(vars, 1);
  sample_data.variables = cell(nVars, 1);
  for i=1:nVars
      sample_data.variables{i}.name         = vars{i, 1};
      sample_data.variables{i}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(vars{i, 1}, 'type')));
      sample_data.variables{i}.dimensions   = vars{i, 2};
      sample_data.variables{i}.data         = sample_data.variables{i}.typeCastFunc(vars{i, 3});
      sample_data.variables{i}.comment      = vars{i, 4};
      
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
      
      if strcmpi(vars{i, 1}, 'PRES_REL')
          sample_data.variables{i}.applied_offset = sample_data.variables{i}.typeCastFunc(-gsw_P0/10^4); % (gsw_P0/10^4 = 10.1325 dbar)
      end
      
      if any(strcmpi(vars{i, 1}, {'VCUR', 'UCUR', 'CDIR', 'HEADING'}))
          sample_data.variables{i}.compass_correction_applied = magDec;
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
          'WSSH',           1,          waveData.param.Hs; ...   % Significant Wave Height Hs = 4 sqrt(M0)
          'WPPE',           1,          waveData.param.Tp; ...   % Peak Wave Period (seconds) - period associated with the largest peak in the power spectrum
          ['WPDI' magExt],  1,          waveData.param.Dp; ...   % Peak Wave Direction (degrees) - peak direction at the peak period
          'WWSH',           1,          waveData.param.Hs_W; ... % Significant Wave Height in the sea region of the power spectrum
          'WWPP',           1,          waveData.param.Tp_W; ... % Peak Sea Wave Period (seconds) - period associated with the largest peak in the sea region of the power spectrum
          ['WWPD' magExt],  1,          waveData.param.Dp_W; ... % Peak Sea Wave Direction (degrees) - peak sea direction at the peak period in the sea region
          'SWSH',           1,          waveData.param.Hs_S; ... % Significant Wave Height in the swell region of the power spectrum
          'SWPP',           1,          waveData.param.Tp_S; ... % Peak Swell Wave Period (seconds) - period associated with the largest peak in the swell region of the power spectrum
          ['SWPD' magExt],  1,          waveData.param.Dp_S; ... % Peak Swell Wave Direction (degrees) - peak swell direction at the peak period in the swell region
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
          ['VDIR' magExt],  1,          waveData.param.Dmn; ...   % Mean Peak Wave Direction
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