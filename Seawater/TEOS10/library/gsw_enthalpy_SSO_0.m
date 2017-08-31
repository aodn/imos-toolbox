function enthalpy_SSO_0 = gsw_enthalpy_SSO_0(p)
    
% gsw_enthalpy_SSO_0                               enthalpy at (SSO,CT=0,p)
%                                                            (76-term eqn.)
%==========================================================================
%  This function calculates enthalpy at the Standard Ocean Salinity, SSO, 
%  and at a Conservative Temperature of zero degrees C, as a function of
%  pressure, p, in dbar, using a streamlined version of the 76-term 
%  computationally-efficient expression for specific volume, that is, a 
%  streamlined version of the code "gsw_enthalpy(SA,CT,p)".
%
% VERSION NUMBER: 3.05 (27th January 2015)
%
% REFERENCES:
%  Roquet, F., G. Madec, T.J. McDougall, P.M. Barker, 2015: Accurate
%   polynomial expressions for the density and specifc volume of seawater
%   using the TEOS-10 standard. Ocean Modelling.
%
%==========================================================================

z = p.*1e-4;

h006 = -2.1078768810e-9; 
h007 =  2.8019291329e-10; 

dynamic_enthalpy_SSO_0_p = z.*(9.726613854843870e-4 + z.*(-2.252956605630465e-5 ...
    + z.*(2.376909655387404e-6 + z.*(-1.664294869986011e-7 ...
    + z.*(-5.988108894465758e-9 + z.*(h006 + h007.*z))))));

enthalpy_SSO_0 = dynamic_enthalpy_SSO_0_p.*1e8;     %Note. 1e8 = db2Pa*1e4;

end
