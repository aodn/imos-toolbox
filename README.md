## Context ##

![](https://raw.githubusercontent.com/wiki/aodn/imos-toolbox/images/imos_logo.png)

> _IMOS is an initiative of the Australian Government being conducted as part of the National Collaborative Research Infrastructure Strategy._

The IMOS Matlab Toolbox aims to provide an automated, easy to use interface for converting raw [[instrument data|SupportedInstruments]] into [IMOS](http://www.imos.org.au) compatible Quality Controlled NetCDF files, ready for handover to [eMII](http://imos.org.au/emii.html). The toolbox is designed to process data which is manually retrieved from long-term mooring sites.

![https://raw.githubusercontent.com/wiki/aodn/imos-toolbox/images/IMOS-Toolbox_context.png](https://raw.githubusercontent.com/wiki/aodn/imos-toolbox/images/IMOS-Toolbox_context.png)

Typical usage of the Toolbox would proceed as follows:

  1. **Import** and **pre-process** instrument data set applying calculations or transformations like local to UTC time conversion.
  1. **Automatically quality control** data using automated and semi-automated QC procedures such as impossible date and location checks, in/out of water flagging, outlier, spikes and flatlines detections.
  1. **Manually quality control** data via interactive display.
  1. IMOS compliant set of **NetCDF files are output** and include both original and modified plus QC'd data sets.

## Getting started ##

**Important**: [OceanDB2015](http://data.aodn.org.au/IMOS/public/eMII/softwares/imos-toolbox/OceanDB2015.mdb.zip) deployment database is now available, however toolbox versions below 2.3 included **will not work** with this database. If you wish to use this new deployment database, stick with the latest toolbox version 2.4 and above.

  * Grab the latest toolbox from [the Downloads page](http://data.aodn.org.au/IMOS/public/eMII/softwares/imos-toolbox/).
  * Optionally, download the [deployment database template](http://data.aodn.org.au/IMOS/public/eMII/softwares/imos-toolbox/OceanDB2015.mdb.zip), and populate it with some metadata following these [guidelines](https://raw.githubusercontent.com/wiki/aodn/imos-toolbox/documents/deployment_database_conventions.pdf). The IMOS [NetCDF User's manual](https://raw.githubusercontent.com/wiki/aodn/imos-toolbox/documents/IMOS_netCDF_usermanual_v1.3.pdf) includes a list of IMOS facility and platform codes.
  * Read the wiki pages for [[installing|ToolboxInstallation]], [[configuring|ToolboxConfiguration]] and [[using|UsingTheToolboxOverview]] the toolbox.
  * If something goes wrong, send me an [email](mailto:guillaume.galibert@utas.edu.au), or submit an [issue](https://github.com/aodn/imos-toolbox/issues).

## Going further ##

See the [[overview|ToolboxOverview]] for more details or navigate through the following links.

  * Specifications
    * [[DeploymentDatabase]]
  * Help
    * [[Installation|ToolboxInstallation]]
    * [[Configuration|ToolboxConfiguration]]
    * [[Use|UsingTheToolboxOverview]]
    * [[Supported Instruments|SupportedInstruments]]
    * [[Available pre-processing routines|PPRoutines]]
    * [[Available quality control procedures|QCProcedures]]
    * [[Troubleshooting|Troubleshooting]]
    * [[NetCDF Templates|NetCDFTemplates]]
    * [[Contribute to the code|ContributeToTheCode]]
  * Other
    * [[ProcessLevelsAndQC|ProcessLevelsAndQC]]
