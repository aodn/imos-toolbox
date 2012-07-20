function pres = sw_pres(DEPTH,LAT)

% SW_PRES    Pressure from depth
%===========================================================================
% SW_PRES   $Revision$  $Date$
%           Copyright (C) CSIRO, Phil Morgan 1993.
%
% USAGE:  pres = sw_pres(depth,lat)
%
% DESCRIPTION:
%    Calculates pressure in dbars from depth in meters.
%
% INPUT:  (all must have same dimensions)
%   depth = depth [metres]  
%   lat   = Latitude in decimal degress north [-90..+90]
%           (LAT may have dimensions 1x1 or 1xn where depth(mxn) )
%
% OUTPUT:
%  pres   = Pressure    [db]
%
% AUTHOR:  Phil Morgan 93-06-25  (morgan@ml.csiro.au)
%
% DISCLAIMER:
%   This software is provided "as is" without warranty of any kind.  
%   See the file sw_copy.m for conditions of use and licence.
%
% REFERENCES:
%    Saunders, P.M. 1981
%    "Practical conversion of Pressure to Depth"
%    Journal of Physical Oceanography, 11, 573-574
%
% CHECK VALUE: 
%    P=7500.00 db for LAT=30 deg, depth=7321.45 meters
%=========================================================================

% CALLER:  general purpose
% CALLEE:  none

%-------------
% CHECK INPUTS
%-------------
[mD,nD] = size(DEPTH);
[mL,nL] = size(LAT);
if mL==1 & nL==1
  LAT = LAT*ones(size(DEPTH));
end %if  

if (mD~=mL) | (nD~=nL)              % DEPTH & LAT are not the same shape
     if (nD==nL) & (mL==1)          % LAT for each column of DEPTH
        LAT = LAT( ones(1,mD), : ); %     copy LATS down each column
                                    %     s.t. dim(DEPTH)==dim(LAT)
     else
        error('sw_pres.m:  Inputs arguments have wrong dimensions')
     end %if
end %if

Transpose = 0;
if mD == 1  % row vector
   DEPTH   =  DEPTH(:);
   LAT     =  LAT(:);
   Transpose = 1;
end %if

%-------------
% BEGIN
%-------------

DEG2RAD = pi/180;
X       = sin(abs(LAT)*DEG2RAD);  % convert to radians
C1      = 5.92E-3+X.^2*5.25E-3;
pres    = ((1-C1)-sqrt(((1-C1).^2)-(8.84E-6*DEPTH)))/4.42E-6;

if Transpose
   pres = pres';
end %if

return
%===========================================================================