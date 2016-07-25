function [conc_O2] = O2sol(S, T, unit)
%O2SOL Computes solubility of O2 in sea water at 1-atm pressure of air 
% including saturated water vapor.
%
% This function is based on O2sol Version 1.1 4/4/2005 writen by 
% Roberta C. Hamme (Scripps Inst of Oceanography) which can be found here :
% http://web.uvic.ca/~rhamme/O2sol.m
% 
% Reference:
% Hernan E. Garcia and Louis I. Gordon, 1992.
% "Oxygen solubility in seawater: Better fitting equations"
% Limnology and Oceanography, 37, pp. 1307-1312.
%
% Inputs:
%   S       - salinity    [PSS]
%   T       - temperature [degree C]
%   unit    - output unit, supported values = ['umol/kg', 'ml/l']
%
% Outputs:
%   concO2 	- solubility of O2  [umol/kg or ml/l] 
%
% Author:       Roberta Hamme (rhamme@ucsd.edu)
% Contributor : Guillaume Galibert <guillaume.galibert@utas.edu.au>

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

%----------------------
% Check input parameters
%----------------------
if nargin ~=3
   error('O2sol.m: Must pass 3 parameters')
end %if

% Check S,T dimensions and verify consistent
[ms,ns] = size(S);
[mt,nt] = size(T);

  
% Check that T&S have the same shape or are singular
if ((ms~=mt) | (ns~=nt)) & (ms+ns>2) & (mt+nt>2)
   error('O2sol: S & T must have same dimensions or be singular')
end %if

%------
% BEGIN
%------

% convert T to scaled temperature
temp_S = log((298.15 - T)./(273.15 + T));

% constants from Table 1 of Garcia & Gordon for the fit to Benson and Krause (1984)
if strcmpi(unit, 'umol/kg')
    A0_o2 =  5.80871;
    A1_o2 =  3.20291;
    A2_o2 =  4.17887;
    A3_o2 =  5.10006;
    A4_o2 = -9.86643e-2;
    A5_o2 =  3.80369;
    B0_o2 = -7.01577e-3;
    B1_o2 = -7.70028e-3;
    B2_o2 = -1.13864e-2;
    B3_o2 = -9.51519e-3;
    C0_o2 = -2.75915e-7;
elseif strcmpi(unit, 'ml/l')
    A0_o2 =  2.00907;
    A1_o2 =  3.22014;
    A2_o2 =  4.05010;
    A3_o2 =  4.94457;
    A4_o2 = -2.56847e-1;
    A5_o2 =  3.88767;
    B0_o2 = -6.24523e-3;
    B1_o2 = -7.37614e-3;
    B2_o2 = -1.03410e-2;
    B3_o2 = -8.17083e-3;
    C0_o2 = -4.88682e-7;
else
    error('O2sol: unit must be umol/kg or ml/l');
end

% Corrected Eqn (8) of Garcia and Gordon 1992
conc_O2 = exp(A0_o2 + A1_o2*temp_S + A2_o2*temp_S.^2 + A3_o2*temp_S.^3 + A4_o2*temp_S.^4 + A5_o2*temp_S.^5 + ...
    S.*(B0_o2 + B1_o2*temp_S + B2_o2*temp_S.^2 + B3_o2*temp_S.^3) + C0_o2*S.^2);

return