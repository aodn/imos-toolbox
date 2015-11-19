function SP = gsw_SP_from_R(R,t,p)

% gsw_SP_from_R                  Practical Salinity from conductivity ratio 
%==========================================================================
%
% USAGE: 
%  SP = gsw_SP_from_R(R,t,p)
%
% DESCRIPTION:
%  Calculates Practical Salinity, SP, from the conductivity ratio, R,
%  primarily using the PSS-78 algorithm.  Note that the PSS-78 algorithm 
%  for Practical Salinity is only valid in the range 2 < SP < 42.  If the 
%  PSS-78 algorithm produces a Practical Salinity that is less than 2 then 
%  the Practical Salinity is recalculated with a modified form of the 
%  Hill et al. (1986) formula.  The modification of the Hill et al. (1986)
%  expression are to ensure that it is exactly consistent with PSS-78 
%  at SP = 2. 
%
% INPUT:
%  R  =  conductivity ratio                                    [ unitless ]
%  t  =  in-situ temperature (ITS-90)                             [ deg C ]
%  p  =  sea pressure                                              [ dbar ]
%        ( i.e. absolute pressure - 10.1325 dbar )
%
%  t & p may have dimensions 1x1 or Mx1 or 1xN or MxN, where R is MxN.
%
% OUTPUT:
%  SP  =   Practical Salinity on the PSS-78 scale              [ unitless ]
%
% AUTHOR:  
%  Paul Barker, Trevor McDougall and Rich Pawlowicz    [ help@teos-10.org ]
%
% VERSION NUMBER: 3.05 (27th January 2015)
%
% REFERENCES:
%  Hill, K.D., T.M. Dauphinee & D.J. Woods, 1986: The extension of the 
%   Practical Salinity Scale 1978 to low salinities. IEEE J. Oceanic Eng.,
%   OE-11, 1, 109 - 112.
%
%  IOC, SCOR and IAPSO, 2010: The international thermodynamic equation of 
%   seawater - 2010: Calculation and use of thermodynamic properties.  
%   Intergovernmental Oceanographic Commission, Manuals and Guides No. 56,
%   UNESCO (English), 196 pp.  Available from http://www.TEOS-10.org
%    See appendix E of this TEOS-10 Manual. 
%
%  Unesco, 1983: Algorithms for computation of fundamental properties of 
%   seawater. Unesco Technical Papers in Marine Science, 44, 53 pp.
%
%  The software is available from http://www.TEOS-10.org
%
%==========================================================================

%--------------------------------------------------------------------------
% Check variables and resize if necessary
%--------------------------------------------------------------------------

if ~(nargin == 3)
   error('gsw_SP_from_R:  Requires three input arguments')
end %if

[mc,nc] = size(R);
[mt,nt] = size(t);
[mp,np] = size(p);

if (mt == 1) & (nt == 1)              % t scalar - fill to size of R
    t = t*ones(size(R));
elseif (nc == nt) & (mt == 1)         % t is row vector,
    t = t(ones(1,mc), :);              % copy down each column.
elseif (mc == mt) & (nt == 1)         % t is column vector,
    t = t(:,ones(1,nc));               % copy across each row.
elseif (nc == mt) & (nt == 1)          % t is a transposed row vector,
    t = t.';                                         % transposed then
    t = t(ones(1,mc), :);                    % copy down each column.
elseif (mc == mt) & (nc == nt)
    % ok
else
    error('gsw_SP_from_R: Inputs array dimensions arguments do not agree')
end %if

if (mp == 1) & (np == 1)              % p scalar - fill to size of R
    p = p*ones(size(R));
elseif (nc == np) & (mp == 1)         % p is row vector,
    p = p(ones(1,mc), :);              % copy down each column.
elseif (mc == mp) & (np == 1)         % p is column vector,
    p = p(:,ones(1,nc));               % copy across each row.
elseif (nc == mp) & (np == 1)          % p is a transposed row vector,
    p = p.';                                         % transposed then
    p = p(ones(1,mc), :);                    % copy down each column.
elseif (mc == mp) & (nc == np)
    % ok
else
    error('gsw_SP_from_R: Inputs array dimensions arguments do not agree')
end 

if mc == 1
    R = R.';
    t = t.';
    p = p.';
    transposed = 1;
else
    transposed = 0;
end

%--------------------------------------------------------------------------
% Start of the calculation
%--------------------------------------------------------------------------

a0 =  0.0080;
a1 = -0.1692;
a2 = 25.3851;
a3 = 14.0941;
a4 = -7.0261;
a5 =  2.7081;

b0 =  0.0005;
b1 = -0.0056;
b2 = -0.0066;
b3 = -0.0375;
b4 =  0.0636;
b5 = -0.0144;

c0 =  0.6766097;
c1 =  2.00564e-2;
c2 =  1.104259e-4;
c3 = -6.9698e-7;
c4 =  1.0031e-9;

d1 =  3.426e-2;
d2 =  4.464e-4;
d3 =  4.215e-1;
d4 = -3.107e-3;

e1 =  2.070e-5;
e2 = -6.370e-10;
e3 =  3.989e-15;

k  =  0.0162;

[Iocean] = find(~isnan(R + t + p));

t68 = t(Iocean).*1.00024;
ft68 = (t68 - 15)./(1 + k*(t68 - 15));

% rt_lc corresponds to rt as defined in the UNESCO 44 (1983) routines.  
rt_lc = c0 + (c1 + (c2 + (c3 + c4.*t68).*t68).*t68).*t68;
Rp = 1 + (p(Iocean).*(e1 + p(Iocean).*(e2 + e3.*p(Iocean))))./ ...
      (1 + d1.*t68 + d2.*t68.*t68 + (d3 + d4.*t68).*R(Iocean));
Rt = R(Iocean)./(Rp.*rt_lc);   

Rt(Rt < 0) = NaN;

Rtx = sqrt(Rt);

SP = NaN(size(R));

SP(Iocean) = a0 + (a1 + (a2 + (a3 + (a4 + a5.*Rtx).*Rtx).*Rtx).*Rtx).*Rtx + ...
    ft68.*(b0 + (b1 + (b2+ (b3 + (b4 + b5.*Rtx).*Rtx).*Rtx).*Rtx).*Rtx);

% The following section of the code is designed for SP < 2 based on the
% Hill et al. (1986) algorithm.  This algorithm is adjusted so that it is
% exactly equal to the PSS-78 algorithm at SP = 2.

if any(SP(Iocean) < 2)
    [I2] = find(SP(Iocean) < 2);
    Hill_ratio = gsw_Hill_ratio_at_SP2(t(Iocean(I2))); 
    x = 400*Rt(I2);
    sqrty = 10*Rtx(I2);
    part1 = 1 + x.*(1.5 + x);
    part2 = 1 + sqrty.*(1 + sqrty.*(1 + sqrty));
    SP_Hill_raw = SP(I2) - a0./part1 - b0.*ft68(I2)./part2;
    SP(Iocean(I2)) = Hill_ratio.*SP_Hill_raw;
end

% This line ensures that SP is non-negative.
SP(SP < 0) = 0;

if transposed
    SP = SP.';
end

end
