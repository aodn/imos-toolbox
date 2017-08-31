function CT = gsw_CT_from_pt(SA,pt)

% gsw_CT_from_pt        Conservative Temperature from potential temperature
%==========================================================================
%
% USAGE:
%  CT = gsw_CT_from_pt(SA,pt)
%
% DESCRIPTION:
%  Calculates Conservative Temperature of seawater from potential 
%  temperature (whose reference sea pressure is zero dbar).
%
% INPUT:
%  SA  =  Absolute Salinity                                        [ g/kg ]
%  pt  =  potential temperature (ITS-90)                          [ deg C ]
%
%  SA & pt need to have the same dimensions.
%
% OUTPUT:
%  CT  =  Conservative Temperature (ITS-90)                       [ deg C ]
%
% AUTHOR: 
%  David Jackett, Trevor McDougall and Paul Barker     [ help@teos-10.org ]
%  
% VERSION NUMBER: 3.05 (27th January 2015)
%
% REFERENCES:
%  IOC, SCOR and IAPSO, 2010: The international thermodynamic equation of 
%   seawater - 2010: Calculation and use of thermodynamic properties.  
%   Intergovernmental Oceanographic Commission, Manuals and Guides No. 56,
%   UNESCO (English), 196 pp.  Available from http://www.TEOS-10.org
%    See section 3.3 of this TEOS-10 Manual. 
%
%  The software is available from http://www.TEOS-10.org
%
%==========================================================================

%--------------------------------------------------------------------------
% Check variables and resize if necessary
%--------------------------------------------------------------------------

if ~(nargin == 2)
   error('gsw_CT_from_pt:  Requires two inputs')
end %if

[ms,ns] = size(SA);
[mt,nt] = size(pt);

if (mt ~= ms | nt ~= ns)
    error('gsw_CT_from_pt: SA and pt must have same dimensions')
end

if ms == 1
    SA = SA.';
    pt = pt.';
    transposed = 1;
else
    transposed = 0;
end

%--------------------------------------------------------------------------
% Start of the calculation
%--------------------------------------------------------------------------

% This line ensures that SA is non-negative.
SA(SA < 0) = 0;

sfac = 0.0248826675584615;                   % sfac = 1/(40.*(35.16504/35)). 

x2 = sfac.*SA; 
x = sqrt(x2); 
y = pt.*0.025;                               % normalize for F03 and F08.

pot_enthalpy =  61.01362420681071 + y.*(168776.46138048015 + ...
    y.*(-2735.2785605119625 + y.*(2574.2164453821433 + ...
    y.*(-1536.6644434977543 + y.*(545.7340497931629 + ...
    (-50.91091728474331 - 18.30489878927802.*y).*y))))) + ...
    x2.*(268.5520265845071 + y.*(-12019.028203559312 + ...
    y.*(3734.858026725145 + y.*(-2046.7671145057618 + ...
    y.*(465.28655623826234 + (-0.6370820302376359 - ...
    10.650848542359153.*y).*y)))) + ...
    x.*(937.2099110620707 + y.*(588.1802812170108 + ...
    y.*(248.39476522971285 + (-3.871557904936333 - ...
    2.6268019854268356.*y).*y)) + ...
    x.*(-1687.914374187449 + x.*(246.9598888781377 + ...
    x.*(123.59576582457964 - 48.5891069025409.*x)) + ...
    y.*(936.3206544460336 + ...
    y.*(-942.7827304544439 + y.*(369.4389437509002 + ...
    (-33.83664947895248 - 9.987880382780322.*y).*y))))));

%--------------------------------------------------------------------------
% The above polynomial for pot_enthalpy is the full expression for 
% potential entahlpy in terms of SA and pt, obtained from the Gibbs 
% function as below.  The above polynomial has simply collected like powers
% of x and y so that it is computationally faster than calling the Gibbs 
% function twice as is done in the commented code below.  When this code 
% below is run, the results are identical to calculating pot_enthalpy as 
% above, to machine precision.  
%
%  pr0 = zeros(size(SA));
%  pot_enthalpy = gsw_gibbs(0,0,0,SA,pt,pr0) - ...
%                       (273.15 + pt).*gsw_gibbs(0,1,0,SA,pt,pr0);
%
%-----------------This is the end of the alternative code------------------

CT = pot_enthalpy./gsw_cp0;

if transposed
    CT = CT.';
end

end
