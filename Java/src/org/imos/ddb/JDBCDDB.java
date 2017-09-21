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
import java.sql.DatabaseMetaData;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.ArrayList;

/**
 * In memory representation of the IMOS deployment database using JDBC. 
 * This class uses a generic JDBC driver and connection string so is
 * database agnostic, allowing the deployment database to be hosted on any
 * JDBC supported database platform.
 * 
 * This class should never be instantiated directly; use the static method
 * org.imos.ddb.DDB.getDDB.
 * 
 * @author Gordon Keith <gordon.keith@csiro.au>
 * @author Peter Jansen <peter.jansen@csiro.au> - generic database schema changes
 * 
 * @see http://java.sun.com/javase/6/docs/technotes/guides/jdbc/bridge.html
 */
public class JDBCDDB extends DDB {

	String identQuote = "'";
	
	/**The JDBC database driver*/
	private String driver;
	private String connection;
	private String user;
	private String password;

	/**
	 * Create a JDBC DDB object using the specified JDBC driver and database connection. 
	 * 
	 * @param driver Class name of JDBC database driver
	 * @param connection Database connection string, must include user and password if required by the database.
	 * @throws ClassNotFoundException If the specified Database driver can't be found
	 * @throws SQLException If an attempt to open a connection to the database fails
	 */
	protected JDBCDDB(String driver, String connection, String user, String password) throws ClassNotFoundException, SQLException {
		this.driver = driver;
		this.connection = connection;
		this.user = user;
		this.password = password;

		// Test connection - throws exception at creation if can't connect
		Class.forName(driver);

		Connection conn = DriverManager.getConnection(connection, user, password);
		
		// get the database's IdentifierQuote
		DatabaseMetaData dbmd = conn.getMetaData();
		identQuote = dbmd.getIdentifierQuoteString();
		
		conn.close();
	}

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
		ArrayList<Object> results = null;

		try {

			//create ODBC database connection
			Class.forName(driver);

			conn = DriverManager.getConnection(connection, user, password);

			results = new ArrayList<Object>();

			//build the query
			String query = "SELECT * FROM " + identQuote + tableName + identQuote;
			if (fieldName != null) {

				if (fieldValue == null)
					throw new Exception("a fieldValue must be provided");

				//wrap strings in quotes
				if (fieldValue instanceof String) 
					query += " WHERE " + identQuote + fieldName + identQuote + " = '" + fieldValue + "'";
				else
					query += " WHERE " + identQuote + fieldName + identQuote + " = " + fieldValue;
			}

			//execute the query
			Statement stmt = null;
			ResultSet rs = null;
			try {
				stmt = conn.createStatement();
				rs = stmt.executeQuery(query);
			}
			catch (Exception e) {

				System.out.println("JDBCDDB::Exception Caught " + e);

				//Hack to accommodate DeploymentId and FieldTripID
				//types of number or text. Don't tell anyone
				if (fieldName != null && fieldValue instanceof String) {

					query = "SELECT * FROM " + identQuote + tableName + identQuote + 
							" WHERE " + identQuote + fieldName + identQuote + " = " + fieldValue;

					System.out.println("JDBCDDB::Query : " + query);

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

				for (int i = 1; i <= columnsNumber; i++) {

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
		finally {try {conn.close();} catch (Exception e) {}}

		return results;
	}
}
