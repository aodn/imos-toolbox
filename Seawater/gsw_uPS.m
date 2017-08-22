function uPS = gsw_uPS

% gsw_uPS                             unit conversion factor for salinities
%==========================================================================
%
% USAGE:
%  uPS = gsw_uPS
%
% DESCRIPTION:
%  The unit conversion factor for salinities (35.16504/35) g/kg (Millero et
%  al., 2008).  Reference Salinity SR is uPS times Practical Salinity SP. 
%
% OUTPUT:
%  uPS  =  unit conversion factor for salinities                   [ g/kg ]
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
%    See section 2.4 and Table D.4 of this TEOS-10 Manual.  
%
%  Millero, F. J., R. Feistel, D. G. Wright, and T. J. McDougall, 2008: 
%   The composition of Standard Seawater and the definition of the 
%   Reference-Composition Salinity Scale, Deep-Sea Res. I, 55, 50-72. 
%     See section 6, Eqn. (6.1) of this paper.
%
%  The software is available from http://www.TEOS-10.org
%
%==========================================================================

uPS = 35.16504/35;

end
