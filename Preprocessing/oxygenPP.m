function sample_data = oxygenPP( sample_data, qcLevel, auto )
%OXSOLPP Adds a oxygen solubility variable to the given data sets, if they
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
%  Input Parameters
%       TEMP, PSAL, PRES_REL (or PRES)
%       DOX
%       DOXS
%       DOX1
%       DOX2 (calculate DOX2, OXSOL only)
%
% Outputs:
%   sample_data - the same data sets, with oxygen (umol/kg) 
%                 oxygen satutation, oxygen solubility variables added.
% 
% Output Parameters
%       DOX2
%       DOXS
%       OXSOL
%
% Author:       Peter Jansen <peter.jansen@csiro.au>
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
  
  % Get the temperature
  tempIdx       = getVar(sam.variables, 'TEMP');
  if ~(tempIdx), continue; end % if there is no temperature, then don't do anythin  
  % get coorinates and dimensions from TEMP to use as output
  % coordinates/dimensions
  dimensions = sam.variables{tempIdx}.dimensions;
  if isfield(sam.variables{tempIdx}, 'coordinates')
      coordinates = sam.variables{tempIdx}.coordinates;
  else
      coordinates = '';
  end
  temp = sam.variables{tempIdx}.data;
  
  % indexs of other variables that might be needed
  psalIdx       = getVar(sam.variables, 'PSAL');
  presRelIdx    = getVar(sam.variables, 'PRES_REL');
  presIdx       = getVar(sam.variables, 'PRES');
  
  if (presRelIdx)
      pres = sam.variables{presRelIdx}.data;
  else
      % Should be pressure, convert from depth?
      pres = sam.instrument_nominal_depth*ones(size(temp));
  end
  
  % oxygen parameters that maybe in the dataset
  doxIdx        = getVar(sam.variables, 'DOX');
  dox1Idx       = getVar(sam.variables, 'DOX1');
  dox2Idx       = getVar(sam.variables, 'DOX2');
  doxsIdx       = getVar(sam.variables, 'DOXS');
  oxsolIdx      = getVar(sam.variables, 'OXSOL');
  
  % check is psal and some dox measurement present, if not skip
  if ~(psalIdx && (doxIdx || dox1Idx || dox2Idx || doxsIdx)), continue; end
  
%   % get a latitude for calculation of Salinity Absolute from TEOS-10
%   if isempty(sam.geospatial_lat_min)
%       disp(['Warning : no geospatial_lat_min, geospatial_long_min documented for oxygenPP to be applied on ' sam.toolbox_input_file]);
%       prompt = {'Latitude (South -ve)', 'Longitude (West -ve)'};
%       dlg_title = 'Location';
%       num_lines = 1;
%       defaultans = {'0' , '0'};
%       answer = inputdlg(prompt,dlg_title,num_lines,defaultans);
%       
%       % don't try to apply any correction if canceled by user
%       if isempty(answer), return; end
%       
%       sam.geospatial_lat_min = str2double(answer(2));
%       continue;
%   end
%   lat = sam.geospatial_lat_min;
%   long = sam.geospatial_long_min;
  
  psal = sam.variables{psalIdx}.data;
  
  ptmp = sw_ptmp(psal, temp , pres, 0);
  
  %SA = gsw_SA_from_SP(psal, pres, long, lat);
  %pt = gsw_pt_from_t(SA, temp, pres, 0);
  
  % calculate the density at 0 dbar
  dens = sw_dens0(psal, ptmp);

  % calculate oxygen solability
  if ~(oxsolIdx)
      oxsol = gsw_O2sol_SP_pt(psal, ptmp); % Should this be potential temperature?
      oxsolComment = 'oxsolPP.m: derived from PSAL, TEMP using Garcia and Gordon (1992, 1993)';
  else
      oxsol = sam.variables{oxsolIdx}.data;
  end
    
  if (doxIdx) && ~(dox2Idx)
    dox = sam.variables{doxIdx}.data;
    dox2 = dox * 44660 ./ dens;
    dox2Comment = 'oxsolPP.m: derived from dox2 = dox (ml/l) * 44660 / sw_dens0(PSAL,TEMP)';
  end
  if (dox1Idx) && ~(dox2Idx)
    dox1 = sam.variables{dox1Idx}.data;
    dox2 = dox1 ./ dens;
    dox2Comment = 'oxsolPP.m: derived from dox2 = dox (umol/l) / sw_dens0(PSAL,TEMP)';
  end
  if (doxsIdx) && ~(dox2Idx)
    doxs = sam.variables{doxsIdx}.data;
    dox2 = doxs .* oxsol;
    dox2Comment = 'oxsolPP.m: derived from doxs * oxsol(PSAL, TEMP)';
  end
  
  if ~(dox2Idx)
      sam.variables{end+1}.dimensions = dimensions;
      sam.variables{end}.name         = 'DOX2';
      sam.variables{end}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sam.variables{end}.name, 'type')));
      sam.variables{end}.coordinates  = coordinates;
  
      sam.variables{end}.data = sam.variables{end}.typeCastFunc(dox2);
      sam.variables{end}.comment       = dox2Comment;
  else
      dox2 = sam.variables{dox2Idx}.data;
  end
      
  if (~doxsIdx)   
      doxs = dox2 ./ oxsol;
      
      sam.variables{end+1}.dimensions = dimensions;
      sam.variables{end}.name         = 'DOXS';
      sam.variables{end}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sam.variables{end}.name, 'type')));
      sam.variables{end}.coordinates  = coordinates;
  
      sam.variables{end}.data = sam.variables{end}.typeCastFunc(doxs);
      sam.variables{end}.comment       = dox2Comment;
  end
  if (~oxsolIdx)   
      sam.variables{end+1}.dimensions = dimensions;
      sam.variables{end}.name         = 'OXSOL';
      sam.variables{end}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sam.variables{end}.name, 'type')));
      sam.variables{end}.coordinates  = coordinates;
  
      sam.variables{end}.data = sam.variables{end}.typeCastFunc(oxsol);
      sam.variables{end}.comment       = oxsolComment;
  end

  history = sam.history;
  if isempty(history)
      sam.history = sprintf('%s - %s', datestr(now_utc, readProperty('exportNetCDF.dateFormat')), oxsolComment);
  else
      sam.history = sprintf('%s\n%s - %s', history, datestr(now_utc, readProperty('exportNetCDF.dateFormat')), oxsolComment);
  end
  
  sample_data{k} = sam;
end

% FROM WQM
%     % some fields are not in IMOS uom - scale them so that they are
%     switch upper(fields{k})
%         
%         % WQM provides conductivity S/m; exactly like we want it to be!
%         
%         % WQM can provide Dissolved Oxygen in mmol/m3,
%         % hopefully 1 mmol/m3 = 1 umol/l
%         % exactly like we want it to be!
%         case upper('DO(mmol/m^3)') % DOX1_1
%             comment = 'Originally expressed in mmol/m3, 1l = 0.001m3 was assumed.';
%             isUmolPerL = true;
%             
%         % convert dissolved oxygen in ml/l to umol/l
%         case upper('DO(ml/l)') % DOX1_2
%             comment = 'Originally expressed in ml/l, 1ml/l = 44.660umol/l was assumed.';
%             isUmolPerL = true;
%             
%             % ml/l -> umol/l
%             %
%             % Conversion factors from Saunders (1986) :
%             % https://darchive.mblwhoilibrary.org/bitstream/handle/1912/68/WHOI-89-23.pdf?sequence=3
%             % 1ml/l = 43.57 umol/kg (with dens = 1.025 kg/l)
%             % 1ml/l = 44.660 umol/l
%             
%             data = data .* 44.660;
%             
%         % convert dissolved oxygen in mg/L to umol/l.
%         case upper('DO(mg/l)') % DOX1_3
%             data = data * 44.660/1.429; % O2 density = 1.429 kg/m3
%             comment = 'Originally expressed in mg/l, O2 density = 1.429kg/m3 and 1ml/l = 44.660umol/l were assumed.';
%             isUmolPerL = true;
%             
%         % WQM provides chlorophyll in ug/L; we need it in mg/m^3, 
%         % hopefully it is equivalent.
%     end
% 
