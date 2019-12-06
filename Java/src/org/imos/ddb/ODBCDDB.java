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

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.Statement;
import java.util.ArrayList;

/**
 * In memory representation of the IMOS deployment database using JDBC. 
 * Database access is achieved via the Sun JDBC-ODBC bridge. This seems to 
 * work great under Windows, but not under Linux. If using Linux, see the 
 * alternate org.imos.ddb.MDBSQLDDB.
 *  
 * If a decent (free) JDBC driver for MS Access is ever released, we can 
 * migrate over to it.
 * 
 * This class should never be instantiated directly; use the static method
 * org.imos.ddb.DDB.getDDB.
 * 
 * @author Paul McCarthy <paul.mcccarthy@csiro.au>
 * @author Peter Jansen <peter.jansen@csiro.au> - generic database schema changes
 * 
 * @see http://java.sun.com/javase/6/docs/technotes/guides/jdbc/bridge.html
 */
public class ODBCDDB extends DDB {

	/**The ODBC database name*/
	private final String dbName;

	/**
	 * Saves the given ODBC Data Source Name (DSN) for later use. 
	 * 
	 * @param name name of the ODBC DSN for the deployment database. 
	 */
	protected ODBCDDB(String dbName) {this.dbName = dbName;}

	/**
	 * Executes the given query, in the form:
	 * 
	 *   select * from [tableName] where [fieldName] = '[fieldValue]'
	 * 
	 * The rows are converted into object equivalents of the table, and returned 
	 * in a List. If fieldName is null, the where clause is omitted, thus the 
	 * entire table is returned.
	 * 
	 * @param tableName The table to read.
	 * 
	 * @param fieldName the name of the query field.
	 * 
	 * @param fieldValue the query field value.
	 * 
	 * @throws Exception on any error.
	 */
	public ArrayList<Object> executeQuery(
			String tableName,  
			String fieldName, 
			Object fieldValue)
					throws Exception {

		Connection conn = null;
		Statement stmt = null;
		ResultSet rs = null;
		ArrayList<Object> results = null;

		try {

			//create ODBC database connection
			Class.forName("sun.jdbc.odbc.JdbcOdbcDriver");

			conn = DriverManager.getConnection("jdbc:odbc:" + dbName);

			results = new ArrayList<Object>();

			//build the query
			String query = "SELECT * FROM " + tableName;
			if (fieldName != null) {

				if (fieldValue == null)
					throw new Exception("a fieldValue must be provided");

				//wrap strings in quotes
				if (fieldValue instanceof String) 
					query += " WHERE " + fieldName + " = '" + fieldValue + "'";
				else
					query += " WHERE " + fieldName + " = " + fieldValue;
			}

			//execute the query
			try {
				stmt = conn.createStatement();
				rs = stmt.executeQuery(query);
			}
			catch (Exception e) {

				//Hack to accommodate DeploymentId and FieldTripID
				//types of number or text. Don't tell anyone
				if (fieldName != null && fieldValue instanceof String) {

					query = "SELECT * FROM " + tableName + 
							" WHERE " + fieldName + " = " + fieldValue;

					stmt = conn.createStatement();
					rs = stmt.executeQuery(query);
				}
				else throw e;
			}

			ResultSetMetaData rsmd = rs.getMetaData();
			int columnsNumber = rsmd.getColumnCount();
			//create an object for each row
			while (rs.next()) {

				ArrayList<Object> instance = new ArrayList<Object>();
				results.add(instance);

				for (int i = 1; i < columnsNumber; i++) {

					DBObject db = new DBObject();

					db.name = rsmd.getColumnName(i);
					db.o = rs.getObject(i);

					//all numeric values must be doubles
					if (db.o instanceof Integer) {
						db.o = (double)((Integer)db.o).intValue();
					}

					instance.add(db);
				}
			}
		}

		//always close db connection
		finally {
			try {
				rs.close();
				stmt.close();
				conn.close();
			} 
			catch (Exception e) {}}

		return results;
	}
}
