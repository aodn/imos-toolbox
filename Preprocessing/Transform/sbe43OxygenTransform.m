function [data, name, comment, history] = sbe43OxygenTransform( sam, varIdx )
%SBE43OXYGENTRANSFORM Implementation of SBE43 voltage to oxygen concentration
%data.
%
% This function provides an implementation of the oxygen concentration
% formula, specified in Seabird Application Note 64:
%
%   http://www.seabird.com/application_notes/AN64.htm
%
% In order to derive oxygen, the provided data set must contain TEMP, PRES
% and PSAL variables
%
% Inputs:
%   sam     - struct containing the data set
%   varIdx  - index into sam.variables, denoting the variable which contains
%             the raw oxygen voltage data.
%
% Outputs:
%   data    - array of oxygen concentration values, ml/l
%   name    - new variable name 'DOX'
%   comment - string which can be used for variable comment
%   history - string which can be used for the dataset history
%
% Author:       Paul McCarthy <paul.mccarthy@csiro.au>
% Contributor:  Guillaume Galibert <guillaume.galibert@utas.edu.au>
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
  narginchk(2,2);

  if ~isstruct(sam),     error('sam must be a struct');    end
  if ~isnumeric(varIdx), error('varIdx must be a number'); end

  temp    = getVar(sam.variables, 'TEMP');
  psal    = getVar(sam.variables, 'PSAL');
  presRel = getVar(sam.variables, 'PRES_REL');
  if presRel == 0
      pres    = getVar(sam.variables, 'PRES');
  end
  doVolt    = varIdx;
  
  if ~(temp && psal && (presRel || pres) && doVolt), return; end
  
  data    = sam.variables{doVolt}.data;
  name    = sam.variables{doVolt}.name;
  comment = sam.variables{doVolt}.comment;
  history = sam.history;
  
  % measured parameters
  T = sam.variables{temp}.data;
  if presRel == 0
      P = sam.variables{pres}.data;
      P = P - 14.7*0.689476; % SeaBird's atmospheric correction
  else
      P = sam.variables{presRel}.data;
  end
  S = sam.variables{psal}.data;
  V = sam.variables{doVolt}.data;
  
  % calibration coefficients
  params.Soc   = 1.0;
  params.Voff  = 0;
  params.A     = 0;
  params.B     = 0;
  params.C     = 0;
  params.E     = 0;
  params.Tau20 = 0.0;
  params.D1    = 1.92634e-004;
  params.D2    = -4.64803e-002;
  params.H1    = -0.033;
  params.H2    = 5000;
  params.H3    = 1450;
  
  % calculated values
  [lat, lon] = getLatLonForGSW(sam);

  if isempty(lat) || isempty(lon), return; end % cancelled by user

  SA = gsw_SA_from_SP(S, P, lon, lat);
  potT = gsw_pt0_from_t(SA, T, P);
  params.oxsol = gsw_O2sol_SP_pt(S, potT);
  params.dVdt  = [0.0; diff(V)];
  params.tauTP = params.Tau20 * exp(params.D1 .* P + params.D2 .* (T - 20.0));
  params.K     = T + 273.15;
  
  V    = hysteresisCorrection(V, T, P, params);
  data = oxygenConcentration(V, T, S, P, params);
  
  name = 'DOX';
  sbe43OxygenTransformComment = ['sbe43OxygenTransform: ' name ' derived from ' ...
      sam.variables{doVolt}.name ' following SeaBird application note 64 ' ...
      '(http://www.seabird.com/application_notes/AN64-3.htm). Oxygen ' ...
      'solubility at atmospheric pressure was derived from TEMP, PSAL, ' presName ...
      ', LATITUDE and LONGITUDE using gsw_O2sol_SP_pt, gsw_pt0_from_t ' ...
      'and gsw_SA_from_SP from the Gibbs-SeaWater toolbox (TEOS-10) v3.06.'];
  if isempty(comment)
      comment = sbe43OxygenTransformComment;
  else
      comment = [comment ' ' sbe43OxygenTransformComment];
  end
  if isempty(history)
      history = sprintf('%s - %s', datestr(now_utc, readProperty('exportNetCDF.dateFormat')), sbe43OxygenTransformComment);
  else
      history = sprintf('%s\n%s - %s', history, datestr(now_utc, readProperty('exportNetCDF.dateFormat')), sbe43OxygenTransformComment);
  end
end

function oxygen = oxygenConcentration(V, T, S, P, params)
%OXYGENCONCENTRATION Calculates oxygen concentration.
%
% This function is an implementation of the oxygen concentration equation
% specified in Seabird Application Note 64.
%
% Inputs:
%   V      - Oxygen voltage data
%   T      - Temperature, degrees celsius
%   S      - Salinity, PSU
%   P      - Pressure, decibars
%   params - struct containing coefficients and parameters
%
% Outputs:
%   oxygen - Oxygen concentration, mL/L
%

  Soc   = params.Soc;
  Voff  = params.Voff;
  tauTP = params.tauTP;
  dVdt  = params.dVdt;
  oxsol = params.oxsol;
  A     = params.A;
  B     = params.B;
  C     = params.C;
  E     = params.E;
  K     = params.K;
  
  oxygen = Soc   .* (V      + ...
                     Voff   + ...
                     tauTP .* ...
                     dVdt) .* ...
           oxsol .* (1.0        + ...
                     A .* T     + ...
                     B .* T.^2  + ...
                     C .* T.^3) .* ...
           exp(E .* P ./ K);
end

function V = hysteresisCorrection(V, T, P, params)
%HYSTERESISCORRECTION Applies hysteresis correction on the given oxygen
% voltage data.
%
% This function is an implementation of the Hysteresis Algorithm using 
% Oxygen Voltage Values, as specified in Seabird Application Note 64-3:
%
%   http://www.seabird.com/application_notes/AN64-3.htm
%
% Inputs:
%   V      - Oxygen voltage data
%   T      - Time (Matlab serial time)
%   P      - Pressure in decibars
%   params - struct containing coefficients H1, H2, H3 and Voff.
%
% Outputs:
%   V      - Corrected oxygen voltage data
%

  % turn time into seconds since start
  T = T  - T(1);
  T = T ./ 86400;

  H1   = params.H1;
  H2   = params.H2;
  H3   = params.H3;
  Voff = params.Voff;
  
  for k = 2:length(V)
    
    D = 1 + H1 .* (exp(P(k) ./ H2) - 1);
    C = exp(-1 .* (T(k) - T(k-1)) ./ H3);
    
    V(k) = V(k) + Voff;
    V(k) = ((V(k) + (V(k-1) .* C .* D)) - (V(k-1) .* C)) ./ D;
    V(k) = V(k) - Voff;
  end
end
