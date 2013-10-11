function specvol_SSO_0_p = gsw_specvol_SSO_0_p(p)
    
%gsw_specvol_SSO_0_p                        specific volume at (SSO,CT=0,p)
%                                                        (48-term equation)
%==========================================================================
%  This function calculates specifc volume at the Standard Ocean Salinity,
%  SSO, and at a Conservative Temperature of zero degrees C, as a function 
%  of pressure, p, in dbar, using a streamlined version of the 48-term CT
%  version of specific volume, that is, a streamlined version of the code
%  "gsw_specvol(SA,CT,p)".
%
% VERSION NUMBER: 3.02 (16th November, 2012)
%
% REFERENCES:
%  McDougall T.J., P.M. Barker, R. Feistel and D.R. Jackett, 2013:  A 
%   computationally efficient 48-term expression for the density of 
%   seawater in terms of Conservative Temperature, and related properties
%   of seawater.  To be submitted to J. Atm. Ocean. Technol., xx, yyy-zzz.
%
%==========================================================================
                        
v01 =  9.998420897506056e+2;
v05 = -6.698001071123802;
v08 = -3.988822378968490e-2;
v12 = -2.233269627352527e-2;
v15 = -1.806789763745328e-4;
v17 = -3.087032500374211e-7;
v20 =  1.550932729220080e-10;
v21 =  1.0;
v26 = -7.521448093615448e-3;
v31 = -3.303308871386421e-5;
v36 =  5.419326551148740e-6;
v37 = -2.742185394906099e-5;
v41 = -1.105097577149576e-7;
v43 = -1.119011592875110e-10;
v47 = -1.200507748551599e-15;

SSO = 35.16504*ones(size(p));

sqrtSSO = 5.930011804372737*ones(size(p)); % sqrt(SSO) = 5.930011804372737;

specvol_SSO_0_p = (v21 + SSO.*(v26 + v36*SSO + v31*sqrtSSO)  ...
             + p.*(v37 + v41*SSO + p.*(v43 + v47*p )))./ ...
             (v01 + SSO.*(v05 + v08*sqrtSSO) ...
             + p.*(v12 + v15*SSO + p.*(v17 + v20*SSO)));
                   
end
