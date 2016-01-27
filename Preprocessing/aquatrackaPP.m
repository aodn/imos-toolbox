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
% Copyright (c) 2009, eMarine Information Infrastructure (eMII) and Integrated 
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
