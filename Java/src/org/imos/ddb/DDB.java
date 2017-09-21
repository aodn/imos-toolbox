/*
 * Copyright (C) 2017, Australian Ocean Data Network (AODN) and Integrated 
 * Marine Observing System (IMOS).
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation version 3 of the License.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.

 * You should have received a copy of the GNU General Public License
 * along with this program.
 * If not, see <https://www.gnu.org/licenses/gpl-3.0.en.html>.
 */
package org.imos.ddb;

import java.io.File;
import java.util.ArrayList;

/**
 * Interface providing access to the Deployment Database (DDB). Provides the 
 * ability to query individual tables. 
 * 
 * Results are returned as lists containing instances of the object equivalent 
 * of the queried table. See the class definitions in the org.imos.ddb.schema
 * package.
 * 
 * The DDB is a singleton; only one DDB instance may be in existence at any 
 * time; this instance is accessed via the static getDDB method.
 * 
 * @author Paul McCarthy <paul.mccarthy@csiro.au>
 * @author Gordon Keith <gordon.keith@csiro.au>
 *   -provides a method getDDB(String driver, String connection, String user, 
 *   String password)
 */
public abstract class DDB {

	/**Singleton instance of the DDB.*/
	private static DDB ddb;

	/**
	 * Returns a handle to a DDB object. Creates one if necessary.
	 * 
	 * @param name  Currently if Windows, the ODBC DSN name of the DDB, or if 
	 * Linux, the file name of the DDB. 
	 * 
	 * @return a DDB instance, which can be used to access the DDB.
	 * 
	 * @throws Exception on any error.
	 */
	public static DDB getDDB(String name) throws Exception {

		if (ddb != null) return ddb;

		String os = System.getProperty("os.name");
		File filename = new File(name);

		if (filename.isFile())
			//By default, uses the UCanAccess driver and mdb file name as connection, 
			//assuming username and password are not necessary (see http://ucanaccess.sourceforge.net/site.html).
			//ucanaccess.jar and its .jar dependencies must be added to the 
			//Java Build Path libraries of the project (and at least in Matlab classpath.txt).
			return new JDBCDDB("net.ucanaccess.jdbc.UcanaccessDriver", "jdbc:ucanaccess://" + name + ";jackcessOpener=org.imos.ddb.CryptCodecOpener", "", "");
		else {
			if (os.startsWith("Windows"))
				return new ODBCDDB(name);
			else {
				System.err.println(name + " is not a valid filepath!");
			}

		}

		return ddb;
	}

	/**
	 * Returns a handle to a DDB object. Creates one if necessary.
	 * 
	 * @param driver  Class name of JDBC database driver
	 * @param connection  Database connection string, must include user
	 * and password if required by the database.
	 * @param user  user's login to log on to the database
	 * @param password  password associated to the user's login provided
	 * 
	 * @return a DDB instance, which can be used to access the DDB.
	 * 
	 * @throws Exception on any error.
	 */
	public static DDB getDDB(String driver, String connection, String user, String password) throws Exception {

		if (ddb != null) return ddb;

		ddb = new JDBCDDB(driver, connection, user, password);

		return ddb;
	}

	/**
	 * Query the DDB. This method provides a primitive SQL interface to the DDB.
	 * The following SQL query is executed:
	 * 
	 *   select * from [tableName] where [fieldName] = '[fieldValue]'
	 * 
	 * The resulting rows are converted into object-equivalents of the given 
	 * table and returned in a List. If fieldName is null, all rows are returned.
	 * 
	 * @param tableName name of the DDB table to query (used in the 'from'
	 * clause).
	 * 
	 * @param fieldName field name within the given table - optional (used in the 
	 * 'where' clause).
	 * 
	 * @param fieldValue field value - optional (used in the 'where' clause).
	 *  
	 * @return a List of org.imos.ddb.schema.* objects, each representing one 
	 * row of the result.
	 * 
	 * @throws Exception on any error.
	 */
	public abstract ArrayList<Object> executeQuery(
			String tableName,  
			String fieldName, 
			Object fieldValue)
					throws Exception;
}
