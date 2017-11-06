function sample_data = salinityPP( sample_data, qcLevel, auto )
%SALINITYPP Adds a salinity variable to the given data sets, if they
% contain conductivity, temperature pressure and depth variables or nominal depth
% information. 
%
% This function uses the Gibbs-SeaWater toolbox (TEOS-10) to derive salinity
% data from conductivity, temperature and pressure. It adds the salinity 
% data as a new variable in the data sets. Data sets which do not contain 
% conductivity, temperature pressure and depth variables or nominal depth 
% information are left unmodified.
%
% Inputs:
%   sample_data - cell array of data sets, ideally with conductivity, 
%                 temperature and pressure variables.
%   qcLevel     - string, 'raw' or 'qc'. Some pp not applied when 'raw'.
%   auto        - logical, run pre-processing in batch mode.
%
% Outputs:
%   sample_data - the same data sets, with salinity variables added.
%
% Author:       Paul McCarthy <paul.mccarthy@csiro.au>
% Contributor:  Guillaume Galibert <guillaume.galibert@utas.edu.au>
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

for k = 1:length(sample_data)
  
  sam = sample_data{k};
  
  % data set already contains salinity
  if getVar(sam.variables, 'PSAL'), continue; end
  
  cndcIdx       = getVar(sam.variables, 'CNDC');
  tempIdx       = getVar(sam.variables, 'TEMP');
  
  [presRel, zName, zComment] = getPresRelForGSW(sam);
  
  % cndc, temp, and pres/pres_rel or depth/nominal depth not present in data set
  if ~(cndcIdx && tempIdx && ~isempty(zName)), continue; end
  
  cndc = sam.variables{cndcIdx}.data;
  temp = sam.variables{tempIdx}.data;
  
  % calculate C(S,T,P)/C(35,15,0) ratio
  % conductivity is in S/m and gsw_C3515 in mS/cm
  R = 10*cndc ./ gsw_C3515;
  
  % calculate salinity
  psal = gsw_SP_from_R(R, temp, presRel);
  
  dimensions = sam.variables{tempIdx}.dimensions;
  salinityComment = ['salinityPP.m: derived from CNDC, TEMP and ' zName ' ' zComment ' using the Gibbs-SeaWater toolbox (TEOS-10) v3.06'];
  
  if isfield(sam.variables{tempIdx}, 'coordinates')
      coordinates = sam.variables{tempIdx}.coordinates;
  else
      coordinates = '';
  end
    
  % add salinity data as new variable in data set
  sample_data{k} = addVar(...
    sam, ...
    'PSAL', ...
    psal, ...
    dimensions, ...
    salinityComment, ...
    coordinates);

    history = sample_data{k}.history;
    if isempty(history)
        sample_data{k}.history = sprintf('%s - %s', datestr(now_utc, readProperty('exportNetCDF.dateFormat')), salinityComment);
    else
        sample_data{k}.history = sprintf('%s\n%s - %s', history, datestr(now_utc, readProperty('exportNetCDF.dateFormat')), salinityComment);
    end
end
