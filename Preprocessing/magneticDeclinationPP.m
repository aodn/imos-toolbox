function sample_data = magneticDeclinationPP( sample_data, qcLevel, auto )
%MAGNETICDECLINATIONPP computes and applies the relevant magnetic 
% declination correction to the datasets.
%
% Makes use of the NOAA Geomag software to compute the magnetic declination
% at a specific location and time (centre of data time coverage) and then
% applies the relevant correction to any *_MAG IMOS code parameter which are
% then renamed without '_MAG'.
%
% Inputs:
%   sample_data - cell array of structs, the data sets for which a magnetic
%                 measurement (ex. magnetic compass) dependent data (ex.
%                 ADCP current direction) should be modified.
%   qcLevel     - string, 'raw' or 'qc'. Some pp not applied when 'raw'.
%   auto        - logical, check if pre-processing in batch mode.
%
% Outputs:
%   sample_data - same as input, with data parameters referring to true 
%                 North instead of magnetic North.
%
% Author:       Guillaume Galibert <guillaume.galibert@utas.edu.au>
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
  narginchk(2, 3);

  if ~iscell(sample_data), error('sample_data must be a cell array'); end
  if isempty(sample_data), return;                                    end
  
  % no modification of data is performed on the raw FV00 dataset except
  % local time to UTC conversion
  if strcmpi(qcLevel, 'raw'), return; end
   
  % magnetic measurement dependent IMOS parameters
  magParam = {'CDIR_MAG', 'HEADING_MAG', 'SSDS_MAG', 'SSWD_MAG', ...
      'SSWV_MAG', 'WPDI_MAG', 'WWPD_MAG', 'SWPD_MAG', ...
      'UCUR_MAG', 'VCUR_MAG', 'VDIR_MAG', ...
      'CDIR', 'HEADING', 'SSDS', 'SSWD', ...
      'SSWV', 'WPDI', 'WWPD', 'SWPD', ...
      'UCUR', 'VCUR', 'VDIR'};
  
  nDataSet = length(sample_data);
  iMagDataSet = [];
  isMagDecToBeComputed = false;
  lat = [];
  lon = [];
  h = [];
  d = [];
  for i = 1:nDataSet
    nVar = length(sample_data{i}.variables);
    for j = 1:nVar
        % needs correction from magnetic declination
        if any(strcmpi(sample_data{i}.variables{j}.name, magParam))
            if ~any(iMagDataSet == i)
                iMagDataSet = [iMagDataSet i];
            end
        end
    end
    
    if any(iMagDataSet == i)
        if isempty(sample_data{i}.instrument_nominal_depth) || ...
                isempty(sample_data{i}.geospatial_lat_min) || ...
                isempty(sample_data{i}.geospatial_lon_min)
            disp(['Warning : no instrument_nominal_depth/geospatial_lat_min/geospatial_lon_min documented for magneticDeclinationPP to be applied on ' sample_data{i}.toolbox_input_file]);
            prompt = {'Depth:', 'Latitude (South -ve)', 'Longitude (West -ve)'};
            dlg_title = 'Coords';
            num_lines = 1;
            defaultans = {'0','0', '0'};
            answer = inputdlg(prompt,dlg_title,num_lines,defaultans);
            
            % don't try to apply any correction if canceled by user
            if isempty(answer), return; end
            
            sample_data{i}.instrument_nominal_depth = str2double(answer(1));
            sample_data{i}.geospatial_lat_min = str2double(answer(2));
            sample_data{i}.geospatial_lon_min = str2double(answer(3));
            continue;
        end
        % geomag only support computation for height above sea level
        % ranging [-1000;600000]
        height_above_sea_level = -sample_data{i}.instrument_nominal_depth;
        if height_above_sea_level < -1000; height_above_sea_level = -1000; end
                
        geomagDate = sample_data{i}.time_coverage_start + ...
            (sample_data{i}.time_coverage_end - sample_data{i}.time_coverage_start)/2;
        
        lat(end+1) = sample_data{i}.geospatial_lat_min;
        lon(end+1) = sample_data{i}.geospatial_lon_min;
        h(end+1) = height_above_sea_level;
        d(end+1) = geomagDate;
        
        isMagDecToBeComputed = true;
    end
  end
  
  if isMagDecToBeComputed
      
      [ geomagDeclin, geomagLat, geomagLon, geomagDepth, geomagDate, model] = geomag70(lat, lon, h, d);
            
      nMagDataSet = length(iMagDataSet);
      for i = 1:nMagDataSet
          isMagDecApplied = false;
          magneticDeclinationComment = ['magneticDeclinationPP: data initially referring to magnetic North has ' ...
              'been modified so that it now refers to true North, applying a computed magnetic ' ...
              'declination of ' num2str(geomagDeclin(i)) 'degrees. NOAA''s Geomag v7.0 software + ' model ' ' ...
              'model have been used to compute this value at a latitude=' num2str(geomagLat(i)) 'degrees ' ...
              'North, longitude=' num2str(geomagLon(i)) 'degrees East, depth=' num2str(geomagDepth(i)) 'm ' ...
              '(instrument nominal depth) and date=' datestr(geomagDate(i), 'yyyy/mm/dd') ...
              ' (date in the middle of time_coverage_start and time_coverage_end).'];
          
          % we look for magnetic measurement dependent IMOS parameters
          iVcur_mag = getVar(sample_data{iMagDataSet(i)}.variables, 'VCUR_MAG');
          if iVcur_mag ~= 0, vcur_mag = sample_data{iMagDataSet(i)}.variables{iVcur_mag}.data; end
          
          iUcur_mag = getVar(sample_data{iMagDataSet(i)}.variables, 'UCUR_MAG');
          if iVcur_mag ~= 0, ucur_mag = sample_data{iMagDataSet(i)}.variables{iUcur_mag}.data; end
                      
          nVar = length(sample_data{iMagDataSet(i)}.variables);
          for j = 1:nVar
              switch sample_data{iMagDataSet(i)}.variables{j}.name
                  case {'CDIR_MAG', 'HEADING_MAG', 'VDIR_MAG', 'SSDS_MAG', ...
                          'SSWD_MAG', 'WPDI_MAG', 'WWPD_MAG', 'SWPD_MAG'} % PARAM_MAG (Degrees clockwise from magnetic North)
                     
                      % current parameter gives a direction from magnetic
                      % North so just need to add the magnetic declination
                      % to get a direction from true North
                      data_mag = sample_data{iMagDataSet(i)}.variables{j}.data;
                      data = data_mag + geomagDeclin(i);
                      
                      % we make sure values fall within [0; 360[
                      data = make0To360(data);
                      
                  case 'VCUR_MAG' % northward_sea_water_velocity (m s-1) referenced to magnetic north
                      data = vcur_mag*cos(geomagDeclin(i) * pi/180) - ucur_mag*sin(geomagDeclin(i) * pi/180);
                      
                  case 'UCUR_MAG' % eastward_sea_water_velocity (m s-1) referenced to magnetic north
                      data = vcur_mag*sin(geomagDeclin(i) * pi/180) + ucur_mag*cos(geomagDeclin(i) * pi/180);
                      
                  case 'SSWV_MAG' % sea_surface_wave_directional_variance_spectral_density (m2 s deg-1) referenced to magnetic north
                      % data stays "the same" but we modify the dimension
                      % from DIR_MAG to DIR
                      iDim = sample_data{iMagDataSet(i)}.variables{j}.dimensions(end);
                      dataDir_mag = sample_data{iMagDataSet(i)}.dimensions{iDim}.data;
                      dataDir = dataDir_mag + geomagDeclin(i);
                      
                      % we make sure values fall within [0; 360[
                      dataDir = make0To360(dataDir);
                      
                      % we sort the dimension dataDir so that it is monotonic
                      [dataDir, iSortDirMag] = sort(dataDir);
                      
                      % we need to re-arrange the data matrix according to the new DIR
                      % dimension order
                      data = sample_data{iMagDataSet(i)}.variables{j}.data(:,:,iSortDirMag);
                      
                      % we modify the DIR values
                      sample_data{iMagDataSet(i)}.dimensions{iDim}.name = ...
                          sample_data{iMagDataSet(i)}.dimensions{iDim}.name(1:end-4);
                      sample_data{iMagDataSet(i)}.dimensions{iDim}.standard_name = '';
                      sample_data{iMagDataSet(i)}.dimensions{iDim}.long_name = '';
                      sample_data{iMagDataSet(i)}.dimensions{iDim}.units = '';
                      sample_data{iMagDataSet(i)}.dimensions{iDim}.data = dataDir;
                      sample_data{iMagDataSet(i)}.dimensions{iDim}.magnetic_declination = geomagDeclin(i);
                      sample_data{iMagDataSet(i)}.dimensions{iDim}.compass_correction_applied = geomagDeclin(i);
                      sample_data{iMagDataSet(i)}.dimensions{iDim}.comment = magneticDeclinationComment;
                      
                      comment = sample_data{iMagDataSet(i)}.dimensions{iDim}.comment;
                      if isempty(comment)
                          sample_data{iMagDataSet(i)}.dimensions{iDim}.comment = magneticDeclinationComment;
                      else
                          sample_data{iMagDataSet(i)}.dimensions{iDim}.comment = [comment ' ' magneticDeclinationComment];
                      end
              
                  case {'CDIR', 'HEADING', 'VDIR', 'SSDS', 'SSWD', 'WPDI', ...
                          'WWPD', 'SWPD', 'VCUR', 'UCUR'}
                      % we add a variable attribute for theoretical
                      % magnetic declination but don't do any modification
                      % to the data
                      sample_data{iMagDataSet(i)}.variables{j}.magnetic_declination = geomagDeclin(i);
                      continue;
                      
                  case 'SSWV'
                      % we add a variable attribute for theoretical
                      % magnetic declination but don't do any modification
                      % to the data and dimension
                      sample_data{iMagDataSet(i)}.variables{j}.magnetic_declination = geomagDeclin(i);
                      iDim = sample_data{iMagDataSet(i)}.variables{j}.dimensions(end);
                      sample_data{iMagDataSet(i)}.dimensions{iDim}.magnetic_declination = geomagDeclin(i);
                      continue;
                      
                  otherwise
                      % we don't do any modification
                      continue;
              end
              
              % we apply the modifications to the data and metadata
              paramName = sample_data{iMagDataSet(i)}.variables{j}.name(1:end-4);
              sample_data{iMagDataSet(i)}.variables{j}.name = paramName;
              sample_data{iMagDataSet(i)}.variables{j}.standard_name = '';
              sample_data{iMagDataSet(i)}.variables{j}.long_name = '';
              sample_data{iMagDataSet(i)}.variables{j}.units = '';
              sample_data{iMagDataSet(i)}.variables{j}.data = data;
              sample_data{iMagDataSet(i)}.variables{j}.magnetic_declination = geomagDeclin(i);
              sample_data{iMagDataSet(i)}.variables{j}.compass_correction_applied = geomagDeclin(i);
              
              comment = sample_data{iMagDataSet(i)}.variables{j}.comment;
              if isempty(comment)
                  sample_data{iMagDataSet(i)}.variables{j}.comment = magneticDeclinationComment;
              else
                  sample_data{iMagDataSet(i)}.variables{j}.comment = [comment ' ' magneticDeclinationComment];
              end
              
              sample_data{iMagDataSet(i)} = makeNetCDFCompliant(sample_data{iMagDataSet(i)});
              
              isMagDecApplied = true;
          end
          
          if isMagDecApplied
              history = sample_data{iMagDataSet(i)}.history;
              if isempty(history)
                  sample_data{iMagDataSet(i)}.history = sprintf('%s - %s', datestr(now_utc, readProperty('exportNetCDF.dateFormat')), magneticDeclinationComment);
              else
                  sample_data{iMagDataSet(i)}.history = sprintf('%s\n%s - %s', history, datestr(now_utc, readProperty('exportNetCDF.dateFormat')), magneticDeclinationComment);
              end
          end
      end
  end
  
end

function angle = make0To360(angle)
    iLower = angle < 0;
    angle(iLower) = 360 + angle(iLower);
    
    iHigher = angle >= 360;
    angle(iHigher) = angle(iHigher) - 360;
end