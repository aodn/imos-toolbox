function T0 = gsw_T0

% gsw_T0                                                 Celcius zero point
%==========================================================================
%
% USAGE:
%  T0 = gsw_T0
%
% DESCRIPTION:
%  The Celcius zero point; 273.15 K.  That is T = t + T0 where T is the
%  Absolute Temperature (in degrees K) and t is temperature in degrees C. 
%
% OUTPUT:
%  T0  =  the Celcius zero point.                                     [ K ]
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
%    See Table D.1 of this TEOS-10 Manual.  
%
%  The software is available from http://www.TEOS-10.org
%
%==========================================================================

T0 = 273.15;

end
