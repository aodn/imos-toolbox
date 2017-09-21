function Hill_ratio = gsw_Hill_ratio_at_SP2(t)

% gsw_Hill_ratio_at_SP2                               Hill ratio at SP of 2
%==========================================================================
%
% USAGE:  
%  Hill_ratio = gsw_Hill_ratio_at_SP2(t)
%
% DESCRIPTION:
%  Calculates the Hill ratio, which is the adjustment needed to apply for
%  Practical Salinities smaller than 2.  This ratio is defined at a 
%  Practical Salinity = 2 and in-situ temperature, t using PSS-78. The Hill
%  ratio is the ratio of 2 to the output of the Hill et al. (1986) formula
%  for Practical Salinity at the conductivity ratio, Rt, at which Practical
%  Salinity on the PSS-78 scale is exactly 2.
%
% INPUT:
%  t  =  in-situ temperature (ITS-90)                             [ deg C ]
%
% OUTPUT:
%  Hill_ratio  =  Hill ratio at SP of 2                        [ unitless ]
%
% AUTHOR:  
%  Trevor McDougall and Paul Barker                    [ help@teos-10.org ]
%
% VERSION NUMBER: 3.05 (27th January 2015)
%
% REFERENCES:
%  Hill, K.D., T.M. Dauphinee & D.J. Woods, 1986: The extension of the 
%   Practical Salinity Scale 1978 to low salinities. IEEE J. Oceanic Eng.,
%   11, 109 - 112.
%
%  IOC, SCOR and IAPSO, 2010: The international thermodynamic equation of 
%   seawater - 2010: Calculation and use of thermodynamic properties.  
%   Intergovernmental Oceanographic Commission, Manuals and Guides No. 56,
%   UNESCO (English), 196 pp.  Available from http://www.TEOS-10.org
%    See appendix E of this TEOS-10 Manual.  
%
%  McDougall T.J. and S.J. Wotherspoon, 2013: A simple modification of 
%   Newton's method to achieve convergence of order 1 + sqrt(2).  Applied 
%   Mathematics Letters, 29, 20-25.  
%
%  Unesco, 1983: Algorithms for computation of fundamental properties of 
%   seawater. Unesco Technical Papers in Marine Science, 44, 53 pp.
%
%  The software is available from http://www.TEOS-10.org
%
%==========================================================================

%--------------------------------------------------------------------------
% Check variables
%--------------------------------------------------------------------------

if ~(nargin == 1)
    error('gsw_Hill_ratio_at_SP2: Needs only one input argument')
end %if

SP2 = 2.*(ones(size(t)));

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

g0 = 2.641463563366498e-1;
g1 = 2.007883247811176e-4;
g2 = -4.107694432853053e-6;
g3 = 8.401670882091225e-8;
g4 = -1.711392021989210e-9;
g5 = 3.374193893377380e-11;
g6 = -5.923731174730784e-13;
g7 = 8.057771569962299e-15;
g8 = -7.054313817447962e-17;
g9 = 2.859992717347235e-19;

k  =  0.0162;

t68 = t.*1.00024;
ft68 = (t68 - 15)./(1 + k.*(t68 - 15));

%--------------------------------------------------------------------------
% Find the initial estimates of Rtx (Rtx0) and of the derivative dSP_dRtx
% at SP = 2. 
%--------------------------------------------------------------------------
Rtx0 = g0 + t68.*(g1 + t68.*(g2 + t68.*(g3 + t68.*(g4 + t68.*(g5...
         + t68.*(g6 + t68.*(g7 + t68.*(g8 + t68.*g9))))))));
     
dSP_dRtx =  a1 + (2*a2 + (3*a3 + (4*a4 + 5*a5.*Rtx0).*Rtx0).*Rtx0).*Rtx0 + ...
    ft68.*(b1 + (2*b2 + (3*b3 + (4*b4 + 5*b5.*Rtx0).*Rtx0).*Rtx0).*Rtx0);    

%--------------------------------------------------------------------------
% Begin a single modified Newton-Raphson iteration (McDougall and 
% Wotherspoon, 2013) to find Rt at SP = 2.
%--------------------------------------------------------------------------
SP_est = a0 + (a1 + (a2 + (a3 + (a4 + a5.*Rtx0).*Rtx0).*Rtx0).*Rtx0).*Rtx0 ...
        + ft68.*(b0 + (b1 + (b2+ (b3 + (b4 + b5.*Rtx0).*Rtx0).*Rtx0).*Rtx0).*Rtx0);
Rtx = Rtx0 - (SP_est - SP2)./dSP_dRtx;
Rtxm = 0.5*(Rtx + Rtx0);
dSP_dRtx =  a1 + (2*a2 + (3*a3 + (4*a4 + 5*a5.*Rtxm).*Rtxm).*Rtxm).*Rtxm...
        + ft68.*(b1 + (2*b2 + (3*b3 + (4*b4 + 5*b5.*Rtxm).*Rtxm).*Rtxm).*Rtxm);
Rtx = Rtx0 - (SP_est - SP2)./dSP_dRtx;

% This is the end of one full iteration of the modified Newton-Raphson 
% iterative equation solver.  The error in Rtx at this point is equivalent 
% to an error in SP of 9e-16 psu.  
                                
x = 400*Rtx.*Rtx;
sqrty = 10*Rtx;
part1 = 1 + x.*(1.5 + x) ;
part2 = 1 + sqrty.*(1 + sqrty.*(1 + sqrty));
SP_Hill_raw_at_SP2 = SP2 - a0./part1 - b0.*ft68./part2;

Hill_ratio = 2./SP_Hill_raw_at_SP2;

end
