% gsw_SAAR       Absolute Salinity Anomaly Ratio (excluding the Baltic Sea)
%==========================================================================
%
% USAGE:  
%  [SAAR, in_ocean] = gsw_SAAR(p,long,lat)
%
% DESCRIPTION:
%  Calculates the Absolute Salinity Anomaly Ratio, SAAR, in the open ocean
%  by spatially interpolating the global reference data set of SAAR to the
%  location of the seawater sample.  
% 
%  This function uses version 3.0 of the SAAR look up table (15th May 2011). 
%
%  The Absolute Salinity Anomaly Ratio in the Baltic Sea is evaluated 
%  separately, since it is a function of Practical Salinity, not of space. 
%  The present function returns a SAAR of zero for data in the Baltic Sea. 
%  The correct way of calculating Absolute Salinity in the Baltic Sea is by 
%  calling gsw_SA_from_SP.  
%
% INPUT:
%  p     =  sea pressure                                           [ dbar ] 
%          ( i.e. absolute pressure - 10.1325 dbar )
%  long  =  Longitude in decimal degrees                     [ 0 ... +360 ]
%                                                      or [ -180 ... +180 ]
%  lat   =  Latitude in decimal degrees north               [ -90 ... +90 ]
%
%  p, long & lat need to be vectors and have the same dimensions.
%
% OUTPUT:
%  SAAR      =  Absolute Salinity Anomaly Ratio                [ unitless ]
%  in_ocean  =  0, if long and lat are a long way from the ocean 
%            =  1, if long and lat are in or near the ocean
%  Note. This flag is only set when the observation is well and truly on
%    dry land; often the warning flag is not set until one is several 
%    hundred kilometres inland from the coast. 
%
% AUTHOR: 
%  David Jackett                                       [ web mailto:help@teos-10.org ]
%
% MODIFIED:
%  Paul Barker and Trevor McDougall 
%  Acknowledgment. Matlab programming assisance from Sunke Schmidtko.
%
% VERSION NUMBER: 3.05 (27th January 2015)
%
% REFERENCES:
%  IOC, SCOR and IAPSO, 2010: The international thermodynamic equation of 
%   seawater - 2010: Calculation and use of thermodynamic properties.  
%   Intergovernmental Oceanographic Commission, Manuals and Guides No. 56,
%   UNESCO (English), 196 pp.  Available from http://www.TEOS-10.org
%
%  McDougall, T.J., D.R. Jackett, F.J. Millero, R. Pawlowicz and 
%   P.M. Barker, 2012: A global algorithm for estimating Absolute Salinity.
%   Ocean Science, 8, 1123-1134.  
%   http://www.ocean-sci.net/8/1123/2012/os-8-1123-2012.pdf 
%
%  See also gsw_SA_from_SP, gsw_deltaSA_atlas
%
%  Reference page in Help browser
%       <a href="matlab:doc gsw_SAAR">doc gsw_SAAR</a>
%  Note that this reference page includes the code contained in gsw_SAAR.
%  We have opted to encode this programme as it is a global standard and 
%  such we cannot allow anyone to change it.
%
%  The software is available from http://www.TEOS-10.org
%
%==========================================================================
