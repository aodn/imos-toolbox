function cp0 = gsw_cp0

% gsw_cp0                               the "specific heat" for use with CT
%==========================================================================
%
% USAGE:
%  cp0 = gsw_cp0
%
% DESCRIPTION:
%  The "specific heat" for use with Conservative Temperature.  cp0 is the
%  ratio of potential enthalpy to Conservative Temperature. 
%
% OUTPUT:
%  cp0  =  The "specific heat" for use                         [ J/(kg K) ]
%          with Conservative Temperature   
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
%    See Eqn. (3.3.3) and Table D.5 of this TEOS-10 Manual.  
%
%  The software is available from http://www.TEOS-10.org
%
%==========================================================================

cp0 = 3991.86795711963;

end
