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

% From : http://doi.org/10.13155/39795
%
% The unit of DOXY is umol/kg in Argo data and the oxygen measurements are sent from Argo floats in 
% another unit such as umol/L for the Optode and ml/L for the SBE-IDO. Thus the unit conversion is carried out by DACs as follows:
%   O2 [umol/L] = 44.6596 . O2 [ml/L]
%   O2 [umol/kg] = O2 [umol/L] / pdens
% Here, pdens is the potential density of water [kg/L] at zero pressure and at the potential temperature 
% (e.g., 1.0269 kg/L; e.g., UNESCO, 1983). The value of 44.6596 is derived from the molar volume of the oxygen gas, 22.3916 L/mole, 
% at standard temperature and pressure (0 C, 1 atmosphere; e.g., Garcia and Gordon, 1992). 
% This unit conversion follows the "Recommendations on the conversion between oxygen quantities for Bio-Argo floats and other autonomous sensor platforms" 
% by SCOR Working Group 142 on "Quality Control Procedures for Oxygen and Other Biogeochemical Sensors on Floats and Gliders" [RD13] . 
% The unit conversion should always be done with the best available temperature, i.e., TEMP of the CTD unit.

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
  
  [presRel, presName] = presRelFromSampleData(sam);

	% from imosParameters.txt
	% DOX,                 0, volume_concentration_of_dissolved_molecular_oxygen_in_sea_water,                          ml l-1,        ,              ,                                  O, 999999.0, 0.0,      200.0,    float
	% DOX1,                1, mole_concentration_of_dissolved_molecular_oxygen_in_sea_water,                            umol l-1,      ,              ,                                  O, 999999.0, 0.0,      1000.0, float
	% DOX2,                1, moles_of_oxygen_per_unit_mass_in_sea_water,                                               umol kg-1,     ,              ,                                  O, 999999.0, 0.0,      1000.0, float
	% DOXS,                1, fractional_saturation_of_oxygen_in_sea_water,                                             percent,       ,              ,                                  O, 999999.0, ,         ,         float
	% DOXY,                1, mass_concentration_of_oxygen_in_sea_water,                                                kg m-3,        ,              ,                                  O, 999999.0, 0.0,      29.0,     float
	% DOXY_TEMP,           1, temperature_of_sensor_for_oxygen_in_sea_water,                                            degrees_Celsius,,             ,                                  T, 999999.0, 0.0,      50.0,     float
	% OXSOL,               0, oxygen_solubility,                                                                        umol kg-1,     ,              ,                                  O, 999999.0, 0.0,      1000.0, float

  % oxygen parameters that maybe in the dataset
  doxIdx        = getVar(sam.variables, 'DOX');
  dox1Idx       = getVar(sam.variables, 'DOX1');
  dox2Idx       = getVar(sam.variables, 'DOX2');
  doxsIdx       = getVar(sam.variables, 'DOXS');
  doxyIdx       = getVar(sam.variables, 'DOXY');
  oxsolIdx      = getVar(sam.variables, 'OXSOL');
  
  % check is psal and some dox measurement present, if not skip
  if ~(psalIdx && (doxIdx || dox1Idx || dox2Idx || doxsIdx)), continue; end
    
  psal = sam.variables{psalIdx}.data;
  
  ptmp = sw_ptmp(psal, temp , presRel, 0);
  
  % calculate the density at 0 dbar
  dens = sw_dens0(psal, ptmp);

  % calculate oxygen solability
  if ~(oxsolIdx)
      oxsol = gsw_O2sol_SP_pt(psal, ptmp); % sea bird calculates this using psal, temp, not potential temperature
      oxsolComment = 'oxsolPP.m: derived from PSAL, TEMP using Garcia and Gordon (1992, 1993), calculated using teos-10 function gsw_O2sol_SP_pt(SP,pt)';
  else
      oxsol = sam.variables{oxsolIdx}.data;
  end

  % derive DOX2 from DOX1, DOX, DOXY, or DOXS in that preference order DOX1 first preference, so is calculated last
  if (doxsIdx) && ~(dox2Idx)
    doxs = sam.variables{doxsIdx}.data;
    dox2 = doxs .* oxsol;
    dox2Comment = 'oxsolPP.m: derived using dox2 = doxs * oxsol(PSAL, TEMP)';
  end
  if (doxyIdx) && ~(dox2Idx) && ~(dox1Idx)
    doxy = sam.variables{doxyIdx}.data;
    dox1 = doxy * 31.9988 ;
    dox2Comment = 'oxsolPP.m: derived using dox2 = doxy (kg/m^3) * 31.9988 / sw_dens0(PSAL, PTEMP)';
    dox2 = dox1 ./ dens;
  end
  if (dox1Idx) && ~(dox2Idx)
    dox1 = sam.variables{dox1Idx}.data;
    dox2 = dox1 ./ (dens/1000);
    dox2Comment = 'oxsolPP.m: derived using dox2 = dox (umol/l) / sw_dens0(PSAL, PTEMP)';
  end
  if (doxIdx) && ~(dox2Idx)
    dox = sam.variables{doxIdx}.data;
    dox2 = dox * 44659.6 ./ dens;
    dox2Comment = 'oxsolPP.m: derived using dox2 = dox (ml/l) * 44659.6 / sw_dens0(PSAL, PTEMP)';
  end
  
  if ~(dox2Idx)
      sam.variables{end+1}.dimensions = dimensions;
      sam.variables{end}.name         = 'DOX2';
      sam.variables{end}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sam.variables{end}.name, 'type')));
      sam.variables{end}.coordinates  = coordinates;
  
      sam.variables{end}.data                   = sam.variables{end}.typeCastFunc(dox2);
      sam.variables{end}.comment                = dox2Comment;
      sam.variables{end}.conversion_reference   = 'http://doi.org/10.13155/39795';
      sam.variables{end}.comment_pressure       = ['oxygenPP.m: pressure from ' presName];

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
      sam.variables{end}.comment       = 'oxsolPP.m: derived using doxs = dox2 / oxsol';
  end
  if (~oxsolIdx)   
      sam.variables{end+1}.dimensions = dimensions;
      sam.variables{end}.name         = 'OXSOL';
      sam.variables{end}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sam.variables{end}.name, 'type')));
      sam.variables{end}.coordinates  = coordinates;
  
      sam.variables{end}.data = sam.variables{end}.typeCastFunc(oxsol);
      sam.variables{end}.comment       = oxsolComment;
  end

  history = [];
  if (isfield(sam, 'history'))
    history = sam.history;
  end
  if isempty(history)
      sam.history = sprintf('%s - %s', datestr(now_utc, readProperty('exportNetCDF.dateFormat')), dox2Comment);
  else
      sam.history = sprintf('%s\n%s - %s', history, datestr(now_utc, readProperty('exportNetCDF.dateFormat')), dox2Comment);
  end
  sam.history = sprintf('%s\n%s - %s', history, datestr(now_utc, readProperty('exportNetCDF.dateFormat')), oxsolComment);
  
  sample_data{k} = sam;
end

