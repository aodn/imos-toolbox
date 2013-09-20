This zip file contains the C source code for the NGDC software "Geomag" 
version 7.0 that computes the estimated main magnetic field values for 
given locations and dates (or ranges of dates).  Geomag requires a 
magnetic field model file for input.  Two models are included in this 
zip: IGRF11.COF and WMM2010.COF. Note that the text file formats differ 
slightly in format between Unix and Windows platforms. Two different
archives are therefore provided for Unix and Windows. The zip and tar 
files also include compiled versions (executables) of Geomag for 
Windows and Linux. This readme file contains instructions for both 
the Windows and Linux versions.

Important notice on change of file format
-----------------------------------------
The file format of IGRF11.COF had to be changed from the previous 
versions (IGRF10.cof and IGRF10.unx) because the previous format did not 
allow for the new 0.01 nT precision of the DGRF2005 coefficients. In this 
file format revision, we also swapped the previously confusing m,n ordering  
to the standard n,m where n is the degree and m is the order. The format 
was further adjusted to have blanks between all fields, so that values no
longer run into each other. This makes the files easier to read using 
unformatted read statments. 

Background
----------
IGRF11 is the eleventh generation standard main field model adopted 
by the International Association of Geomagnetism and Aeronomy (IAGA).  
This is a degree and order 10 model from 1900 to 1995 and a degree and
order 13 model from 2000 to 2015, providing estimates of the main field 
for dates between January 1, 1900 and January 1, 2015. For more information 
on the IGRF and IAGA, visit the IAGA Working Group V-MOD Web site at:
        http://www.ngdc.noaa.gov/IAGA/vmod/

WMM2010 is the standard model for the U.S. and U.K. Departments of Defense  
and for NATO, also used widely in civilian navigation systems. This is a 
degree and order 12 main field model for 2010.0 and degree and order 12 
secular variation model for 2010 - 2015. For more information on the WMM or 
to download the Technical Report, visit the WMM Web site at:
        http://www.ngdc.noaa.gov/geomag/WMM/


The computed magnetic elements are:
-----------------------------------
D: Declination
I: Inclination
H: Horizontal field strength
X: North component
Y: East component
Z: Down component
F: Total field strength
dD,dI,dH,dX,dY,dZ,dF: Change per year of the above quantities.
     

To compile this code:
------------------------------------
Gnu C compiler on Unix:
gcc -lm geomag70.c -o geomag70.exe

Intel C on Unix:
icc geomag70.c -o geomag70.exe

The Windows .exe file was generated using 
Code Gear C++ 2009 Builder


Command line option:
--------------------
Note that the geomag program can receive parameters on 
the command line. For example:
geomag70.exe IGRF11.COF 2010.32 D M133.4 10.5 10.5 

The command line syntax is listed by providing the h option as
geomag70.exe h


Spread-sheet option:
--------------------
Revision 6.1 introduced the option to read a file of
dates and locations and create a new file with a set of extra
columns giving the magnetic components. These can then be
read as columns into a spread sheet program. The dates and
coordinates have to be given in the same format as for the
command line option. See also the sample files discussed below.

For example:
geomag70.exe IGRF11.COF f in-coords.txt output.txt
will append the magnetic components and their secular
variation to the dates and locations given in 'in-coords.txt'
and write the result to a file 'output.txt'. 

This distribution contains example files which were produced 
on a Linux system using the commands:
geomag70.exe IGRF11.COF f sample_coords.txt sample_out_IGRF11.txt
geomag70.exe WMM2010.COF f sample_coords.txt sample_out_WMM2010.txt

To run the program with command line arguments under Windows:
-------------------------------------------------------------
1) Click on <Start> <Programs> <Accessories> <Command Prompt>
2) Change directory ('cd') to the folder containg geomag70.exe
3) Run the program, e.g. 'geomag70.exe IGRF11.COF f in.txt out.txt'

Contact:
--------
For further infos, or bug reports, please contact: 
stefan.maus@noaa.gov
