function z = gsw_z_from_p(p,lat,geo_strf_dyn_height)

% gsw_z_from_p                                         height from pressure
%==========================================================================
%
% USAGE:  
%  z = gsw_z_from_p(p,lat,{geo_strf_dyn_height})
%
% DESCRIPTION:
%  Calculates height from sea pressure using the computationally-efficient
%  48-term expression for density in terms of SA, CT and p (McDougall et 
%  al., 2013).  Dynamic height anomaly, geo_strf_dyn_height, if provided,
%  must be computed with its p_ref = 0 (the surface).  
%
%  Note. Height z is NEGATIVE in the ocean. i.e. Depth is -z.  
%   Depth is not used in the GSW computer software library.  
%
%  Note that the 48-term equation has been fitted in a restricted range of 
%  parameter space, and is most accurate inside the "oceanographic funnel" 
%  described in McDougall et al. (2013).  The GSW library function 
%  "gsw_infunnel(SA,CT,p)" is avaialble to be used if one wants to test if 
%  some of one's data lies outside this "funnel".  
%
% INPUT:
%  p    =  sea pressure                                            [ dbar ]
%          ( i.e. absolute pressure - 10.1325 dbar )
%  lat  =  latitude in decimal degrees north                [ -90 ... +90 ]
%
% OPTIONAL:
%  geo_strf_dyn_height = dynamic height anomaly                 [ m^2/s^2 ]
%    Note that the refernce pressure, p_ref, of geo_strf_dyn_height must be 
%    zero (0) dbar.
%
%  lat may have dimensions 1x1 or Mx1 or 1xN or MxN, where p is MxN.
%  geo_strf_dyn_height, if provided, must have dimensions MxN which is
%  the same as p.
%
% OUTPUT:
%  z  =  height                                                       [ m ]
%  Note. At sea level z = 0, and since z (HEIGHT) is defined to be
%    positive upwards, it follows that while z is positive in the 
%    atmosphere, it is NEGATIVE in the ocean.
%
% AUTHOR:  
%  Trevor McDougall, Claire Roberts-Thomson & Paul Barker.
%                                                      [ help@teos-10.org ]
%
% VERSION NUMBER: 3.02 (16th November, 2012)
%
% REFERENCES:
%  IOC, SCOR and IAPSO, 2010: The international thermodynamic equation of 
%   seawater - 2010: Calculation and use of thermodynamic properties.  
%   Intergovernmental Oceanographic Commission, Manuals and Guides No. 56,
%   UNESCO (English), 196 pp.  Available from http://www.TEOS-10.org
%
%  McDougall T.J., P.M. Barker, R. Feistel and D.R. Jackett, 2013:  A 
%   computationally efficient 48-term expression for the density of 
%   seawater in terms of Conservative Temperature, and related properties
%   of seawater.  To be submitted to J. Atm. Ocean. Technol., xx, yyy-zzz.
%
%  Moritz (2000) Goedetic reference system 1980. J. Geodesy, 74, 128-133.
%   
%  This software is available from http://www.TEOS-10.org
%
%==========================================================================

%--------------------------------------------------------------------------
% Check variables and resize if necessary
%--------------------------------------------------------------------------

if ~(nargin == 2 | nargin == 3)
   error('gsw_z_from_p: Requires two or three inputs')
end %if

if ~exist('geo_strf_dyn_height','var')
    geo_strf_dyn_height = zeros(size(p));
end

[mp,np] = size(p);
[ml,nl] = size(lat);
[mdh,ndh] = size(geo_strf_dyn_height);

if (mp ~= mdh) | (np ~= ndh)
    error('gsw_z_from_p: pressure & dynamic height anomaly need to have the same dimensions')
end

if (ml == 1) & (nl == 1)              % lat scalar - fill to size of p
    lat = lat*ones(size(p));
elseif (nl == np) & (ml == 1)         % lat is row vector,
    lat = lat(ones(1,mp), :);              % copy down each column.
elseif (mp == ml) & (nl == 1)         % lat is column vector,
    lat = lat(:,ones(1,np));               % copy across each row.
elseif (np == ml) & (nl == 1)          % lat is a transposed row vector,
    lat = lat.';                              % transposed then
    lat = lat(ones(1,mp), :);                % copy down each column.
elseif (mp == ml) & (np == nl)
    % ok
else
    error('gsw_z_from_p: Inputs array dimensions arguments do not agree')
end %if

if mp == 1
    p = p.';
    lat = lat.';
    geo_strf_dyn_height = geo_strf_dyn_height.';
    transposed = 1;
else
    transposed = 0;
end

%--------------------------------------------------------------------------
% Start of the calculation
%--------------------------------------------------------------------------

gamma = 2.26e-7 ; 
DEG2RAD = pi/180;
X     = sin(lat*DEG2RAD);
sin2  = X.*X;
B     = 9.780327*(1.0 + (5.2792e-3 + (2.32e-5*sin2)).*sin2); 
A     = -0.5*gamma*B ;
C     = gsw_enthalpy_SSO_0_p(p) - geo_strf_dyn_height;
z     = -2*C./(B + sqrt(B.*B - 4.*A.*C));

if transposed
    z = z.';
end

end
