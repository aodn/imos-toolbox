function sample_data = velocityMagDirPP( sample_data, qcLevel, auto )
%VELOCITYMAGDIRPP Adds CSPD and CDIR variables to the given data sets, if they
% contain UCUR and VCUR variables.
%
% This function uses trigonometry functions to derive the sea water
% velocity direction and speed data from the meridional and zonal sea water
% velocity speed. It adds the sea water velocity magnitude and direction data 
% as new variables in the data sets. Data sets which do not contain 
% UCUR and VCUR variables or which already contain CSPD and CDIR are left unmodified.
%
% Inputs:
%   sample_data - cell array of data sets, ideally with UCUR and VCUR.
%   qcLevel     - string, 'raw' or 'qc'. Some pp not applied when 'raw'.
%   auto        - logical, run pre-processing in batch mode.
%
% Outputs:
%   sample_data - the same data sets, with CSPD and CDIR variables added.
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

for k = 1:length(sample_data)
  
  sam = sample_data{k};
  
  % data set already contains CSPD or CDIR
  if getVar(sam.variables, 'CSPD') || getVar(sam.variables, 'CDIR'), continue; end
  
  ucurIdx = getVar(sam.variables, 'UCUR');
  vcurIdx = getVar(sam.variables, 'VCUR');
  
  % UCUR or VCUR not present in data set
  if ~(ucurIdx && vcurIdx), continue; end
  
  ucur = sam.variables{ucurIdx}.data;
  vcur = sam.variables{vcurIdx}.data;
  
  % calculate magnitude
  cspd = sqrt(ucur.^2 + vcur.^2);
  
  % calculate direction
  cdir = atan2(vcur, ucur) * 180/pi; % atan2 goes positive anti-clockwise with 0 on the right side
  cdir = -cdir + 90; % we want to go positive clockwise with 0 on the top side
  cdir = cdir + 360*(cdir < 0); % we shift +360 for whatever is left negative
  
  dimensions = sam.variables{ucurIdx}.dimensions;
  comment = 'velocityMagDirPP.m: CSPD and CDIR were derived from UCUR and VCUR.';
  
  if isfield(sam.variables{ucurIdx}, 'coordinates')
      coordinates = sam.variables{ucurIdx}.coordinates;
  else
      coordinates = '';
  end
    
  % add CSPD and CDIR data as new variable in data set
  sample_data{k} = addVar(...
    sample_data{k}, ...
    'CSPD', ...
    cspd, ...
    dimensions, ...
    comment, ...
    coordinates);

  sample_data{k} = addVar(...
    sample_data{k}, ...
    'CDIR', ...
    cdir, ...
    dimensions, ...
    comment, ...
    coordinates);

    history = sample_data{k}.history;
    if isempty(history)
        sample_data{k}.history = sprintf('%s - %s', datestr(now_utc, readProperty('exportNetCDF.dateFormat')), comment);
    else
        sample_data{k}.history = sprintf('%s\n%s - %s', history, datestr(now_utc, readProperty('exportNetCDF.dateFormat')), comment);
    end
end
