function enthalpy_SSO_0_p = gsw_enthalpy_SSO_0_p(p)
    
% gsw_enthalpy_SSO_0_p                             enthalpy at (SSO,CT=0,p)
%                                                            (48-term eqn.)
%==========================================================================
%  This function calculates enthalpy at the Standard Ocean Salinity, SSO, 
%  and at a Conservative Temperature of zero degrees C, as a function of
%  pressure, p, in dbar, using a streamlined version of the 48-term CT 
%  version of the Gibbs function, that is, a streamlined version of the 
%  code "gsw_enthalpy(SA,CT,p)".
%
%  VERSION NUMBER: 3.02 (16th November, 2012)
%
% REFERENCES:
%  McDougall T.J., P.M. Barker, R. Feistel and D.R. Jackett, 2013:  A 
%   computationally efficient 48-term expression for the density of 
%   seawater in terms of Conservative Temperature, and related properties
%   of seawater.  To be submitted to J. Atm. Ocean. Technol., xx, yyy-zzz.
%
%==========================================================================

db2Pa = 1e4;                      % factor to convert from dbar to Pa
SSO = 35.16504*ones(size(p));

sqrtSSO = sqrt(SSO);

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

a0 = v21 + SSO.*(v26 + v36*SSO + v31*sqrtSSO);
 
a1 = v37 + v41*SSO;

a2 = v43;

a3 = v47;

b0 = v01 + SSO.*(v05 + v08*sqrtSSO);
 
b1 = 0.5*(v12 + v15*SSO);

b2 = v17 + v20*SSO;

b1sq = b1.*b1; 
sqrt_disc = sqrt(b1sq - b0.*b2);

N = a0 + (2*a3.*b0.*b1./b2 - a2.*b0)./b2;

M = a1 + (4*a3.*b1sq./b2 - a3.*b0 - 2*a2.*b1)./b2;

A = b1 - sqrt_disc;
B = b1 + sqrt_disc;

part = (N.*b2 - M.*b1)./(b2.*(B - A));

enthalpy_SSO_0_p = db2Pa.*(p.*(a2 - 2*a3.*b1./b2 + 0.5*a3.*p)./b2 + ...
          (M./(2*b2)).*log(1 + p.*(2*b1 + b2.*p)./b0) + ...
           part.*log(1 + (b2.*p.*(B - A))./(A.*(B + b2.*p))));

end
