function p = gsw_p_from_z(z,lat,geo_strf_dyn_height,sea_surface_geopotental)

% gsw_p_from_z                      pressure from height (76-term equation)
%==========================================================================
%
% USAGE:
%  p = gsw_p_from_z(z,lat,{geo_strf_dyn_height},{sea_surface_geopotental})
%
% DESCRIPTION:
%  Calculates sea pressure from height using computationally-efficient 
%  75-term expression for density, in terms of SA, CT and p (Roquet et al.,
%  2015).  Dynamic height anomaly, geo_strf_dyn_height, if provided,
%  must be computed with its p_ref = 0 (the surface). Also if provided,
%  sea_surface_geopotental is the geopotential at zero sea pressure. This 
%  function solves Eqn.(3.32.3) of IOC et al. (2010) iteratively for p.  
%
%  Note. Height (z) is NEGATIVE in the ocean.  Depth is -z.  
%    Depth is not used in the GSW computer software library. 
%
%  Note that this 75-term equation has been fitted in a restricted range of 
%  parameter space, and is most accurate inside the "oceanographic funnel" 
%  described in McDougall et al. (2003).  The GSW library function 
%  "gsw_infunnel(SA,CT,p)" is avaialble to be used if one wants to test if 
%  some of one's data lies outside this "funnel".  
%
% INPUT:
%  z  =  height                                                       [ m ]
%   Note. At sea level z = 0, and since z (HEIGHT) is defined 
%     to be positive upwards, it follows that while z is 
%     positive in the atmosphere, it is NEGATIVE in the ocean.
%  lat  =  latitude in decimal degrees north                [ -90 ... +90 ]
%   
% OPTIONAL:
%  geo_strf_dyn_height = dynamic height anomaly                 [ m^2/s^2 ]
%    Note that the reference pressure, p_ref, of geo_strf_dyn_height must
%     be zero (0) dbar.
%  sea_surface_geopotental = geopotential at zero sea pressure  [ m^2/s^2 ]
%
%  lat may have dimensions 1x1 or Mx1 or 1xN or MxN, where z is MxN.
%  geo_strf_dyn_height and geo_strf_dyn_height, if provided, must have 
%  dimensions MxN, which are the same as z.
%
% OUTPUT:
%   p  =  sea pressure                                             [ dbar ]
%         ( i.e. absolute pressure - 10.1325 dbar )
%
% AUTHOR: 
%  Trevor McDougall, Claire Roberts-Thomson and Paul Barker. 
%                                                      [ help@teos-10.org ]
%
% VERSION NUMBER: 3.05 (27th January 2015)
%
% REFERENCES:
%  IOC, SCOR and IAPSO, 2010: The international thermodynamic equation of
%   seawater - 2010: Calculation and use of thermodynamic properties.
%   Intergovernmental Oceanographic Commission, Manuals and Guides No. 56,
%   UNESCO (English), 196 pp.  Available from http://www.TEOS-10.org
%
%  McDougall, T.J., D.R. Jackett, D.G. Wright and R. Feistel, 2003: 
%   Accurate and computationally efficient algorithms for potential 
%   temperature and density of seawater.  J. Atmosph. Ocean. Tech., 20,
%   pp. 730-741.
%
%  McDougall T.J. and S.J. Wotherspoon, 2013: A simple modification of 
%   Newton's method to achieve convergence of order 1 + sqrt(2).  Applied 
%   Mathematics Letters, 29, 20-25.  
%
%  Moritz, 2000: Goedetic reference system 1980. J. Geodesy, 74, 128-133.
%
%  Roquet, F., G. Madec, T.J. McDougall, P.M. Barker, 2015: Accurate
%   polynomial expressions for the density and specifc volume of seawater
%   using the TEOS-10 standard. Ocean Modelling.
%
%  Saunders, P.M., 1981: Practical conversion of pressure to depth. 
%   Journal of Physical Oceanography, 11, 573-574.
%
%  This software is available from http://www.TEOS-10.org
%
%==========================================================================

%--------------------------------------------------------------------------
% Check variables and resize if necessary
%--------------------------------------------------------------------------

if ~(nargin == 2 | nargin == 3 | nargin == 4)
   error('gsw_p_from_z: Requires two, three or four inputs')
end %if

if any(z > 5)
   error('gsw_p_from_z: The input z is generally negative and values must be less than 5 m.')
end

if ~exist('geo_strf_dyn_height','var')
    geo_strf_dyn_height = zeros(size(z));
end

if ~exist('sea_surface_geopotental','var')
    sea_surface_geopotental = zeros(size(z));
end

[mz,nz] = size(z);
[ml,nl] = size(lat);
[mdh,ndh] = size(geo_strf_dyn_height);
[msg,nsg] = size(sea_surface_geopotental);

if (mz ~= mdh) | (nz ~= ndh)
    error('gsw_p_from_z: height & dynamic height anomaly need to have the same dimensions')
end
if (mdh ~= msg) | (ndh ~= nsg)
    error('gsw_p_from_z: dynamic height anomaly & the geopotential at zero sea pressure need to have the same dimensions')
end

if (ml == 1) & (nl == 1)              % lat is a scalar - fill to size of z
    lat = lat*ones(size(z));
elseif (nl == nz) & (ml == 1)         % lat is row vector,
    lat = lat(ones(1,mz), :);              % copy down each column.
elseif (mz == ml) & (nl == 1)         % lat is column vector,
    lat = lat(:,ones(1,nz));               % copy across each row.
elseif (nz == ml) & (nl == 1)          % lat is a transposed row vector,
    lat = lat.';                              % transposed then
    lat= lat(ones(1,mz), :);                % copy down each column.
elseif (mz == ml) & (nz == nl)
    % ok
else
    error('gsw_p_from_z: Inputs array dimensions arguments do not agree')
end %if

if mz == 1
    z = z.';
    lat = lat.';
    geo_strf_dyn_height = geo_strf_dyn_height.';
    sea_surface_geopotental = sea_surface_geopotental.';
    transposed = 1;
else
    transposed = 0;
end

%--------------------------------------------------------------------------
% Start of the calculation
%--------------------------------------------------------------------------

db2Pa = 1e4; 
gamma = 2.26e-7; % If the graviational acceleration were to be regarded as 
                 % being depth-independent, which is often the case in 
                 % ocean models, then gamma would be set to be zero here,
                 % and the code below works perfectly well.  
deg2rad = pi/180;
sinlat = sin(lat*deg2rad);
sin2 = sinlat.*sinlat;
gs = 9.780327*(1.0 + (5.2792e-3 + (2.32e-5*sin2)).*sin2);

% get the first estimate of p from Saunders (1981)
c1 =  5.25e-3*sin2 + 5.92e-3;
p  = -2.*z./((1-c1) + sqrt((1-c1).*(1-c1) + 8.84e-6.*z)) ;
% end of the first estimate from Saunders (1981)

df_dp = db2Pa*gsw_specvol_SSO_0(p); % initial value of the derivative of f

f = gsw_enthalpy_SSO_0(p) + gs.*(z - 0.5*gamma*(z.*z)) ...
                - (geo_strf_dyn_height + sea_surface_geopotental);
p_old = p;
p = p_old - f./df_dp;
p_mid = 0.5*(p + p_old);
df_dp = db2Pa*gsw_specvol_SSO_0(p_mid);
p = p_old - f./df_dp;

% After this one iteration through this modified Newton-Raphson iterative
% procedure (McDougall and Wotherspoon, 2013), the remaining error in p is 
% at computer machine precision, being no more than 1.6e-10 dbar. 

if transposed
    p = p.';
end

end
