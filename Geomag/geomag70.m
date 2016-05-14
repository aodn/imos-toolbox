function [ geomagDeclin, geomagLat, geomagLon, geomagDepth, geomagDate, model] = geomag70( lat, lon, height_above_sea_level, date )

% GEOMAG Calculate geomagnetic field values from a spherical harmonic model.
%
%  **[D,I,H,F] = GEOMAG(LAT,LON,DATE) returns the geomagnetic declination D,
%  **inclination I, horizontal intensity H, and total intensity F as a
%  **function of Julian day JD, latitude LAT, and longitude LON.

% Copyright (c) 2015, eMarine Information Infrastructure (eMII) and Integrated 
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
%     * Neither the name of the eMII/IMOS nor the names of its contributors 
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
  geomagCmd = sprintf('%s %s f %s %s %s', geomagExeFull, geomagModelFile, geomagInputFile, geomagOutputFile, stdOutRedirection);
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

