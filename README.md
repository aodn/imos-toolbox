The IMOS Toolbox is mainly written in **Matlab** with a little bit of **Java** and aims at **converting oceanographic instrument files into quality controlled IMOS compliant NetCDF files**.

Along with its source code, binaires are provided so that **it can also be used without Matlab**.

It can connect to a deployment database in order to collect the relevant metadata attached to each data set. An MS-Access file is provided as a default deployment database but any type of database can be used. The Java code can use any JDBC API to query the deployment database. By default, [UCanAccess](http://ucanaccess.sourceforge.net/site.html) is used to query the MS-Access file.

The toolbox can currently process instruments deployed on moorings (**time series**) or during casts (**profiles**).

The processing of these files can be performed **interactively** with a graphical interface or in **batch mode**.

Please read the [wiki](https://github.com/aodn/imos-toolbox/wiki) for more information on how to **install** and **use** the toolbox. You can also read the [licence](https://raw.githubusercontent.com/aodn/imos-toolbox/master/license.txt) for copyright and licensing information.
