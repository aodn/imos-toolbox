function [ geomagDeclin, geomagLat, geomagLon, geomagDepth, geomagDate, model] = geomag70( lat, lon, height_above_sea_level, date )

% GEOMAG Calculate geomagnetic field values from a spherical harmonic model.
%
%  **[D,I,H,F] = GEOMAG(LAT,LON,DATE) returns the geomagnetic declination D,
%  **inclination I, horizontal intensity H, and total intensity F as a
%  **function of Julian day JD, latitude LAT, and longitude LON.

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

  if ~(length(lat)==length(lon) && ...
      length(lat)==length(height_above_sea_level) && ...
      length(lat)==length(date)), ...
        error('dimension miss match, lat %d lon %d h %d date %d', length(lat), length(lat), length(height_above_sea_level), length(date)); 
  end
  
  switch computer
      case 'GLNXA64'
          computerDir = 'linux';
          geomagExe = 'geomag70';
          stdOutRedirection = '>/dev/null'; % we don't want standard output to be output in console (useless)
          endOfLine = '\n';
          maxPathLength = 1024;
          
      case {'PCWIN', 'PCWIN64'}
          computerDir = 'windows';
          geomagExe = 'geomag70.exe';
          stdOutRedirection = '>NUL';
          endOfLine = '\r\n';
          maxPathLength = 259;

      case {'MACI64'}
          computerDir = 'macosx';
          geomagExe = 'geomag70';
          stdOutRedirection = '>/dev/null';
          endOfLine = '\n';
          maxPathLength = 1024;
          
      otherwise
          return;
  end
  
  path = '';
  if ~isdeployed, [path, ~, ~] = fileparts(which('imosToolbox.m')); end
  if isempty(path), path = pwd; end
  
  % read in model parameter
  propFile = fullfile('Geomag', 'geomag70.txt');
  model    = readProperty('model', propFile);
  
  geomagPath        = fullfile(path, 'Geomag');
  geomagExeFull     = fullfile(geomagPath, computerDir, geomagExe);
  geomagModelFile   = fullfile(geomagPath, computerDir, [model '.COF']);
  geomagInputFile   = fullfile(geomagPath, 'sample_coords.txt');
  geomagOutputFile  = fullfile(geomagPath, ['sample_out_' model '.txt']);
  
  % geomag is limited to OS path length
  if length(geomagOutputFile) > maxPathLength
      error(['geomag70.m : Change your toolbox location so that ' geomagOutputFile ' is shorter than ' num2str(maxPathLength) ' characters long (Geomag limitation).']);
  end

  % we create the geomag input file for the input data
  geomagFormat = '%s D M%f %f %f\n';
  inputId = fopen(geomagInputFile, 'w');
  for i=1:length(lat)
      fprintf(inputId, geomagFormat, datestr(date(i), 'yyyy,mm,dd'), height_above_sea_level(i),  lat(i), lon(i));
  end
  fclose(inputId);
    
  % we run the geomag program and read its output
  geomagCmd = sprintf('"%s" "%s" f "%s" "%s" %s', geomagExeFull, geomagModelFile, geomagInputFile, geomagOutputFile, stdOutRedirection);
  system(geomagCmd);
  
  geomagFormat = '%s D M%f %f %f %fd %fm %*s %*s %*f %*f %*f %*f %*f %*f %*f %*f %*f %*f %*f %*f';
  outputId = fopen(geomagOutputFile, 'rt');
  geomagOutputData = textscan(outputId, geomagFormat, ...
      'HeaderLines',            1, ...
      'Delimiter',              ' ', ...
      'MultipleDelimsAsOne',    true, ...
      'EndOfLine',              endOfLine);
  fclose(outputId);
  
  geomagDate    = datenum(geomagOutputData{1}, 'yyyy,mm,dd');
  geomagDepth   = -geomagOutputData{2};
  geomagLat     = geomagOutputData{3};
  geomagLon     = geomagOutputData{4};
  signDeclin    = sign(geomagOutputData{5});
  if signDeclin >= 0, signDeclin = 1; end
  geomagDeclin  = geomagOutputData{5} + signDeclin.*geomagOutputData{6}/60;
  
  %for i=1:length(geomagDeclin)
  %  fprintf('lat = %f, lon = %f, date = %s, dec = %f\n', geomagLat(i), geomagLon(i), geomagDate{i}, geomagDeclin(i));
  %end
  
end

