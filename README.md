# IMOS Toolbox

The IMOS Toolbox aims at **converting oceanographic instrument files into quality-controlled IMOS compliant NetCDF files**. 

The toolbox process instruments deployed on moorings (**time series**) or during casts (**profiles**). The processing, including quality control (**QC**) of several oceanographic variables, can be done in **batch mode** or **interactive**.

Finally, the package allows deployment metadata to be ingested into the files from any JDBC supported database (including MS-access), CSV files, or added manually through a graphical user interface (GUI). Manual **QC** is also possible.

See our [wiki page](https://github.com/aodn/imos-toolbox/wiki) page for more details.

# Distribution

The **stable** releases may be obtained [here](https://github.com/aodn/imos-toolbox/releases). The releases contain both the source code and binary applications (executables).


# Requirements

We support Windows and Linux. The toolbox may be used as a **Matlab stand-alone library** or **stand-alone application** (**No Matlab is required**).

For a **stand-alone library** usage, **Matlab R2018b** or newer is required ( since version 2.6.1).

For a **stand-alone application**, you will need the Matlab Component Runtime (v95).

See [installation instructions](https://github.com/aodn/imos-toolbox/wiki/ToolboxInstallation) for further information.

# Usage

The toolbox can connect to a deployment database to collect the relevant metadata attached to each dataset. We provide an MS-Access database file template and an underlying schema, but several types of databases can be used. The Java code interface can use any JDBC API to query the deployment database. By default, [UCanAccess](http://ucanaccess.sourceforge.net/site.html) is used to query the MS-Access file.

Please read the [wiki](https://github.com/aodn/imos-toolbox/wiki) for more information on how to **use** the toolbox. 

This project is designed and maintained by [ANMN](http://imos.org.au/facilities/nationalmooringnetwork/) and [AODN](http://imos.org.au/facilities/aodn/).

# License

The toolbox is copyrighted and licensed under the terms of the GNU GPLv3. For more details, click [here](https://raw.githubusercontent.com/aodn/imos-toolbox/master/license.txt).
