function pt0 = gsw_pt0_from_t(SA,t,p)

% gsw_pt0_from_t                               potential temperature with a
%                                       reference sea pressure of zero dbar
% =========================================================================
%
% USAGE:
%  pt0 = gsw_pt0_from_t(SA,t,p)
%
% DESCRIPTION:
%  Calculates potential temperature with reference pressure, p_ref = 0 dbar.
%  The present routine is computationally faster than the more general
%  function "gsw_pt_from_t(SA,t,p,p_ref)" which can be used for any 
%  reference pressure value.
%  This subroutine calls "gsw_entropy_part(SA,t,p)",
%  "gsw_entropy_part_zerop(SA,pt0)" and "gsw_gibbs_pt0_pt0(SA,pt0)".
%
% INPUT:
%  SA  =  Absolute Salinity                                        [ g/kg ]
%  t   =  in-situ temperature (ITS-90)                            [ deg C ]
%  p   =  sea pressure                                             [ dbar ]
%         ( i.e. absolute pressure - 10.1325 dbar )
%
%  SA & t need to have the same dimensions.
%  p may have dimensions 1x1 or Mx1 or 1xN or MxN, where SA & t are MxN.
%
% OUTPUT:
%  pt0  =  potential temperature                                  [ deg C ]
%          with reference sea pressure (p_ref) = 0 dbar.
%  Note. The reference sea pressure of the output, pt0, is zero dbar.
%
% AUTHOR:  
%  Trevor McDougall, David Jackett, Claire Roberts-Thomson and Paul Barker. 
%                                                      [ help@teos-10.org ]
%
% VERSION NUMBER: 3.05 (27th January 2015)
%
% REFERENCES:
%  IOC, SCOR and IAPSO, 2010: The international thermodynamic equation of
%   seawater - 2010: Calculation and use of thermodynamic properties.
%   Intergovernmental Oceanographic Commission, Manuals and Guides No. 56,
%   UNESCO (English), 196 pp.  Available from http://www.TEOS-10.org
%    See section 3.1 of this TEOS-10 Manual. 
%
%  McDougall T. J. and S. J. Wotherspoon, 2013: A simple modification of 
%   Newton's method to achieve convergence of order 1 + sqrt(2).  Applied 
%   Mathematics Letters, 29, 20-25.  
%
%  The software is available from http://www.TEOS-10.org
%
%==========================================================================

%--------------------------------------------------------------------------
% Check variables and resize if necessary
%--------------------------------------------------------------------------

if ~(nargin == 3)
    error('gsw_pt0_from_t: Requires 3 inputs - Absolute Salinity, temperature, and pressure')
end %if

[ms,ns] = size(SA);
[mt,nt] = size(t);
[mp,np] = size(p);

if (ms ~= mt | ns ~= nt )
    error('gsw_pt0_from_t: Input arguments do not have the same dimensions')
end %if

if (mp == 1) & (np == 1)              % p scalar - fill to size of SA
    p = p*ones(size(SA));
elseif (ns == np) & (mp == 1)         % p is row vector,
    p = p(ones(1,ms), :);              % copy down each column.
elseif (ms == mp) & (np == 1)         % p is column vector,
    p = p(:,ones(1,ns));               % copy across each row.
elseif (ns == mp) & (np == 1)          % p is a transposed row vector,
    p = p.';                              % transposed then
    p = p(ones(1,ms), :);                % copy down each column.
elseif (ms == mp) & (ns == np)
    % ok
else
    error('gsw_pt0_from_t: Inputs array dimensions arguments do not agree')
end %if

if ms == 1
    SA = SA.';
    t = t.';
    p = p.';
    transposed = 1;
else
    transposed = 0;
end

%--------------------------------------------------------------------------
% Start of the calculation
%--------------------------------------------------------------------------

% This line ensures that SA is non-negative.
SA(SA < 0) = 0;

SSO = gsw_SSO;                    % from section 2.4 of IOC et al. (2010).

s1 = SA*(35./SSO);

pt0 = t + p.*( 8.65483913395442e-6  - ...
         s1.*  1.41636299744881e-6  - ...
          p.*  7.38286467135737e-9  + ...
          t.*(-8.38241357039698e-6  + ...
         s1.*  2.83933368585534e-8  + ...
          t.*  1.77803965218656e-8  + ...
          p.*  1.71155619208233e-10));

dentropy_dt = gsw_cp0./((gsw_T0 + pt0).*(1 - 0.05.*(1 - SA./SSO)));

true_entropy_part = gsw_entropy_part(SA,t,p);

for Number_of_iterations = 1:2
    pt0_old = pt0;
    dentropy = gsw_entropy_part_zerop(SA,pt0_old) - true_entropy_part;
    pt0 = pt0_old - dentropy./dentropy_dt ; % this is half way through the modified method (McDougall and Wotherspoon, 2012)
    pt0m = 0.5*(pt0 + pt0_old);
    dentropy_dt = -gsw_gibbs_pt0_pt0(SA,pt0m);
    pt0 = pt0_old - dentropy./dentropy_dt;
end

if transposed
    pt0 = pt0.';
end

% maximum error of 6.3x10^-9 degrees C for one iteration.
% maximum error is 1.8x10^-14 degrees C for two iterations 
% (two iterations is the default, "for Number_of_iterations = 1:2"). 
% These errors are over the full "oceanographic funnel" of 
% McDougall et al. (2013), which reaches down to p = 8000 dbar. 

end
