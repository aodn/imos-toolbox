# IMOS Toolbox #

![http://imos-toolbox.googlecode.com/svn/wiki/images/imos_logo.png](http://imos-toolbox.googlecode.com/svn/wiki/images/imos_logo.png)

> _IMOS is an initiative of the Australian Government being conducted as part of the National Collaborative Research Infrastructure Strategy._

The IMOS Matlab Toolbox aims to provide an automated, easy to use interface for converting raw [instrument data](SupportedInstruments.md) into [IMOS](http://www.imos.org.au) compatible Quality Controlled NetCDF files, ready for handover to [eMII](http://imos.org.au/emii.html). The toolbox is designed to process data which is manually retrieved from long-term mooring sites.

![http://imos-toolbox.googlecode.com/svn/wiki/images/IMOS-Toolbox_context.png](http://imos-toolbox.googlecode.com/svn/wiki/images/IMOS-Toolbox_context.png)

Typical usage of the Toolbox would proceed as follows:

  1. User downloads data set from an instrument supported by the Toolbox (e.g. SBE37).
  1. User imports data set into Toolbox and performs some pre-processing tasks like local time to UTC time conversion.
  1. Toolbox executes automatic QC procedures over data set, such as impossible date and location checks, in/out of water flagging, outlier, spikes and flatlines detections.
  1. User performs manual QC over data via interactive display.
  1. Toolbox generates IMOS compliant NetCDF files containing non QC'd and QC'd data sets.

It makes use of the [Gibbs-SeaWater toolbox (TEOS-10)](http://www.teos-10.org/).

See the [overview](ToolboxOverview.md) for more details and then browse the whole Wiki through the [sidebar](Sidebar.md) on the left.

### Getting started ###

**Important**

[OceanDB2015](http://data.aodn.org.au/IMOS/public/eMII/softwares/imos-toolbox/OceanDB2015.mdb.zip) deployment database is now available, however toolbox versions below 2.3 included **will not work** with this database. If you wish to use this new deployment database, stick with the latest toolbox version 2.4 and above.

  * Grab the latest toolbox from [the Downloads page](http://data.aodn.org.au/IMOS/public/eMII/softwares/imos-toolbox/).
  * If you're using the toolbox as a standalone, [install the proper Matlab Runtime](http://code.google.com/p/imos-toolbox/wiki/ToolboxInstallation#Install_Matlab_Runtime). A new Matlab runtime is required for toolbox versions 2.3 and above.
  * Optionally, download the [deployment database template](http://data.aodn.org.au/IMOS/public/eMII/softwares/imos-toolbox/OceanDB2015.mdb.zip), and populate it with some metadata. Ask me if you wish to migrate from one version to another.
  * Check the [wiki pages](http://code.google.com/p/imos-toolbox/wiki/ToolboxOverview?tm=6) for using and configuring the toolbox.
  * If you're using a deployment database, have a look at the [guidelines](http://imos-toolbox.googlecode.com/svn/wiki/documents/deployment_database_conventions.pdf) for deployment database metadata entry. The latest IMOS NetCDF User's manual, containing a list of IMOS facility and platform codes, is available [here](https://imos-toolbox.googlecode.com/svn/wiki/documents/IMOS_netCDF_usermanual_v1.3.pdf).
  * If something goes wrong, send me an [email](http://code.google.com/u/guillaume.galibert/), or submit an [issue](http://code.google.com/p/imos-toolbox/issues/list).