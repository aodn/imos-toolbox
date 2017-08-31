function O2sol = gsw_O2sol_SP_pt(SP,pt)

% gsw_O2sol_SP_pt                              solubility of O2 in seawater
%==========================================================================
%
% USAGE:  
%  O2sol = gsw_O2sol_SP_pt(SP,pt)
%
% DESCRIPTION:
%  Calculates the oxygen concentration expected at equilibrium with air at 
%  an Absolute Pressure of 101325 Pa (sea pressure of 0 dbar) including 
%  saturated water vapor.  This function uses the solubility coefficients 
%  derived from the data of Benson and Krause (1984), as fitted by Garcia 
%  and Gordon (1992, 1993).
%
%  Note that this algorithm has not been approved by IOC and is not work 
%  from SCOR/IAPSO Working Group 127. It is included in the GSW
%  Oceanographic Toolbox as it seems to be oceanographic best practice.
%
% INPUT:  
%  SP  =  Practical Salinity  (PSS-78)                         [ unitless ]
%  pt  =  potential temperature (ITS-90) referenced               [ deg C ]
%         to one standard atmosphere (0 dbar).
%
%  SP & pt need to have the same dimensions.
%
% OUTPUT:
%  O2sol = solubility of oxygen in micro-moles per kg           [ umol/kg ] 
% 
% AUTHOR:  Roberta Hamme, Paul Barker and Trevor McDougall
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
%  Benson, B.B., and D. Krause, 1984: The concentration and isotopic 
%   fractionation of oxygen dissolved in freshwater and seawater in 
%   equilibrium with the atmosphere. Limnology and Oceanography, 29, 
%   620-632.
%
%  Garcia, H.E., and L.I. Gordon, 1992: Oxygen solubility in seawater: 
%   Better fitting equations. Limnology and Oceanography, 37, 1307-1312.
%
%  Garcia, H.E., and L.I. Gordon, 1993: Erratum: Oxygen solubility in 
%   seawater: better fitting equations. Limnology and Oceanography, 38,
%   656.
%
%  The software is available from http://www.TEOS-10.org
%
%==========================================================================

%--------------------------------------------------------------------------
% Check variables and resize if necessary
%--------------------------------------------------------------------------

if nargin ~=2
   error('gsw_O2sol_SP_pt: Requires two inputs')
end %if

[ms,ns] = size(SP);
[mt,nt] = size(pt);

if (mt ~= ms | nt ~= ns)
    error('gsw_O2sol_SP_pt: SP and pt must have same dimensions')
end

if ms == 1
    SP = SP.';
    pt = pt.';
    transposed = 1;
else
    transposed = 0;
end

%--------------------------------------------------------------------------
% Start of the calculation
%--------------------------------------------------------------------------

x = SP;        % Note that salinity argument is Practical Salinity, this is
             % beacuse the major ionic components of seawater related to Cl  
          % are what affect the solubility of non-electrolytes in seawater.   

pt68 = pt.*1.00024;     % pt68 is the potential temperature in degress C on 
              % the 1968 International Practical Temperature Scale IPTS-68.
                  
y = log((298.15 - pt68)./(gsw_T0 + pt68));

% The coefficents below are from the second column of Table 1 of Garcia and
% Gordon (1992)
a0 =  5.80871; 
a1 =  3.20291;
a2 =  4.17887;
a3 =  5.10006;
a4 = -9.86643e-2;
a5 =  3.80369;
b0 = -7.01577e-3;
b1 = -7.70028e-3;
b2 = -1.13864e-2;
b3 = -9.51519e-3;
c0 = -2.75915e-7;

O2sol = exp(a0 + y.*(a1 + y.*(a2 + y.*(a3 + y.*(a4 + a5*y)))) ...
          + x.*(b0 + y.*(b1 + y.*(b2 + b3*y)) + c0*x));

if transposed
    O2sol = O2sol.';
end

end