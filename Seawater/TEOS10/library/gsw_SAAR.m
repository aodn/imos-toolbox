function [SAAR, in_ocean] = gsw_SAAR(p,long,lat)

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
%  David Jackett                                       [ help@teos-10.org ]
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
%==========================================================================

%--------------------------------------------------------------------------
% Check variables and resize if necessary
%--------------------------------------------------------------------------

if ~(nargin == 3)
   error('gsw_SAAR:  Requires three inputs')
end %if

[mp,np] = size(p);
[mla,nla] = size(lat);
[mlo,nlo] = size(long);

if (mp ~= mla) | (mp ~=mlo) | (np ~= nla) | (np ~= nlo)
    error('gsw_SAAR: Inputs need be of the same size')
end %if

if any(p < -1.5)
    error('gsw_SAAR: pressure needs to be positive')
end

%set any pressures between 0 and -1.5 to be equal to 0 (i.e. the surface)
p(p < 0) = 0;

%--------------------------------------------------------------------------
% Start of the calculation (extracting from a look up table)
%--------------------------------------------------------------------------

persistent SAAR_ref lats_ref longs_ref p_ref ndepth_ref

if isempty(SAAR_ref)
    gsw_data = 'gsw_data_v3_0.mat';
    
    gsw_data_file = which(gsw_data);
    
    load (gsw_data_file,'SAAR_ref','lats_ref','longs_ref','p_ref', ...
        'ndepth_ref');
end

% precalculate constants 
nx = length(longs_ref); 
ny = length(lats_ref); 
nz = length(p_ref); 
nyz = ny.*nz; 

n0 = length(p);

dlongs_ref = longs_ref(2) - longs_ref(1); 
dlats_ref = lats_ref(2) - lats_ref(1);

indsx0 = floor(1 + (nx-1)*(long - longs_ref(1))./(longs_ref(nx) - longs_ref(1)));
indsx0 = indsx0(:); 
indsx0(indsx0 == nx) = nx - 1;
              
indsy0 = floor(1 + (ny-1)*(lat - lats_ref(1))./(lats_ref(ny) - lats_ref(1)));
indsy0 = indsy0(:); 
indsy0(indsy0 == ny) = ny - 1;

% Assign a pressure bin for each bottle.
indsz0 = ones(n0,1);
for I = 2:nz   
    indsz0(p >= p_ref(I-1) & p < p_ref(I)) = I - 1;    
end
indsz0(p >= p_ref(nz)) = nz-1; 
     
indsy0_indsx0_ny = indsy0 + indsx0.*ny;        
indsn1 = indsy0_indsx0_ny - ny;              %4 xy grid points surrounding the data
indsn2 = indsy0_indsx0_ny;
indsn3 = indsy0_indsx0_ny + 1;
indsn4 = indsy0_indsx0_ny + (1 - ny);

nmax = max([ndepth_ref(indsn1)';ndepth_ref(indsn2)';ndepth_ref(indsn3)';ndepth_ref(indsn4)']);

if any(indsz0(:)' > nmax)
    inds1 = find(indsz0(:)' > nmax);                % casts deeper than GK maximum

    p(inds1) = p_ref(nmax(inds1));                  % have reset p here so have to reset indsz0
     
    indsz0(inds1) = nmax(inds1) - 1;
end

indsyx_tmp = indsy0_indsx0_ny.*nz;        % precalculate constants for loop
inds0 =  indsz0 + indsyx_tmp  - (nyz + nz);
   
data_indices = [indsx0,indsy0,indsz0,inds0]; 
data_inds = data_indices(:,3); 

r1 = (long(:) - longs_ref(indsx0))./(longs_ref(indsx0+1) - longs_ref(indsx0));
s1 = (lat(:) - lats_ref(indsy0))./(lats_ref(indsy0+1) - lats_ref(indsy0));
t1 = (p(:) - p_ref(indsz0))./(p_ref(indsz0+1) - p_ref(indsz0));
    
sa_upper = NaN(size(data_inds));
sa_lower = sa_upper;
SAAR = sa_upper;
in_ocean = ones(size(SAAR));

indsyx_tmp = indsy0_indsx0_ny.*nz;        % precalculate constants for loop
saar_nan = nan(4,n0);

for k = 1:nz-1
    
    inds_k = find(indsz0 == k);
    
    if ~isempty(inds_k) 
        
        indsXYZ = k + indsyx_tmp(inds_k);
        
        inds_di = find(data_inds == k);  
        
        % level k interpolation
        saar = saar_nan;
        
        saar(:,inds_k) = SAAR_ref([(indsXYZ-(nz+nyz))'; (indsXYZ - nz)'; (indsXYZ)'; (indsXYZ -nyz)']);
               
        inds_pan = find(abs(long(inds_k)-277.6085)<=17.6085 & ...
            abs(lat(inds_k)-9.775) <= 9.775);    
        
        if ~isempty(inds_pan)
            inds = inds_k(inds_pan);
            saar(:,inds) = gsw_saar_add_barrier(saar(:,inds),long(inds), ...
                lat(inds),longs_ref(indsx0(inds)),lats_ref(indsy0(inds)),dlongs_ref,dlats_ref);
        end
        
        if any(isnan(sum(saar(:,inds_k))))
            inds = inds_k(isnan(sum(saar(:,inds_k))));
            saar(:,inds) = gsw_saar_add_mean(saar(:,inds));
        end
        
        sa_upper(inds_di) = (1-s1(inds_di)).*(saar(1,inds_k)' + ...
            r1(inds_di).*(saar(2,inds_k)'-saar(1,inds_k)')) + ...
            s1(inds_di).*(saar(4,inds_k)' + ...
            r1(inds_di).*(saar(3,inds_k)'-saar(4,inds_k)'));  % level k+1 interpolation
        
        saar = saar_nan;
        saar(:,inds_k) = SAAR_ref([(indsXYZ+(1-nz-nyz))'; (indsXYZ+(1-nz))'; (indsXYZ+1)'; (indsXYZ+(1-nyz))';]); 
        
        if ~isempty(inds_pan)
            inds = inds_k(inds_pan);
            saar(:,inds) = gsw_saar_add_barrier(saar(:,inds),long(inds), ...
                lat(inds),longs_ref(indsx0(inds)),lats_ref(indsy0(inds)),dlongs_ref,dlats_ref);
        end
        
        if any(isnan(sum(saar(:,inds_k))))
            inds = inds_k(isnan(sum(saar(:,inds_k))));
            saar(:,inds) = gsw_saar_add_mean(saar(:,inds));
        end
        
        sa_lower(inds_di) = (1-s1(inds_di)).*(saar(1,inds_k)' + ...
            r1(inds_di).*(saar(2,inds_k)'-saar(1,inds_k)')) + ...
            s1(inds_di).*(saar(4,inds_k)' + ...
            r1(inds_di).*(saar(3,inds_k)'-saar(4,inds_k)'));
        
        if any(isfinite(sa_upper(inds_di)) & isnan(sa_lower(inds_di)))
            inds_different = find(isfinite(sa_upper(inds_di)) & isnan(sa_lower(inds_di)));
            sa_lower(inds_di(inds_different)) = sa_upper(inds_di(inds_different));
        end
        
        SAAR(inds_di) = sa_upper(inds_di) + t1(inds_di).*(sa_lower(inds_di) - sa_upper(inds_di));

    end
end

inds = find(~isfinite(SAAR)); 
SAAR(inds) = 0;

in_ocean(inds) = 0;

end

%##########################################################################

function SAAR = gsw_saar_add_mean(saar)

% gsw_saar_add_mean
%==========================================================================
%
% USAGE:
%  SAAR = gsw_saar_add_mean(saar)
%
% DESCRIPTION:
%  Replaces NaN's with nanmean of the 4 adjacent neighbours
%
% INPUT:
%  saar  =  Absolute Salinity Anomaly Ratio of the 4 adjacent neighbours  
%                                                              [ unitless ]
%
% OUTPUT:
%  SAAR  =  nanmean of the 4 adjacent neighbours               [ unitless ]
%
% AUTHOR: 
%  David Jackett
%
% MODIFIED:
%  Paul Barker and Trevor McDougall
%  Aknowlegments. Matlab programming assisance from Sjoerd Groeskamp.
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
%  The software is available from http://www.TEOS-10.org
%
%==========================================================================

if exist('nanmean','file')
    saar_nanmean = nanmean(saar);
    saar_nanmean(2,:) = saar_nanmean;
    saar_nanmean(3:4,:) = saar_nanmean;
    nans = isnan(saar);
    [Inans] = find(isnan(saar));
    saar_mean_nans = nans(Inans).*saar_nanmean(Inans);
    saar(Inans) = saar_mean_nans;
else
    saar_mean = mean(saar);
    inds_nan = find(isnan(saar_mean));
    no_nan = length(inds_nan);
    for kk = 1:no_nan
        col = inds_nan(kk);
        [Inn] = find(~isnan(saar(:,col)));
        if ~isempty(Inn)
            saar(isnan(saar(:,col)),col) = sum(saar(Inn,col))./numel(Inn);
        end
    end
end

SAAR = saar;

end

%##########################################################################

function SAAR = gsw_saar_add_barrier(saar,long,lat,longs_ref,lats_ref,dlongs_ref,dlats_ref)

% gsw_saar_add_barrier
%==========================================================================
%
% USAGE:
%  SAAR = gsw_saar_add_barrier(saar,long,lat,longs_ref,lats_ref,dlongs_ref,dlats_ref)
%
% DESCRIPTION:
%  Adds a barrier through Central America (Panama) and then averages
%  over the appropriate side of the barrier
%
% INPUT:
%  saar        =  Absolute Salinity Anomaly Ratio                          [ unitless ]
%  long        =  Longitudes of data in decimal degrees east               [ 0 ... +360 ]
%  lat         =  Latitudes of data in decimal degrees north               [ -90 ... +90 ]
%  longs_ref   =  Longitudes of regular grid in decimal degrees east       [ 0 ... +360 ]
%  lats_ref    =  Latitudes of regular grid in decimal degrees north       [ -90 ... +90 ]
%  dlongs_ref  =  Longitude difference of regular grid in decimal degrees  [ deg longitude ]
%  dlats_ref   =  Latitude difference of regular grid in decimal degrees   [ deg latitude ]
%
% OUTPUT:
%  SAAR        =  Absolute Salinity Anomaly Ratio                          [ unitless ]
%
% AUTHOR: 
%  David Jackett
%
% MODIFIED:
%  Paul Barker and Trevor McDougall
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
%  The software is available from http://www.TEOS-10.org
%
%==========================================================================

longs_pan = [260.0000 272.5900 276.5000 278.6500 280.7300 295.2170];

lats_pan  = [ 19.5500  13.9700   9.6000   8.1000   9.3300   0];

lats_lines0 = interp1(longs_pan,lats_pan,long);

lats_lines1 = interp1(longs_pan,lats_pan,longs_ref);
lats_lines2 = interp1(longs_pan,lats_pan,(longs_ref+dlongs_ref));

for k0 = 1:length(long)
    if lats_lines0(k0) <= lat(k0)
        above_line0 = 1;
    else
        above_line0 = 0;
    end
    if lats_lines1(k0) <= lats_ref(k0)
        above_line(1) = 1;
    else
        above_line(1) = 0;
    end
    if lats_lines1(k0) <= (lats_ref(k0) + dlats_ref)
        above_line(4) = 1;
    else
        above_line(4) = 0;
    end
    if lats_lines2(k0) <= lats_ref(k0)
        above_line(2) = 1;
    else
        above_line(2) = 0;
    end
    if lats_lines2(k0) <= (lats_ref(k0) + dlats_ref)
        above_line(3) = 1;
    else
        above_line(3) = 0;
    end
    saar(above_line ~= above_line0,k0) = nan;     % indices of different sides of CA line 
end

if any(isnan(saar))
    saar = gsw_saar_add_mean(saar);
end

SAAR = saar;

end
