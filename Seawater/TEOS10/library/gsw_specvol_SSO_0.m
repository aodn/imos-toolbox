function specvol_SSO_0 = gsw_specvol_SSO_0(p)
    
%gsw_specvol_SSO_0                          specific volume at (SSO,CT=0,p)
%                                                        (76-term equation)
%==========================================================================
%  This function calculates specifc volume at the Standard Ocean Salinity,
%  SSO, and at a Conservative Temperature of zero degrees C, as a function 
%  of pressure, p, in dbar, using a streamlined version of the 76-term CT
%  version of specific volume, that is, a streamlined version of the code
%  "gsw_specvol(SA,CT,p)".
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

v005 = -1.2647261286e-8; 
v006 =  1.9613503930e-9; 
        
specvol_SSO_0 = 9.726613854843870e-04 + z.*(-4.505913211160929e-05 ...
    + z.*(7.130728965927127e-06 + z.*(-6.657179479768312e-07 ...
    + z.*(-2.994054447232880e-08 + z.*(v005 + v006.*z)))));

end
