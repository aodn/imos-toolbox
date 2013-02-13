function [SA, in_ocean] = gsw_SA_from_SP(SP,p,long,lat)

% gsw_SA_from_SP                  Absolute Salinity from Practical Salinity
%==========================================================================
%
% USAGE:  
%  [SA, in_ocean] = gsw_SA_from_SP(SP,p,long,lat)
%
% DESCRIPTION:
%  Calculates Absolute Salinity from Practical Salinity.  Since SP is 
%  non-negative by definition, this function changes any negative input 
%  values of SP to be zero.  
%
% INPUT:
%  SP   =  Practical Salinity  (PSS-78)                        [ unitless ]
%  p    =  sea pressure                                            [ dbar ]
%         ( i.e. absolute pressure - 10.1325 dbar )
%  long =  longitude in decimal degrees                      [ 0 ... +360 ]
%                                                     or  [ -180 ... +180 ]
%  lat  =  latitude in decimal degrees north                [ -90 ... +90 ] 
%
%  p, lat & long may have dimensions 1x1 or Mx1 or 1xN or MxN,
%  where SP is MxN.
%
% OUTPUT:
%  SA        =  Absolute Salinity                                  [ g/kg ]
%  in_ocean  =  0, if long and lat are a long way from the ocean 
%            =  1, if long and lat are in the ocean
%  Note. This flag is only set when the observation is well and truly on
%    dry land; often the warning flag is not set until one is several 
%    hundred kilometres inland from the coast. 
% 
% AUTHOR: 
%  David Jackett, Trevor McDougall & Paul Barker       [ help@teos-10.org ]
%
% VERSION NUMBER: 3.02 (7th January, 2013)
%
% REFERENCES:
%  IOC, SCOR and IAPSO, 2010: The international thermodynamic equation of 
%   seawater - 2010: Calculation and use of thermodynamic properties.  
%   Intergovernmental Oceanographic Commission, Manuals and Guides No. 56,
%   UNESCO (English), 196 pp.  Available from http://www.TEOS-10.org
%    See section 2.5 and appendices A.4 and A.5 of this TEOS-10 Manual. 
%
%  McDougall, T.J., D.R. Jackett, F.J. Millero, R. Pawlowicz and 
%   P.M. Barker, 2012: A global algorithm for estimating Absolute Salinity.
%   Ocean Science, 8, 1123-1134.  
%   http://www.ocean-sci.net/8/1123/2012/os-8-1123-2012.pdf 
%
%  The software is available from http://www.TEOS-10.org
%
%==========================================================================

%--------------------------------------------------------------------------
% Check variables and resize if necessary
%--------------------------------------------------------------------------

if ~(nargin==4)
    error('gsw_SA_from_SP:  Requires four inputs')
end %if

[ms,ns] = size(SP);
[mp,np] = size(p);

if (mp == 1) & (np == 1)               % p is a scalar - fill to size of SP
    p = p*ones(size(SP));
elseif (ns == np) & (mp == 1)          % p is row vector,
    p = p(ones(1,ms), :);                % copy down each column.
elseif (ms == mp) & (np == 1)          % p is column vector,
    p = p(:,ones(1,ns));                 % copy across each row.
elseif (ns == mp) & (np == 1)          % p is a transposed row vector,
    p = p.';                              % transposed then
    p = p(ones(1,ms), :);                % copy down each column.
elseif (ms == mp) & (ns == np)
    % ok
else
    error('gsw_SA_from_SP: Inputs array dimensions arguments do not agree')
end %if

[mla,nla] = size(lat);

if (mla == 1) & (nla == 1)             % lat is a scalar - fill to size of SP
    lat = lat*ones(size(SP));
elseif (ns == nla) & (mla == 1)        % lat is a row vector,
    lat = lat(ones(1,ms), :);           % copy down each column.
elseif (ms == mla) & (nla == 1)        % lat is a column vector,
    lat = lat(:,ones(1,ns));            % copy across each row.
elseif (ns == mla) & (nla == 1)        % lat is a transposed row vector,
    lat = lat.';                         % transposed then
    lat = lat(ones(1,ms), :);           % copy down each column.
elseif (ms == mla) & (ns == nla)
    % ok
else
    error('gsw_SA_from_SP: Inputs array dimensions arguments do not agree')
end %if

[mlo,nlo] = size(long);
long(long < 0) = long(long < 0) + 360; 

if (mlo == 1) & (nlo == 1)            % long is a scalar - fill to size of SP
    long = long*ones(size(SP));
elseif (ns == nlo) & (mlo == 1)       % long is a row vector,
    long = long(ones(1,ms), :);        % copy down each column.
elseif (ms == mlo) & (nlo == 1)       % long is a column vector,
    long = long(:,ones(1,ns));         % copy across each row. 
elseif (ns == mlo) & (nlo == 1)       % long is a transposed row vector,
    long = long.';                      % transposed then
    long = long(ones(1,ms), :);        % copy down each column.
elseif (ms == nlo) & (mlo == 1)       % long is a transposed column vector,
    long = long.';                      % transposed then
    long = long(:,ones(1,ns));        % copy down each column.
elseif (ms == mlo) & (ns == nlo)
    % ok
else
    error('gsw_SA_from_SP: Inputs array dimensions arguments do not agree')
end %if

if ms == 1
    SP = SP.';
    p = p.';
    lat = lat.';
    long = long.';
    transposed = 1;
else
    transposed = 0;
end

% remove out of range values.
SP(p < 100 & SP > 120) = NaN;
SP(p >= 100 & SP > 42) = NaN;

% change standard blank fill values to NaN's.
SP(abs(SP) == 99999 | abs(SP) == 999999) = NaN;
p(abs(p) == 99999 | abs(p) == 999999) = NaN;
long(abs(long) == 9999 | abs(long) == 99999) = NaN;
lat(abs(lat) == 9999 | abs(lat) == 99999) = NaN;

if any(p < -1.5 | p > 12000)
    error('gsw_SA_from_SP: pressure is out of range')
end
if any(long < 0 | long > 360)
    error('gsw_SA_from_SP: longitude is out of range')
end
if any(abs(lat) > 90)
    error('gsw_SA_from_SP: latitude is out of range')
end

%--------------------------------------------------------------------------
% Start of the calculation
%--------------------------------------------------------------------------
 
% This ensures that SP is non-negative.
SP(SP < 0) = 0;

[Iocean] = find(~isnan(SP + p + lat + long));

SA = nan(size(SP));
SAAR = SA;
in_ocean = SA;
 
% The following function (gsw_SAAR) finds SAAR in the non-Baltic parts of 
% the world ocean.  (Actually, this gsw_SAAR look-up table returns values 
% of zero in the Baltic Sea since SAAR in the Baltic is a function of SP, 
% not space. 
[SAAR(Iocean), in_ocean(Iocean)] = gsw_SAAR(p(Iocean),long(Iocean),lat(Iocean));

SA(Iocean) = (35.16504/35)*SP(Iocean).*(1 + SAAR(Iocean));

% Here the Practical Salinity in the Baltic is used to calculate the
% Absolute Salinity there. 
SA_baltic(Iocean) = gsw_SA_from_SP_Baltic(SP(Iocean),long(Iocean),lat(Iocean));

if any(~isnan(SA_baltic(Iocean)))
    [Ibaltic] = find(~isnan(SA_baltic(Iocean)));
    SA(Iocean(Ibaltic)) = SA_baltic(Iocean(Ibaltic));
end

if transposed
    SA = SA';
    in_ocean = in_ocean';
end

end
