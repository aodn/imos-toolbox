function [dv,ic,h,f] = geomag(lat,lon,h,date)

% GEOMAG Calculate geomagnetic field values from a spherical harmonic model.
%
%  [D,I,H,F] = GEOMAG(LAT,LON,DATE) returns the geomagnetic declination D,
%  inclination I, horizontal intensity H, and total intensity F as a
%  function of Julian day JD, latitude LAT, and longitude LON.
%
%  DATE = [ YY MM DD hh ], can be an N-D array. LAT and LON must be scalars.
%
%  Required ModelDataFile:  "geomag.dat"
%
%  The Data from the ModelDataFile will saved into a MAT-File: "geomag.mat"
%
%   with the Variables:  jda   M by 1
%                        gha   M by N
%                        ghb   1 by N
%
%  In further calls of GEOMAG the MAT-File will used, 
%   to make the proceeding faster.
%

%  Christian Mertens, Univ. Bremen

%  History:
%  This program is based on geomag31.c
%
%  The original FORTRAN program was developed using subroutines written by
%  A. Zunde, USGS
%  and
%  S. R. C. Malin and D. R. Barraclough, Institute of Geological Sciences, UK
%
%  Tranlated into C by
%  Craig H. Shaffer, Lockheed Missiles and Space Company
%
%  Rewritten by
%  David Owens, NGDC
%
%  Translated into Matlab by
%  Christian Mertens, Univ. Bremen

%  Disclaimer:
%  The limited testing done on this code seems to indicate that the results
%  obtained from this program are comparable to those obtained with the
%  the original code (geomag31.c). However, it is a program and most likely
%  contains bugs.

datev = datevec(date);
%date = cat(2,date,zeros(size(date,1),4));
jd = julian(datev(:,1),datev(:,2),datev(:,3),datev(:,4));

%*********************************************************************************
% Check for ModelFiles

mfile = which(mfilename);

[pfad,name] = fileparts(mfile);

file = fullfile(pfad,name);

mat_file = cat(2,file,'.mat');
dat_file = cat(2,file,'.dat');

ok = ( exist(mat_file,'file') == 2 );
if ok
   try
     v = whos('-file',mat_file);
   catch
     ok = 0;
   end
end

vars = { 'jda' 'gha' 'ghb' 'readme' };

if ok
   nn = { v.name };
   for vv = vars
       ok = ( ok & any(strcmp(nn,vv{1})) );
   end
end

if ok

   load(mat_file,vars{:});

elseif ~( exist(dat_file,'file') == 2 )

    msg = sprintf( [ 'Model data file "%s.dat" not found.\n' ...
                     ' Please get the Coefficients for latest IGRF Model\n' ...
                     '(International Geomagnetic Reference Field)\n' ...
                     ' and copy it to\n %s\n' ], ...
                       name,dat_file);

    error(msg)

else

   [msg,jda,gha,ghb,readme] = getshc(dat_file);

   if ~isempty(msg)
       error(msg);
   end

   try
      save(mat_file,'-mat',vars{:});
   end

end

%*********************************************************************************

jlm = jda(end) + median(diff(jda));

if jd > jlm
   jlm = datenum(1968,05,23)-2440000+jlm;
   str = datestr(jlm);
   msg = sprintf( [ 'Model data file "%s.dat" expired on %s.\n\n%s\n\n' ...
                    ' Check out for a new version of latest IGRF Model\n' ...
                    ' (International Geomagnetic Reference Field)\n' ...
                    ' and copy it to: %s\n' ] , ...
                      name,str,readme,dat_file);
   if exist(mat_file,'file') == 2
      msg = sprintf('%s and delete the MAT-File: %s\n',msg,mat_file);
   end
   warning(msg);
end
        
%*********************************************************************************

nmax = 10;

m = prod(size(jd));
d = NaN*jd;
x = NaN*jd;
y = NaN*jd;
z = NaN*jd;
gh = NaN*ones(m,size(gha,2));

% interpolation
k = find(jd <= jda(end));
if length(k) > 0
  gh(k,:) = interp1(jda,gha,jd(k));
end

% extrapolation
k = find(jd > jda(end));
mk = length(k);
if mk > 0
  jdk = jd(k);
  gh(k,:) = ones(mk,1)*gha(end,:) + (jdk(:) - jda(end))/365.25*ghb;
end

for i = 1:m
  [x(i),y(i),z(i)] = shval3(lat(i),lon(i),h(i),nmax,gh(i,:));
end

[dv,ic,h,f] = dihf(x,y,z);
dv = dv*180/pi;
ic = ic*180/pi;

%***********************************************************
%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

function [msg,jda,gha,ghb,readme] = getshc(file)

% GETSHC Read spherical harmonic coefficients.
%
%  [JDA,GHA,GHB] = GETSHC(FILENAME)

%  Christian Mertens, Univ. Bremen

msg = '';

jda = [];
gha = [];
ghb = [];

readme = '';

recl = 80;  % RecordLength in File, without LineBreak!!!

[fid,msg] = fopen(file,'r');

if fid == -1
   msg = sprintf('Cann''t open File: %s\n%s',file,msg);
   return
end

lnr = 0;

%-------------------------------------------
% Read CommentLines from BOF

readme = {};

while 1
   p = ftell(fid);
   b = fgetl(fid);
   if isequal(b,-1)
      break
   end
   ok = ~isempty(b);
   if ok
      ok = ( b(1) == '%' );
   end
   if ~ok
       fseek(fid,p,'bof');
       break
   end
   readme = cat(1,readme,{b(2:end)});
   lnr    = lnr + 1;
end

if isempty(readme)
   readme = '';
else
   readme = sprintf('%s\n',readme{:});
   readme = readme(1:(end-1));
end

%-------------------------------------------

m = 0;
n = 0;

p = ftell(fid);

while 1
  inbuf = fgetl(fid);
  if inbuf == -1
    break;
  end
  lnr = lnr + 1;
  if length(inbuf) ~= recl
    fclose(fid);
    msg = sprintf('Corrupt record in file "%s" on line %d.',file,lnr);
    return
  end
  if strncmp(inbuf,'   ',3)
    m = m + 1;
    a = sscanf(inbuf(12:end),'%f')';
    if a(2) > n
      n = a(2);
    end
  end
end

fseek(fid,p,'bof');

nmaxa = NaN*ones(m,1);
nmaxb = NaN*ones(m,1);
yya   = NaN*ones(m,1);
yyb   = NaN*ones(m,1);
mm    = NaN*ones(m,n);
gha   = NaN*ones(m,n);
ghb   = NaN*ones(m,n);

for ii = 1 : m
  inbuf = fgets(fid);
  a = sscanf(inbuf(12:end),'%f')';
  nmaxa(ii) = a(2);
  nmaxb(ii) = a(3);
  yya(ii) = a(5);
  yyb(ii) = a(6);
  jj = 0;
  npq = nmaxa(ii)*(nmaxa(ii)+3)/2;
  for k = 1:npq
    inbuf = fgets(fid);
    jj = jj + 1;
    mm(ii,jj) = 1;
	v = sscanf(inbuf, '%f');
    gha(ii,jj) = v(3);
    ghb(ii,jj) = v(5);
    jj = jj + 1;
    mm(ii,jj)  = v(2);
    gha(ii,jj) = v(4);
    ghb(ii,jj) = v(6);
  end
end

fclose(fid);

jda = julian(yya,ones(size(yya)),ones(size(yya)));

gha(:,mm(1,:)==0) = [];
ghb(:,mm(1,:)==0) = [];

k   = find( nmaxb ~= 0 );
ghb = ghb(k,:);


%***********************************************************
%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

function [x,y,z] = shval3(lat,lon,elev,nmax,gh)
%SHVAL3 Calculate field components from spherical harmonic model.
%  [X,Y,Z] = SHVAL3(LAT,LON,ELEV,NMAX,GH) returns the northward, eastward,
%  and vertically-downward field components as a function of latitude,
%  longitude, and elevation (m) calculated from the spherical harmonic
%  coefficients GH. NMAX ist the maximum degree and order of the coefficients.

%  History:
%  Based on subroutine 'igrf' by D. R. Barraclough and S. R. C. Malin,
%  report no. 71/1, institute of geological sciences, U.K.
%
%  FORTRAN
%    Norman W. Peddie
%    USGS, MS 964, box 25046 Federal Center, Denver, CO.  80225
%
%  C
%    C. H. Shaffer
%    Lockheed Missiles and Space Company, Sunnyvale CA
%    August 17, 1988
%
%  Matlab
%    Christian Mertens, Univ. Bremen
%    February 2001

earths_radius = 6371.2;
dtr = pi/180;
elev = elev/1000;
r = elev;
slat = sin(lat*dtr);
clat = cos(min(max(lat,-89.999),89.999)*dtr);
sl(1,:) = sin(lon*dtr);
cl(1,:) = cos(lon*dtr);

x = 0;
y = 0;
z = 0;
sd = 0.0;
cd = 1.0;
l = 1;
m = 1;
n = 0;
npq = nmax*(nmax + 3)/2;

a2 = 40680925;
b2 = 40408588;
aa = a2*clat.*clat;
bb = b2*slat.*slat;
cc = aa + bb;
dd = sqrt(cc);
r = sqrt(elev.*(elev + 2.*dd) + (a2*aa + b2*bb)/cc);
cd = (elev + dd)/r;
sd = (a2 - b2)./dd.*slat.*clat./r;
aa = slat;
slat = slat*cd - clat.*sd;
clat = clat*cd + aa.*sd;

ratio = earths_radius./r;
aa = sqrt(3);
p(1,:) = 2.0.*slat;
p(2,:) = 2.0.*clat;
p(3,:) = 4.5.*slat.*slat - 1.5;
p(4,:) = 3.0.*aa.*clat.*slat;
q(1,:) = -clat;
q(2,:) = slat;
q(3,:) = -3.0.*clat.*slat;
q(4,:) = aa.*(slat.*slat - clat.*clat);

for k = 1:npq
  if (n < m)
    m = 0;
    n = n + 1;
    rr = ratio.^(n+2);
    fn = n;
  end

  fm = m;
  if (k >= 5)
    if (m == n)
      aa = sqrt(1 - 0.5/fm);
      j = k - n - 1;
      p(k,:) = (1 + 1./fm).*aa.*clat.*p(j,:);
      q(k,:) = aa.*(clat.*q(j,:) + slat./fm.*p(j,:));
      sl(m,:) = sl(m-1,:).*cl(1,:) + cl(m-1,:).*sl(1,:);
      cl(m,:) = cl(m-1,:).*cl(1,:) - sl(m-1,:).*sl(1,:);
    else
      aa = sqrt(fn*fn - fm*fm);
      bb = sqrt((fn - 1)*(fn - 1) - fm*fm)/aa;
      cc = (2*fn - 1)/aa;
      ii = k - n;
      j = k - 2*n + 1;
      p(k,:) = (fn + 1)*(cc*slat/fn*p(ii) - bb/(fn - 1)*p(j,:));
      q(k,:) = cc*(slat.*q(ii,:) - clat/fn*p(ii)) - bb*q(j,:);
    end
  end
  aa = rr*gh(l);
  if (m == 0)
    x = x + aa.*q(k,:);
    z = z - aa.*p(k,:);
    l = l + 1;
  else
    bb = rr*gh(l+1);
    cc = aa.*cl(m,:) + bb.*sl(m,:);
    x = x + cc.*q(k,:);
    z = z - cc.*p(k,:);
    if (clat > 0)
      y = y + (aa.*sl(m,:) - bb.*cl(m,:)).*fm.*p(k,:)/((fn + 1).*clat);
    else
      y = y + (aa.*sl(m,:) - bb.*cl(m,:)).*q(k,:).*slat;
    end
    l = l + 2;
  end
  m = m + 1;
end

aa = x;
x = x.*cd + z.*sd;
z = z.*cd - aa.*sd;


%***********************************************************
%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

function [dv,ic,h,f] = dihf(x,y,z)
%DIHF Geomagnetic declination, inclination, and intensity.
%  [D,I,H,F] = DIHF(X,Y,Z) returns the geomagnetic declination D,
%  inclination I, horizontal intensity H, and total intensity F as a
%  function of the northward component X, eastward component Y, and
%  vertically-downward component Z.

%  History:
%  FORTRAN
%    A. Zunde
%    USGS, MS 964, box 25046 Federal Center, Denver, CO.  80225
%
%  C
%    C. H. Shaffer
%    Lockheed Missiles and Space Company, Sunnyvale CA
%    August 22, 1988
%
%  Matlab
%    Christian Mertens, Univ. Bremen
%    February 2001

sn = 0.0001;
% horizontal intensity
h = sqrt(x.*x + y.*y);
% total intensity
f = sqrt(x.*x + y.*y + z.*z);

ic = atan2(z,h);
hpx = h + x;
dv = 2*atan2(y,hpx);
dv(hpx<sn) = pi;
dv(h<sn) = NaN;
dv(f<sn) = NaN;
ic(f<sn) = NaN;

%***********************************************************
%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

function jd = julian(yy,mm,dd,hh)
%JULIAN Convert Gregorian date to Julian day.
%  JD = JULIAN(YY,MM,DD,HH) or JD = JULIAN([YY,MM,DD,HH]) returns the Julian
%  day number of the calendar date specified by year, month, day, and decimal
%  hour.
%
%  JD = JULIAN(YY,MM,DD) or JD = JULIAN([YY,MM,DD]) if decimal hour is absent,
%  it is assumed to be zero.
%
%  Although the formal definition holds that Julian days start and end at
%  noon, here Julian days start and end at midnight. In this convention,
%  Julian day 2440000 began at 00:00 hours, May 23, 1968.

%  Christian Mertens, Univ. Bremen

m = size(yy);
if nargin == 1
  if m(2) > 3
    hh = yy(:,4);
  else
    m(2) = 1;
    hh = zeros(m);
  end
  dd = yy(:,3);
  mm = yy(:,2);
  yy = yy(:,1);
elseif nargin == 3
  hh = zeros(m);
end

if any(yy == 0)
  error('There is no year zero.')
end

i = yy < 0;
yy(i) = yy(i) + 1;

igreg = dd + 31*(mm + 12*yy) >= 15 + 31*(10 + 12*1582);

i = mm <= 2;
mm = mm + 1;
yy(i) = yy(i) - 1;
mm(i) = mm(i) + 12;
jd = floor(365.25*yy) + floor(30.6001*mm) + dd + 1720995;
ja = floor(0.01*yy(igreg));
jd(igreg) = jd(igreg) + 2 - ja + floor(0.25*ja);
jd = jd + hh/24;

