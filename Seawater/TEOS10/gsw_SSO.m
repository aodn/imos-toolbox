function SSO = gsw_SSO

% gsw_SSO                                 Standard Ocean Reference Salinity
%==========================================================================
%
% USAGE:
%  SSO = gsw_SSO
%
% DESCRIPTION:
%  SSO is the Standard Ocean Reference Salinity (35.16504 g/kg).
%
%  SSO is the best estimate of the Absolute Salinity of Standard Seawater
%  when the seawater sample has a Practical Salinity, SP, of 35
%  (Millero et al., 2008), and this number is a fundmental part of the 
%  TEOS-10 definition of seawater.  
% 
% OUTPUT:
%  SSO  =  Standard Ocean Reference Salinity.                      [ g/kg ]
%
% AUTHOR: 
%  Trevor McDougall and Paul Barker                    [ help@teos-10.org ]
%
% VERSION NUMBER: 3.05 (27th January 2015)
%
% REFERENCES:
%  IOC, SCOR and IAPSO, 2010: The international thermodynamic equation of 
%   seawater - 2010: Calculation and use of thermodynamic properties.  
%   Intergovernmental Oceanographic Commission, Manuals and Guides No. 56,
%   UNESCO (English), 196 pp.  Available from http://www.TEOS-10.org.
%    See appendices A.3, A.5 and Table D.4 of this TEOS-10 Manual.  
%
%  Millero, F. J., R. Feistel, D. G. Wright, and T. J. McDougall, 2008: 
%   The composition of Standard Seawater and the definition of the 
%   Reference-Composition Salinity Scale, Deep-Sea Res. I, 55, 50-72. 
%    See Table 4 and section 5 of this paper.
%
%  The software is available from http://www.TEOS-10.org
%
%==========================================================================

SSO = 35.16504;

end
