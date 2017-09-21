function sample_data = aquatrackaPP( sample_data, qcLevel, auto )
%AQUATRACKAPP transforms an Aquatracka analog output into engineering units.
%
% This function uses the following formula PARAM =
% scale_factor*10^(PARAM_analog) + offset . scale_factor and offset are
% taken from calibration sheets.
%
% Inputs:
%   sample_data - cell array of data sets, ideally with conductivity, 
%                 temperature and pressure variables.
%   qcLevel     - string, 'raw' or 'qc'. Some pp not applied when 'raw'.
%   auto        - logical, run pre-processing in batch mode.
%
% Outputs:
%   sample_data - the same data sets, with variables in engineering units added.
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

% auto logical in input to enable running under batch processing
if nargin<3, auto=false; end

analogAquatracka = {'CHL', 'FTU', 'PAH', 'CDOM'};
imosAquatracka = {'CHLF', 'TURBF', 'CHR', 'CHC'};
commentsAquatracka = {['Artificial chlorophyll data '...
          'computed from bio-optical sensor raw counts measurements using factory calibration coefficient. The '...
          'fluorometre is equipped with a 430nm peak wavelength LED to irradiate and a '...
          'photodetector paired with an optical filter which measures everything '...
          'that fluoresces in the region of 685nm. '...
          'Originally expressed in ug/l, 1l = 0.001m3 was assumed.'], ...
          ['Turbidity data in FTU '...
          'computed from bio-optical sensor raw counts measurements using factory calibration coefficient. The '...
          'fluorometre is used as a nephelometre equipped with a 440nm peak wavelength LED to irradiate. '], ...
          '', ...
          ''};
nAquatracka = length(analogAquatracka);

voltLabel   = cell(1, nAquatracka);
scaleFactor = NaN(1, nAquatracka);
offset      = NaN(1, nAquatracka);

ParamFile = ['Preprocessing' filesep 'aquatrackaPP.txt'];
for i=1:nAquatracka
    voltLabel{i}    = readProperty(['volt' analogAquatracka{i}], ParamFile);
    scaleFactor(i)  = str2double(readProperty(['scaleFactor' analogAquatracka{i}], ParamFile));
    offset(i)       = str2double(readProperty(['offset' analogAquatracka{i}], ParamFile));
end

for k = 1:length(sample_data)
  for i=1:nAquatracka
      sam = sample_data{k};
      
      voltIdx     = getVar(sam.variables, ['volt_' voltLabel{i}]);
      
      % analog aquatracka output not present in data set
      if ~voltIdx, continue; end
      
      volt = sam.variables{voltIdx}.data;
      
      % Aquatracka formulae
      data = scaleFactor(i)*10.^(volt) + offset(i);
      
      dimensions = sam.variables{voltIdx}.dimensions;
      
      if isfield(sam.variables{voltIdx}, 'coordinates')
          coordinates = sam.variables{voltIdx}.coordinates;
      else
          coordinates = '';
      end
      
      % add data as new variable in data set
      sample_data{k} = addVar(...
          sam, ...
          imosAquatracka{i}, ...
          data, ...
          dimensions, ...
          commentsAquatracka{i}, ...
          coordinates);
      
      history = sample_data{k}.history;
      if isempty(history)
          sample_data{k}.history = sprintf('%s - %s', datestr(now_utc, readProperty('exportNetCDF.dateFormat')), commentsAquatracka{i});
      else
          sample_data{k}.history = sprintf('%s\n%s - %s', history, datestr(now_utc, readProperty('exportNetCDF.dateFormat')), commentsAquatracka{i});
      end
      
  end
end
